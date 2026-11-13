# data/ — Datos de entrada

## Archivos

| Archivo | Descripción |
|---|---|
| `datos_flujo.csv` | Escenarios de flujo vehicular que lee el script de análisis (`cod/optimizacion_semaforos.R`). |
| `aforos_mopt_2023.csv` | *(Opcional)* Conteos originales del MOPT por acceso y movimiento, antes de agruparlos. Sirve para verificar la fuente. |

## `datos_flujo.csv`

Una fila por escenario.

| Columna | Significado | Unidad |
|---|---|---|
| `escenario` | Nombre del escenario | texto |
| `q.NS` | Flujo en la calle Norte-Sur (suma de sus dos sentidos) | vehículos/hora |
| `q.EO` | Flujo en la calle Este-Oeste (suma de sus dos sentidos) | vehículos/hora |
| `n.NS` | Carriles que atiende la fase Norte-Sur (sumando ambos sentidos) | carriles |
| `n.EO` | Carriles que atiende la fase Este-Oeste (sumando ambos sentidos) | carriles |
| `fuente` | `MOPT 2023 (real)` o `Simulado` | texto |

### Escenarios incluidos

| Escenario | q.NS | q.EO | Fuente |
|---|---|---|---|
| MOPT AM (07:30-08:30) | 298 | 955 | MOPT 2023 (real) |
| MOPT PM (16:30-17:30) | 384 | 699 | MOPT 2023 (real) |
| Flujo bajo | 300 | 250 | Simulado |
| Flujo equilibrado | 800 | 800 | Simulado |
| Predominio Norte-Sur | 1300 | 400 | Simulado |
| Alta demanda | 1200 | 1000 | Simulado |

## Origen de los datos reales

MOPT, Dirección General de Ingeniería de Tránsito (2023). *Análisis de intersección Ruta Nacional N.° 124 con
Ruta Nacional N.° 122, San Antonio, Alajuela*, informe MOPT-03-05-01-0587-2023 (Tablas 2 y 3).

- Conteos manuales realizados el 29, 30 y 31 de agosto, el 1 de setiembre y el 4 y 5 de octubre de 2023,
  de 6:30 a 9:00 y de 16:30 a 18:30.
- Horas pico: 7:30 a 8:30 (mañana) y 16:30 a 17:30 (tarde).

### Cómo se prepararon

- La Ruta 124 (calle principal) se tomó como Este-Oeste y la Ruta 122 (secundaria) como Norte-Sur.
- Se sumaron los movimientos (izquierda, directo y derecha) y los dos accesos de cada calle.
  Por ejemplo, en la mañana: `q.EO = 435 (Oeste) + 520 (Este) = 955`.
- Se asumieron 2 carriles por fase (uno por acceso).
- Los totales coinciden con los del informe (955 y 699 veh/h en la calle principal; 256 y 240 veh/h en el acceso sur).

## Limitaciones de los datos

- Los conteos incluyen solo los vehículos que lograron cruzar la intersección (demanda satisfecha); la demanda real podría ser mayor.
- Es un solo cruce y solo horas pico.
- Los escenarios `Simulado` son valores de referencia propios, no datos oficiales.