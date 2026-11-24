# Prueba de carga – Login FakeStoreAPI con k6

Prueba de carga del servicio de login de FakeStoreAPI, parametrizada con los usuarios de un archivo `.csv`. Durante la ejecución se levanta un dashboard web con gráficas en vivo y, al terminar, se generan el reporte HTML, el resumen en JSON y las métricas detalladas en CSV.

Servicio probado (CURL del enunciado, con uno de los usuarios del CSV):

```bash
curl -X POST 'https://fakestoreapi.com/auth/login' \
  -H 'Content-Type: application/json' \
  -d '{"username": "kevinryan", "password": "kev02937@"}'
```

## 1. Tecnologías y versiones

| Tecnología | Versión | Uso |
|---|---|---|
| Grafana k6 | **v2.4.0** (go1.26.11, windows/amd64) | Motor de la prueba de carga |
| k6 Web Dashboard | incluido en k6 v2.4.0 | Gráficas en vivo y reporte HTML |
| papaparse | **5.1.1** (incluida en `helpers/lib/`) | Lectura del archivo CSV |
| Windows | 11 Pro | Sistema operativo de la ejecución |
| PowerShell | 5.1 | Terminal de ejecución |
| Navegador web | cualquiera reciente (Chrome, Edge) | Ver el dashboard y el reporte HTML |
| Microsoft Word | 2007 o superior | Abrir `InformeResultados.docx` |

Notas:

- No se necesita Node.js ni npm: k6 ejecuta el JavaScript por sí mismo.
- Se necesita conexión a internet porque la prueba llama a `fakestoreapi.com`. Las ejecuciones documentadas se hicieron desde un equipo conectado a internet por cable. La librería papaparse ya está en el repositorio, así que no se descarga nada al iniciar.

## 2. Estructura del proyecto

```
retoTecnicoPruebaCargaLoginFakeStore/
├── README.md                     Este archivo
├── Conclusiones.md               Hallazgos y conclusiones
├── InformeResultados.docx        Informe de resultados
├── helpers/
│   ├── UserDataProvider.js       Carga el CSV y reparte los usuarios entre los VUs
│   └── lib/
│       └── papaparse-5.1.1.js    Librería para leer el CSV (copia de jslib.k6.io)
├── login/
│   ├── login-test.js             Script de la prueba de carga
│   └── data/
│       └── users.csv             Usuarios de prueba (user,passwd)
├── scripts/
│   └── analizar-metricas.ps1     Genera las gráficas y tablas del informe
├── docs/
│   └── evidencias/
│       └── Consumo servicio.png  Consumo del login sin carga en Postman (428 ms)
└── reports/
    ├── login-report.html         Reporte HTML con gráficas (k6 Web Dashboard)
    ├── summary.json              Resumen de métricas al final de la prueba
    ├── metrics.csv.gz            Métricas de cada petición (CSV comprimido)
    ├── resumen-consola.txt       Resumen que imprimió k6 en la terminal
    └── graficas/
        ├── vus-vs-tps.png        Usuarios virtuales vs. peticiones por segundo
        ├── tiempos.png           Tiempo de respuesta por segundo
        ├── por-segundo.csv       VUs, TPS y tiempos de cada segundo
        └── por-etapa.csv         Resumen por etapa (subida, sostenida, bajada)
```

## 3. Datos de entrada

`login/data/users.csv`:

```
user,passwd
donero,ewedon
kevinryan,kev02937@
johnd,m38rmF$
derek,jklg*_56
mor_2314,83r5^_
```

Cada usuario virtual (VU) toma un usuario fijo del archivo: el VU 1 usa la fila 1, el VU 2 la fila 2 y así sucesivamente. Cuando hay más VUs que filas, vuelve a empezar desde la primera. Las columnas `user` y `passwd` se envían como `username` y `password` en el cuerpo de la petición, igual que en el CURL.

## 4. Instalación de k6 (solo la primera vez)

1. Instalar k6 v2.4.0 para Windows con una de estas opciones:
   - Instalador `.msi` oficial: <https://github.com/grafana/k6/releases/tag/v2.4.0>
   - winget, desde PowerShell:
     ```powershell
     winget install k6 --source winget
     ```
   Por defecto se instala en `C:\Program Files\k6\k6.exe`.

2. Si el comando `k6` no se reconoce, agregar la carpeta al PATH del usuario:
   ```powershell
   [Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path","User") + ";C:\Program Files\k6", "User")
   ```

3. Cerrar y volver a abrir la terminal (o VS Code completo) para que tome el nuevo PATH.

4. Verificar la instalación:
   ```powershell
   k6 version
   ```
   Resultado esperado: `k6.exe v2.4.0 (commit/dd9395906d, go1.26.11, windows/amd64)`

## 5. Ejecución de la prueba

1. Abrir PowerShell en la carpeta del repositorio, la que contiene este `README.md`.

2. Ejecutar la prueba (es un solo comando, en una sola línea):
   ```powershell
   $env:K6_WEB_DASHBOARD="true"; $env:K6_WEB_DASHBOARD_OPEN="true"; $env:K6_WEB_DASHBOARD_EXPORT="reports/login-report.html"; k6 run --summary-mode=full --summary-export=reports/summary.json --out csv=reports/metrics.csv.gz login/login-test.js
   ```

   | Parte del comando | Qué hace |
   |---|---|
   | `K6_WEB_DASHBOARD=true` | Levanta el servidor de gráficas en vivo |
   | `K6_WEB_DASHBOARD_OPEN=true` | Abre el navegador automáticamente |
   | `K6_WEB_DASHBOARD_EXPORT=...` | Guarda el reporte HTML al terminar |
   | `--summary-mode=full` | Muestra en la terminal el resumen con todas las métricas |
   | `--summary-export=...` | Guarda el resumen en JSON |
   | `--out csv=...` | Guarda las métricas de cada petición en un CSV comprimido |

