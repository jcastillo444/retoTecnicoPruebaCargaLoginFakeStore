param([string]$Csv, [string]$OutDir, [int]$FinSubida = 120, [int]$InicioBajada = 720)
$ErrorActionPreference = "Stop"
[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture
New-Item -ItemType Directory -Force $OutDir | Out-Null
Add-Type -AssemblyName System.Windows.Forms.DataVisualization
Add-Type -AssemblyName System.Drawing

$fs = [IO.File]::OpenRead($Csv)
$gz = New-Object IO.Compression.GZipStream($fs, [IO.Compression.CompressionMode]::Decompress)
$sr = New-Object IO.StreamReader($gz)
$header = $sr.ReadLine().Split(',')
$iName = [array]::IndexOf($header, 'metric_name'); $iTs = [array]::IndexOf($header, 'timestamp'); $iVal = [array]::IndexOf($header, 'metric_value'); $iStatus = [array]::IndexOf($header, 'status')

$reqs = @{}; $vus = @{}; $durSum = @{}; $durMax = @{}; $durs = @{}; $fails = @{}; $statusCount = @{}
while (($line = $sr.ReadLine()) -ne $null) {
  $c = $line.Split(',')
  $n = $c[$iName]; $t = [int]$c[$iTs]
  switch ($n) {
    'http_reqs' { $reqs[$t] = 1 + [int]$reqs[$t]; $s = $c[$iStatus]; $statusCount[$s] = 1 + [int]$statusCount[$s] }
    'vus' { $vus[$t] = [int][double]$c[$iVal] }
    'http_req_duration' {
      $v = [double]::Parse($c[$iVal], [Globalization.CultureInfo]::InvariantCulture)
      $durSum[$t] = $v + [double]$durSum[$t]
      if ($v -gt [double]$durMax[$t]) { $durMax[$t] = $v }
      if (-not $durs.ContainsKey($t)) { $durs[$t] = New-Object System.Collections.Generic.List[double] }
      $durs[$t].Add($v)
    }
    'http_req_failed' { if ([double]::Parse($c[$iVal], [Globalization.CultureInfo]::InvariantCulture) -gt 0) { $fails[$t] = 1 + [int]$fails[$t] } }
  }
}
$sr.Close()

$all = (@($reqs.Keys) + @($vus.Keys)) | Sort-Object -Unique
$t0 = $all[0]
$rows = New-Object System.Collections.Generic.List[object]
$lastVu = 0
foreach ($t in ($t0..$all[-1])) {
  if ($vus.ContainsKey($t)) { $lastVu = $vus[$t] }
  $r = [int]$reqs[$t]
  $rows.Add([pscustomobject]@{ seg = $t - $t0; vus = $lastVu; tps = $r; avg = $(if ($r) { [math]::Round($durSum[$t] / $r, 1) } else { 0 }); max = [math]::Round([double]$durMax[$t], 1); fallos = [int]$fails[$t] })
}
$rows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutDir 'por-segundo.csv')

function Get-Pct($list, $p) { $a = $list | Sort-Object; $a[[math]::Max(0, [math]::Ceiling($p / 100 * $a.Count) - 1)] }
$fin = ($all[-1] - $all[0])
$eSub = "Subida (0-$FinSubida s)"; $eSos = "Sostenida ($FinSubida-$InicioBajada s)"; $eBaj = "Bajada ($InicioBajada-$fin s)"
$stage = @{ $eSub = { $_.seg -lt $FinSubida }; $eSos = { $_.seg -ge $FinSubida -and $_.seg -lt $InicioBajada }; $eBaj = { $_.seg -ge $InicioBajada } }
$stats = foreach ($k in $eSub, $eSos, $eBaj) {
  $sel = $rows | Where-Object $stage[$k] | Where-Object { $_.tps -gt 0 }
  $d = New-Object System.Collections.Generic.List[double]
  foreach ($x in $sel) { $durs[$t0 + $x.seg] | ForEach-Object { $d.Add($_) } }
  $m = $sel | Measure-Object tps -Average -Minimum -Maximum -Sum
  [pscustomobject]@{ etapa = $k; vus_max = ($sel | Measure-Object vus -Maximum).Maximum; peticiones = $m.Sum; tps_prom = [math]::Round($m.Average, 1); tps_min = $m.Minimum; tps_max = $m.Maximum; p95_ms = [math]::Round((Get-Pct $d 95), 1); max_ms = [math]::Round(($d | Measure-Object -Maximum).Maximum, 1) }
}
$stats | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutDir 'por-etapa.csv')
$stats | Format-Table -AutoSize | Out-String | Write-Output
"Status HTTP:"; $statusCount.GetEnumerator() | ForEach-Object { "  $($_.Key): $($_.Value)" }
$vmax = ($rows | Measure-Object vus -Maximum).Maximum
$s46 = $rows | Where-Object { $_.vus -ge $vmax -and $_.tps -gt 0 } | Measure-Object tps -Average
"TPS promedio con $vmax VUs: " + [math]::Round($s46.Average, 1)
$cross = $rows | Where-Object { $_.tps -ge 20 } | Select-Object -First 1
"Primer segundo con >= 20 TPS: seg $($cross.seg) con $($cross.vus) VUs"

