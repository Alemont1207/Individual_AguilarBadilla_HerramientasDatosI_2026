# info/ — Documentación de apoyo

Documentos que explican el contexto del proyecto y de dónde salen los datos. No contienen código ni resultados.

## Qué se guarda aquí

| Documento | Para qué sirve |
|---|---|
| Informe del MOPT (`MOPT-03-05-01-0587-2023.pdf`) | Fuente de los datos reales de tránsito (intersección de la RN 124 con la RN 122, San Antonio de Alajuela). Es un documento público. |
| Planteamiento del proyecto (Avance I) | Tema, justificación, objetivos y marco metodológico del proyecto. |

## Objetivos del proyecto (resumen)

**Objetivo general:** desarrollar un modelo computacional en R que permita optimizar la distribución de los
tiempos semafóricos en una intersección, considerando distintas condiciones de flujo vehicular, para minimizar
el tiempo promedio de espera de los vehículos.

**Objetivos específicos:**

1. Identificar las variables relacionadas con el funcionamiento de una intersección semaforizada y seleccionar las necesarias para el modelo.
2. Construir en R un modelo simplificado que simule el flujo vehicular y estime indicadores de congestión.
3. Implementar un procedimiento de optimización de los tiempos de las fases.
4. Evaluar el modelo en distintos escenarios de demanda.
5. Desarrollar una aplicación interactiva en Shiny para introducir condiciones de flujo y ver la configuración recomendada.

## Fuentes citadas

- MOPT, Dirección General de Ingeniería de Tránsito (2023). *Análisis de intersección Ruta Nacional N.° 124 con Ruta Nacional N.° 122, San Antonio, Alajuela* (informe MOPT-03-05-01-0587-2023).
- Numbeo (2025). *Traffic Index by City 2025*.