Proyecto individual del curso **Herramientas Datos I** (Universidad de Costa Rica, 2026).
**Autora:** Alessia Aguilar Badilla

## ¿De qué trata?

Modelo en R que simula una intersección con semáforo de dos fases (Norte-Sur y Este-Oeste) y busca el
reparto de luz verde que **minimiza el tiempo promedio de espera de los vehículos**, según el flujo de
cada calle. Incluye una aplicación interactiva (Shiny) con una animación de la intersección.

**Pregunta de investigación:** ¿cómo pueden optimizarse los tiempos de luz verde de una intersección,
según las condiciones de flujo vehicular, para minimizar el tiempo promedio de espera de los vehículos?

## Resultado principal

Repartir el verde según el flujo de cada dirección reduce la espera promedio entre **25 % y 50 %**
frente a un reparto igual de 30 s y 30 s.

| Escenario | Verde N-S / E-O (s) | Espera óptima (s/veh) | Espera con 30 s / 30 s (s/veh) | Mejora |
|---|---|---|---|---|
| Datos MOPT, mañana | 10 / 21 | 7,7 | 14,3 | 46 % |
| Datos MOPT, tarde | 10 / 14 | 7,6 | 13,1 | 42 % |
| Flujo bajo | 10 / 10 | 6,7 | 11,7 | 43 % |
| Flujo equilibrado | 10 / 10 | 8,5 | 14,2 | 40 % |
| Predominio Norte-Sur | 26 / 10 | 8,6 | 17,1 | 50 % |
| Alta demanda | 17 / 14 | 12,2 | 16,2 | 25 % |

![Comparación de configuraciones](res/03_comparacion_configuraciones.png)

## Cómo funciona (en breve)

1. **Datos:** flujos de vehículos por hora de cada calle (datos reales del MOPT más escenarios simulados).
2. **Simulación (Montecarlo):** se simula una hora segundo a segundo, con llegadas aleatorias de vehículos,
   filas durante el rojo y salida durante el verde. Cada configuración se repite 20 veces.
3. **Indicador:** tiempo promedio de espera, `W = (1/n) · Σ wᵢ`.
4. **Optimización:** búsqueda de la combinación de verde Norte-Sur (`g.NS`) y Este-Oeste (`g.EO`) con menor `W`,
   con ciclo `C = g.NS + g.EO + L`.
5. **Validación:** la combinación elegida se evalúa de nuevo con llegadas nuevas y se compara con un reparto
   equitativo y con la fórmula de Webster.

## Estructura del repositorio

```
├── cod/      Código: modelo, análisis, aplicación Shiny y reporte (.qmd)
├── data/     Datos de entrada (flujos vehiculares)
├── res/      Resultados generados: tabla, gráficos y reporte en PDF
├── info/     Documentación de apoyo y fuentes
├── config/   Configuración y parámetros del modelo
└── README.md
```

Cada carpeta tiene su propio `README.md` con más detalle.

## Cómo ejecutar

**Requisitos:** R 4.0 o superior y RStudio. Para el reporte, además, Quarto y una instalación de LaTeX
(por ejemplo `quarto install tinytex`).

```r
install.packages(c("shiny", "knitr", "rmarkdown"))
```

Abre el proyecto (`.Rproj`) en RStudio, de modo que la carpeta de trabajo sea la raíz del repositorio.

| Qué quiero hacer | Comando |
|---|---|
| Correr el análisis y generar tabla y gráficos en `res/` | `source("cod/optimizacion_semaforos.R")` |
| Abrir la aplicación con la animación | `shiny::runApp("cod/app_shiny")` |
| Generar el reporte en PDF | `quarto render cod/reporte_autonomo.qmd --to pdf` |

## Datos y fuentes

- Datos reales: MOPT, Dirección General de Ingeniería de Tránsito (2023). *Análisis de intersección Ruta
  Nacional N.° 124 con Ruta Nacional N.° 122, San Antonio, Alajuela* (informe MOPT-03-05-01-0587-2023).
- Contexto: Numbeo (2025), *Traffic Index by City 2025*; OCDE (2023), *Estudios económicos de la OCDE: Costa Rica 2023*.

## Limitaciones

- Modelo simplificado: dos fases, sin peatones, giros por separado, accidentes ni coordinación con otras intersecciones.
- Los datos reales son de un solo cruce y de horas pico, y solo cuentan los vehículos que lograron cruzar.
- Los parámetros (flujo de saturación de 1 800 veh/h por carril, 8 s de transición) son valores típicos, no calibrados con datos locales.

