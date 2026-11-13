# config/ — Configuración

Carpeta reservada para la configuración del proyecto. Por ahora **los parámetros del modelo están definidos
dentro del código**, en la lista `params` al inicio de `cod/optimizacion_semaforos.R`, y la aplicación Shiny
permite cambiarlos en el panel "Mostrar parámetros avanzados".

## Parámetros del modelo y sus valores por defecto

| Parámetro | Valor | Significado |
|---|---|---|
| `s` | 1800 | Flujo de saturación: vehículos por hora que pueden salir por cada carril con luz verde |
| `L` | 8 s | Tiempo de transición y despeje por ciclo (4 s después de cada verde) |
| `g_min` | 10 s | Verde mínimo permitido por fase |
| `g_max` | 90 s | Verde máximo permitido por fase |
| `C_max` | 150 s | Duración máxima del ciclo |
| `g_base` | 30 s | Verde de cada fase en el reparto equitativo de referencia |
| `T_sim` | 3600 s | Duración de cada simulación (una hora) |
| `n_rep` | 20 | Repeticiones de la simulación por configuración (la app usa 10 por defecto) |
| `paso` | 5 s | Paso de la búsqueda en rejilla (luego se refina de 1 en 1 segundo) |
| `semilla` | 2025 | Semilla aleatoria, para que los resultados se puedan repetir |

El ciclo del semáforo es `C = g.NS + g.EO + L`.

## Notas

- Los valores de `s` y `L` son típicos de ingeniería de tránsito, no calibrados con datos locales.
- Si estos parámetros se mueven a un archivo propio en esta carpeta (por ejemplo `parametros.csv`), hay que
  actualizar `cod/optimizacion_semaforos.R` para que lo lea, y documentarlo aquí.