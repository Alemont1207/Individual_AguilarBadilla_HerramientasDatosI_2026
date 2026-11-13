# res/ — Resultados

Archivos generados por el código. **No se editan a mano**: se vuelven a crear al correr los scripts.

## Archivos

| Archivo | Qué es | Lo genera |
|---|---|---|
| `resultados_optimizacion.csv` | Tabla con la configuración óptima y los indicadores de cada escenario | `cod/optimizacion_semaforos.R` |
| `01_flujos_por_escenario.png` | Flujo vehicular por dirección en cada escenario | `cod/optimizacion_semaforos.R` |
| `02_superficie_W.png` | Mapa de calor del tiempo de espera según los verdes probados, con el óptimo marcado | `cod/optimizacion_semaforos.R` |
| `03_comparacion_configuraciones.png` | Espera promedio con reparto equitativo, Webster y optimizado | `cod/optimizacion_semaforos.R` |
| `04_verde_recomendado.png` | Segundos de verde recomendados para cada dirección | `cod/optimizacion_semaforos.R` |
| `Reporte_semaforos.pdf` | Reporte del proyecto (5 páginas) | `cod/reporte_autonomo.qmd` |

## Columnas de `resultados_optimizacion.csv`

| Columna | Significado |
|---|---|
| `escenario` | Escenario analizado |
| `q.NS`, `q.EO` | Flujo Norte-Sur y Este-Oeste (veh/h) |
| `g.NS.opt`, `g.EO.opt` | Verde óptimo Norte-Sur y Este-Oeste (s) |
| `C.opt` | Duración del ciclo óptimo (s) |
| `W.opt` | Tiempo promedio de espera con el plan óptimo (s por vehículo) |
| `g.NS.web`, `g.EO.web` | Verde según la fórmula de Webster (s) |
| `W.webster` | Espera con el plan de Webster (s por vehículo) |
| `W.equitativo` | Espera con el reparto equitativo de 30 s y 30 s (s por vehículo) |
| `mejora.vs.equit.pct` | Reducción de la espera del plan óptimo frente al equitativo (%) |
| `no.atendidos.opt` | Vehículos que no alcanzan a cruzar en la hora simulada (por repetición) |

Los valores de `W` se calculan con llegadas aleatorias **nuevas**, distintas de las usadas para buscar el óptimo (validación).

## Cómo regenerarlos

```r
source("cod/optimizacion_semaforos.R")   # tabla y gráficos
```

```bash
quarto render cod/reporte_autonomo.qmd --to pdf   # reporte (mover el PDF a res/)
```