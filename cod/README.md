# cod/ — Código

Contiene todo el código del proyecto. Se ejecuta siempre con la **raíz del repositorio** como carpeta de trabajo
(abriendo el archivo `.Rproj` en RStudio).

## Archivos

| Archivo | Qué hace |
|---|---|
| `modelo_semaforos.R` | **El modelo.** Solo define funciones, no ejecuta nada. Lo usan el script de análisis y la app. |
| `optimizacion_semaforos.R` | Análisis completo: lee `data/datos_flujo.csv`, optimiza cada escenario y guarda tabla y gráficos en `res/`. |
| `app_shiny/app.R` | Aplicación Shiny: optimización interactiva y simulación visual animada de la intersección. |
| `reporte_autonomo.qmd` | Reporte en PDF (Quarto). Trae los datos y resultados incrustados, no necesita otros archivos. |

## Cómo se relacionan

```
data/datos_flujo.csv ──► optimizacion_semaforos.R ──► res/ (tabla y gráficos)
                              │
                              └── usa las funciones de ──► modelo_semaforos.R ◄── app_shiny/app.R
```

El modelo está separado en su propio archivo para que el script y la app usen exactamente el mismo código
y den los mismos resultados. **La app necesita que `modelo_semaforos.R` esté en `cod/`**, un nivel arriba de
su carpeta.

## Funciones del modelo (`modelo_semaforos.R`)

| Función | Para qué sirve |
|---|---|
| `generar_llegadas()` | Genera las llegadas aleatorias de vehículos (Poisson) por segundo y por repetición. |
| `espera_direccion()` | Calcula la fila y la espera de cada vehículo en una dirección. |
| `evaluar_config()` | Evalúa un par de tiempos de verde: tiempo promedio de espera `W`, `W` por dirección y vehículos no atendidos. |
| `webster()` | Reparto de referencia con la fórmula de Webster. |
| `evaluar_rejilla()` | Evalúa muchas combinaciones de verde. |
| `recomendar_semaforo()` | Optimización completa (rejilla gruesa, refinamiento de 1 s y validación con llegadas nuevas). |
| `serie_cola()` | Longitud de las filas a lo largo del tiempo (para los gráficos de la app). |

## Cómo ejecutar

```r
# 1. Análisis y gráficos (genera archivos en res/)
source("cod/optimizacion_semaforos.R")

# 2. Aplicación Shiny
shiny::runApp("cod/app_shiny")
```

```bash
# 3. Reporte en PDF (en la terminal; requiere Quarto y LaTeX)
quarto render cod/reporte_autonomo.qmd --to pdf
```

## Notas importantes

- **Reproducibilidad:** los resultados usan una semilla fija (`semilla = 2025`), así que se repiten al volver a correr.
- **Parámetros:** están en la lista `params` al inicio de `optimizacion_semaforos.R` (ver `config/README.md`).
  La app permite cambiarlos en el panel "Mostrar parámetros avanzados"; por defecto usa 10 repeticiones
  (el script usa 20), por lo que los números pueden diferir levemente.
- **El reporte no se actualiza solo:** `reporte_autonomo.qmd` tiene los datos y resultados incrustados.
  Si cambias datos o parámetros y vuelves a correr el análisis, hay que actualizar esos valores en el `.qmd`.
- **Paquetes:** el análisis usa solo R base; la app necesita `shiny`; el reporte necesita `knitr` y `rmarkdown`.