3. Seguir la prueba en vivo en el navegador: <http://127.0.0.1:5665>. La prueba dura unos 13 minutos.

4. Al terminar:
   - El resumen de métricas aparece al final de la terminal, debajo de las líneas `running (...)`.
   - El reporte con gráficas queda en `reports\login-report.html`. Para verlo, abrirlo con el navegador.

5. Opcional: generar las gráficas de VUs vs. TPS y de tiempos de respuesta a partir de `reports/metrics.csv.gz`:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\analizar-metricas.ps1 -Csv reports\metrics.csv.gz -OutDir reports\graficas
   ```
   Usa las librerías de gráficos de .NET Framework que ya trae Windows; no hay que instalar nada. Los parámetros opcionales `-FinSubida` (120 por defecto) e `-InicioBajada` (720 por defecto) indican, en segundos, dónde termina la subida y dónde empieza la bajada. Si se cambian los `stages` del script, hay que ajustarlos.

Para detener la prueba antes de tiempo: `Ctrl + C`.

> Las variables `$env:...` solo duran en la terminal donde se escriben. Si se abre otra terminal, hay que volver a ejecutar el comando completo del paso 2.

## 6. Configuración de la prueba

Escenario de carga (`stages` en `login/login-test.js`):

| Etapa | Duración | Usuarios virtuales |
|---|---|---|
| Subida | 2 minutos | de 0 a 60 |
| Carga sostenida (meseta) | 10 minutos | 60 |
| Bajada | 1 minuto | de 60 a 0 |

Duración total: 13 minutos, más 30 segundos de margen para cerrar. Cada VU espera 2 segundos entre peticiones (`sleep(2)`).

Dimensionamiento de los usuarios virtuales:

```
TPS = usuarios virtuales (VUs) / (tiempo de respuesta promedio + tiempo de sleep)
```

- El tiempo de respuesta del login sin carga, medido en Postman, fue de 428 ms (`docs/evidencias/Consumo servicio.png`).
- VUs mínimos para 20 TPS: 20 × (0.428 s + 2 s) = 48.6, es decir, 49 VUs.
- Se usaron 60 VUs, un 22 % por encima del mínimo, para tener margen: 60 / (0.428 s + 2 s) ≈ 24.7 TPS teóricas.

Criterios de aceptación (`thresholds`):

| Métrica | Criterio | Significado |
|---|---|---|
| `http_req_duration` | `p(95)<1500` | El 95 % de las respuestas tarda menos de 1.5 s |
| `http_req_duration` | `max<1500` | Ninguna respuesta tarda 1.5 s o más; si una sola se pasa, la prueba falla |
| `http_req_failed` | `rate<0.03` | Menos del 3 % de las peticiones falla |
| `http_reqs` | `rate>=20` | El promedio de toda la prueba es de al menos 20 TPS; si no se alcanza, la prueba falla |
| `checks` | `rate>0.97` | Más del 97 % de las validaciones pasa |

Validaciones de cada respuesta (`checks`):

- El status es 201, que es lo que responde el servicio cuando el login es correcto.
- La respuesta es un JSON con un campo `token` que tiene forma de JWT (tres partes separadas por puntos).
- El tiempo de respuesta es menor a 1.5 s.

## 7. Cómo leer el resultado

- En la sección `THRESHOLDS` del resumen, cada criterio aparece con una marca: `✓` se cumple, `✗` no se cumple.
- Si algún threshold no se cumple, k6 termina con un código de salida distinto de 0 y la prueba queda como fallida.
- Métricas principales:

| Métrica | Qué mide |
|---|---|
| `http_req_duration` | Tiempo de respuesta (avg, min, med, max, p90, p95) |
| `http_req_failed` | Porcentaje de peticiones con error |
| `http_reqs` | Total de peticiones y peticiones por segundo (TPS) |
| `checks` | Porcentaje de validaciones que pasaron |
| `vus` / `vus_max` | Usuarios virtuales activos / máximo |

Los resultados obtenidos están en `Conclusiones.md` y en `InformeResultados.docx`.

## 8. Problemas frecuentes

- **`k6 : El término 'k6' no se reconoce como nombre de un cmdlet...`**: k6 no está en el PATH. Hacer los pasos 2 y 3 de la sección 4, o usar la ruta completa:
  ```powershell
  & "C:\Program Files\k6\k6.exe" run --summary-mode=full login/login-test.js
  ```
- **El puerto 5665 ya está en uso**: hay otra ejecución de k6 abierta. Cerrarla con `Ctrl + C`, o cerrar el proceso desde PowerShell con `Get-Process k6 | Stop-Process`.
- **No se genera `reports\login-report.html`**: el reporte se escribe cuando k6 cierra la prueba. Si el proceso se cierra a la fuerza (por ejemplo, cerrando la terminal o con `Stop-Process`), no se genera. Volver a ejecutar la prueba completa.
- **Error al conectar con `fakestoreapi.com`**: revisar la conexión a internet o el proxy de la red.