function New-Chart($title, $file, [scriptblock]$fill) {
  $ch = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
  $ch.Width = 1100; $ch.Height = 480; $ch.BackColor = 'White'
  $ch.Titles.Add($title) | Out-Null; $ch.Titles[0].Font = New-Object Drawing.Font('Segoe UI', 13, [Drawing.FontStyle]::Bold)
  $a = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
  $a.AxisX.Title = 'Tiempo de prueba (segundos)'; $a.AxisX.Interval = 60; $a.AxisX.Minimum = 0
  $a.AxisX.MajorGrid.LineColor = 'Gainsboro'; $a.AxisY.MajorGrid.LineColor = 'Gainsboro'
  foreach ($ax in $a.AxisX, $a.AxisY, $a.AxisY2) { $ax.TitleFont = New-Object Drawing.Font('Segoe UI', 10); $ax.LabelStyle.Font = New-Object Drawing.Font('Segoe UI', 9) }
  $ch.ChartAreas.Add($a)
  $lg = New-Object System.Windows.Forms.DataVisualization.Charting.Legend; $lg.Docking = 'Bottom'; $lg.Font = New-Object Drawing.Font('Segoe UI', 10); $ch.Legends.Add($lg)
  & $fill $ch $a
  $ch.SaveImage($file, 'Png')
}
function Add-Series($ch, $name, $color, $y2, $data, $prop, $width = 2) {
  $s = New-Object System.Windows.Forms.DataVisualization.Charting.Series($name)
  $s.ChartType = 'Line'; $s.Color = $color; $s.BorderWidth = $width
  if ($y2) { $s.YAxisType = 'Secondary' }
  foreach ($r in $data) { $s.Points.AddXY($r.seg, $r.$prop) | Out-Null }
  $ch.Series.Add($s)
}

New-Chart 'Usuarios virtuales vs. peticiones por segundo (TPS)' (Join-Path $OutDir 'vus-vs-tps.png') {
  param($ch, $a)
  $a.AxisY.Title = 'Peticiones por segundo (TPS)'; $a.AxisY2.Enabled = 'True'; $a.AxisY2.Title = 'Usuarios virtuales (VUs)'; $a.AxisY2.MajorGrid.Enabled = $false; $a.AxisY2.Maximum = [math]::Ceiling(($vmax + 1) / 10) * 10; $a.AxisY2.Minimum = 0
  Add-Series $ch 'TPS por segundo' ([Drawing.Color]::FromArgb(147, 197, 253)) $false $rows 'tps' 1
  $ma = for ($i = 0; $i -lt $rows.Count; $i++) { $lo = [math]::Max(0, $i - 4); $hi = [math]::Min($rows.Count - 1, $i + 5); [pscustomobject]@{ seg = $rows[$i].seg; tps = ($rows[$lo..$hi] | Measure-Object tps -Average).Average } }
  Add-Series $ch 'TPS (media móvil de 10 s)' ([Drawing.Color]::FromArgb(29, 78, 216)) $false $ma 'tps' 3
  Add-Series $ch 'Usuarios virtuales' ([Drawing.Color]::FromArgb(234, 88, 12)) $true $rows 'vus' 3
  $sl = New-Object System.Windows.Forms.DataVisualization.Charting.StripLine; $sl.IntervalOffset = 20; $sl.StripWidth = 0.15; $sl.BackColor = 'Crimson'; $sl.Text = 'Meta: 20 TPS'; $sl.ForeColor = 'Crimson'; $sl.TextAlignment = 'Center'; $sl.Font = New-Object Drawing.Font('Segoe UI', 9, [Drawing.FontStyle]::Bold)
  $a.AxisY.StripLines.Add($sl)
}
New-Chart 'Tiempo de respuesta por segundo' (Join-Path $OutDir 'tiempos.png') {
  param($ch, $a)
  $a.AxisY.Title = 'Tiempo de respuesta (ms)'
  $d = $rows | Where-Object { $_.tps -gt 0 }
  Add-Series $ch 'Promedio' ([Drawing.Color]::FromArgb(37, 99, 235)) $false $d 'avg'
  Add-Series $ch 'Máximo' ([Drawing.Color]::FromArgb(148, 163, 184)) $false $d 'max' 1
  $sl = New-Object System.Windows.Forms.DataVisualization.Charting.StripLine; $sl.IntervalOffset = 1500; $sl.StripWidth = 5; $sl.BackColor = 'Crimson'; $sl.Text = 'Límite: 1500 ms'; $sl.ForeColor = 'Crimson'; $sl.TextAlignment = 'Near'; $sl.Font = New-Object Drawing.Font('Segoe UI', 9, [Drawing.FontStyle]::Bold)
  $a.AxisY.StripLines.Add($sl); $a.AxisY.Minimum = 0; $a.AxisY.Maximum = 1600; $a.AxisY.Interval = 200
}
"Gráficas generadas en $OutDir"
