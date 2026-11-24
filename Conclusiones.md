# Conclusiones – Prueba de carga del login

## Resultado general

La prueba de carga del servicio `POST https://fakestoreapi.com/auth/login` **cumple con los criterios definidos**. La ejecución final duró 13 minutos: subida de 0 a 60 usuarios virtuales en 2 minutos, 10 minutos de meseta con 60 usuarios y bajada en 1 minuto, con 2 segundos de espera entre peticiones de cada usuario. Se ejecutó desde un equipo conectado a internet por cable.

| Criterio | Meta | Ejecución final (60 VUs, versionada en `reports/`) | Resultado |
|---|---|---|---|
| TPS alcanzadas | al menos 20 TPS | 21.2 TPS de promedio en toda la prueba; 23.9 TPS en la meseta | ✅ Cumple |
| Tiempo de respuesta | máximo 1.5 s | p95 = 591 ms; máximo = 1.23 s | ✅ Cumple |
| Tasa de error | menor al 3 % | 0.00 % (0 de 16 543 peticiones) | ✅ Cumple |
| Checks (status 201, token JWT, tiempo < 1.5 s) | más del 97 % | 100 % (49 629 de 49 629) | ✅ Cumple |

Los cinco thresholds del script se cumplieron, incluido `http_reqs: rate>=20`, que hace fallar la prueba si el promedio de toda la ejecución no llega a 20 TPS.

Las cifras detalladas, las gráficas y las recomendaciones están en `InformeResultados.docx`.

## Dimensionamiento: cálculo teórico vs. resultado real

Con usuarios virtuales y `sleep`, las TPS se calculan así:

```
TPS = usuarios virtuales (VUs) / (tiempo de respuesta promedio + tiempo de sleep)
```

El tiempo de respuesta del login sin carga, medido en Postman, fue de **428 ms** (`docs/evidencias/Consumo servicio.png`). Con 2 segundos de sleep:

- VUs mínimos para 20 TPS: 20 × (0.428 s + 2 s) = 48.6, es decir, **49 VUs**.
- Se usaron **60 VUs**, un 22 % por encima del mínimo, para que la prueba no quedara justa.

| Cálculo | Teórico (428 ms) | Real (k6) | Diferencia |
|---|---|---|---|
| TPS en la meseta con 60 VUs | 60 / 2.428 s = **24.7** | **23.9** | −3.2 % |
| TPS promedio de toda la prueba (con subida y bajada) | **21.9** | **21.2** | −3.2 % |
| Tiempo de respuesta promedio | 428 ms (Postman, sin carga) | 508 ms (k6, con carga) | +80 ms |

La diferencia entre lo teórico y lo real se explica completa por el tiempo de respuesta. En Postman fue una petición suelta (428 ms); en k6 fue el promedio de 16 543 peticiones (508 ms). Si se recalcula con el tiempo real, 60 / (0.508 s + 2 s) = **23.9 TPS**, exactamente lo que se midió en la meseta. La fórmula sirve para dimensionar, siempre que se deje margen para la diferencia entre el tiempo sin carga y el tiempo con carga.

## Hallazgos

1. **Con 60 usuarios virtuales se superan las 20 TPS durante toda la meseta.** En los 10 minutos de meseta, el servicio atendió en promedio 23.9 TPS, y la media móvil de 10 segundos se mantuvo entre 21.5 y 24.6 TPS, siempre por encima de la meta. El promedio de toda la prueba fue de 21.2 TPS, aunque incluye la subida y la bajada, cuando hay menos usuarios activos. Las 20 TPS se alcanzaron a los 86 segundos de prueba, con unos 43 usuarios virtuales.

2. **El tiempo de respuesta se mantiene estable con la carga.** La mediana fue de 490 ms y el p95 de 591 ms. Por etapas, el p95 fue de 558 ms en la subida, 601 ms en la meseta y 547 ms en la bajada. Hubo un tramo más lento alrededor de los 274 segundos (promedio de 733 ms en ese segundo), que no llegó a afectar los criterios.

3. **El tiempo máximo (1.23 s) se dio al inicio de la prueba.** Ocurrió en el tercer segundo, con solo 2 usuarios activos, cuando se abren las primeras conexiones (DNS, TCP y TLS). En la meseta, el máximo fue de 1.21 s. Todas las respuestas quedaron por debajo de 1.5 s.

4. **Ninguna iteración quedó interrumpida.** k6 completó 16 543 iteraciones y registró 16 543 peticiones: todos los usuarios virtuales terminaron su última petición antes de cerrar.

5. **Casi todo el tiempo de respuesta es espera del servidor.** `http_req_waiting` (507 ms de promedio) es prácticamente igual a `http_req_duration` (508 ms). Conectar, negociar TLS y transferir datos solo cuesta algo en las primeras peticiones de cada usuario virtual, porque después k6 reutiliza las conexiones (HTTP/2 y TLS 1.3).

6. **El login exitoso responde 201 (Created), no 200.** Las 16 543 peticiones respondieron 201 con un token JWT.

## Limitaciones

- La prueba se ejecutó desde un solo equipo conectado a internet por cable, contra un servicio público. Los tiempos incluyen la latencia de esa red y pueden variar según la hora y la conexión.
- FakeStoreAPI es una API de demostración: los resultados muestran cómo se comporta este servicio, no un sistema productivo.
- No se tiene acceso a las métricas del servidor (CPU, memoria, base de datos), así que solo se mide lo que ve el cliente.

## Conclusiones

- El servicio soporta la carga esperada: con 60 usuarios virtuales sostuvo 23.9 TPS durante 10 minutos, por encima de la meta de 20 TPS, y el promedio de toda la prueba fue de 21.2 TPS.
- La fórmula `TPS = VUs / (tiempo de respuesta promedio + sleep)` permitió dimensionar la prueba: con el tiempo sin carga de Postman (428 ms) se necesitaban como mínimo 49 usuarios virtuales, y se usaron 60, un 22 % más, para que la prueba no quedara justa. El resultado real (23.9 TPS) quedó un 3.2 % por debajo del teórico (24.7 TPS), porque con carga el tiempo de respuesta promedio fue de 508 ms.
- La configuración de rampas (2 minutos de subida, 10 de meseta y 1 de bajada) protege al servidor de impactos iniciales, permite evaluar la estabilidad del rendimiento en la meseta y permite que las peticiones en curso terminen sin interrupciones al cerrar la prueba.
- El tiempo de respuesta permanece estable (p95 de 591 ms y mediana de 490 ms) y no tiene picos suficientes para afectar la prueba.
- El tiempo de respuesta máximo fue de 1.23 s, al inicio de la prueba, y se mantiene por debajo del máximo solicitado de 1.5 s.
- El porcentaje de error fue de 0 % con una carga mayor a la esperada, lo cual es positivo.
- La prueba se hizo desde un equipo con acceso a internet por cable, lo que evita la variación propia de una conexión inalámbrica; aun así, los tiempos incluyen la latencia de esa red.
- Por todo esto, la prueba es exitosa: cumple los criterios de aceptación definidos. Para aprobar un paso a producción se recomienda complementarla con pruebas de estrés y de resistencia en un ambiente similar a producción, con monitoreo del servidor.

Se optó por dejar el informe en el repo solo para dar a conocer su resultado sin la necesidad de ejecutarlo, sin embargo esto no es buena práctica pues este informe genera muchos archivos temporales que cambian constantemente.
