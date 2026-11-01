# =============================================================================
# Optimización de los tiempos semafóricos para la reducción de la congestión
# vehicular mediante R
# -----------------------------------------------------------------------------
# Intersección simplificada de dos fases (Norte-Sur y Este-Oeste).
#
# Estructura del programa (según el marco metodológico del Avance I):
#   0. Parámetros del modelo
#   1. Datos: importación de escenarios de demanda y análisis exploratorio
#   2. Simulación de la intersección (llegadas, filas, salidas, espera w_i)
#   3. Indicador de congestión: W = (1/n) * sum(w_i)
#   4. Optimización: min W(g.NS, g.EO) sujeto a restricciones
#   5. Evaluación en distintos escenarios de demanda
#   6. Gráficos y resultados
#
# El modelo (cod/modelo_semaforos.R) es compartido con la aplicación Shiny
# (cod/app_shiny/app.R); este script se encarga del análisis y de los gráficos.
#
# Solo usa R base (no requiere instalar paquetes).
# =============================================================================

rm(list = ls())

# Estructura del proyecto: cod/ (código), data/ (datos), res/ (resultados)
# Se ejecuta desde la raíz del proyecto (si se abre desde cod/, se sube un nivel).
if (basename(getwd()) == "cod") setwd("..")
DIR_COD  <- "cod"
DIR_DATA <- "data"
DIR_RES  <- "res"
dir.create(DIR_DATA, showWarnings = FALSE)
dir.create(DIR_RES,  showWarnings = FALSE)

# Modelo compartido con la aplicación Shiny
source(file.path(DIR_COD, "modelo_semaforos.R"))

# -----------------------------------------------------------------------------
# 0. PARÁMETROS DEL MODELO
# -----------------------------------------------------------------------------
params <- list(
  s       = 1800,   # flujo de saturación (veh/hora/carril)
  L       = 8,      # tiempo de transición/despeje por ciclo (s); se reparte
                    #   mitad tras cada fase (L/2 después de cada verde)
  g_min   = 10,     # verde mínimo por fase (s)
  g_max   = 90,     # verde máximo por fase (s)
  C_max   = 150,    # duración máxima del ciclo (s)
  g_base  = 30,     # verde de la configuración de referencia "equitativa" (s)
  T_sim   = 3600,   # período simulado (s)
  n_rep   = 20,     # réplicas estocásticas por configuración
  paso    = 5,      # paso de la rejilla gruesa de búsqueda (s)
  semilla = 2025    # semilla para reproducibilidad
)

# -----------------------------------------------------------------------------
# 1. DATOS: IMPORTACIÓN Y ANÁLISIS EXPLORATORIO
# -----------------------------------------------------------------------------
# Si existe "datos_flujo.csv" se importa (por ejemplo con datos oficiales de
# tránsito de Costa Rica). El archivo debe tener las columnas:
#   escenario, q.NS, q.EO, n.NS, n.EO
# Si no existe, se construyen escenarios simulados de referencia y se guarda el
# archivo como plantilla para reemplazarlo luego con datos reales.

cargar_escenarios <- function(ruta = file.path(DIR_DATA, "datos_flujo.csv")) {
  if (file.exists(ruta)) {
    esc <- read.csv(ruta, stringsAsFactors = FALSE, check.names = FALSE)
    cat("Datos importados desde:", ruta, "\n")
  } else {
    esc <- data.frame(
      escenario = c("Flujo bajo", "Flujo equilibrado",
                    "Predominio Norte-Sur", "Alta demanda"),
      q.NS = c(300,  800, 1300, 1200),   # vehículos/hora
      q.EO = c(250,  800,  400,  1000),
      n.NS = c(2, 2, 2, 2),              # carriles
      n.EO = c(2, 2, 2, 2),
      stringsAsFactors = FALSE
    )
    write.csv(esc, ruta, row.names = FALSE)
    cat("No se encontró", ruta, "- se usaron escenarios simulados",
        "y se guardó una plantilla.\n")
  }
  columnas <- c("escenario", "q.NS", "q.EO", "n.NS", "n.EO")
  faltan <- setdiff(columnas, names(esc))
  if (length(faltan) > 0)
    stop("Faltan columnas en los datos: ", paste(faltan, collapse = ", "))
  esc
}

analisis_exploratorio <- function(esc, p) {
  # Grado de saturación por flujo crítico: y = q / (s * n)
  esc$y.NS      <- esc$q.NS / (p$s * esc$n.NS)
  esc$y.EO      <- esc$q.EO / (p$s * esc$n.EO)
  esc$Y         <- esc$y.NS + esc$y.EO
  esc$prop.NS   <- esc$q.NS / (esc$q.NS + esc$q.EO)
  esc$dif.flujo <- esc$q.NS - esc$q.EO

  cat("\n================ ANÁLISIS EXPLORATORIO ================\n")
  print(esc, digits = 3, row.names = FALSE)
  cat("\nResumen de flujos (veh/h):\n")
  print(summary(esc[, c("q.NS", "q.EO")]))
  cat("\nNota: Y = y.NS + y.EO. Si Y se acerca o supera 1, la intersección\n",
      "no tiene capacidad suficiente y las filas crecen sin control.\n", sep = "")
  invisible(esc)
}

# -----------------------------------------------------------------------------
# 2-4. MODELO (simulación, indicador W y optimización)
# -----------------------------------------------------------------------------
# Las funciones del modelo están en cod/modelo_semaforos.R (se cargaron arriba):
# generar_llegadas(), espera_direccion(), evaluar_config(), webster(),
# evaluar_rejilla() y recomendar_semaforo(). Se separaron para que las use
# también la aplicación Shiny sin duplicar código.
#   Simulación: segundo a segundo; llegadas Poisson; cola FIFO; salida según
#   capacidad durante el verde. Indicador: W = (1/n) * sum(w_i).
#   Optimización: rejilla gruesa + refinamiento de 1 s, validada con llegadas nuevas.

# -----------------------------------------------------------------------------
# 5. EVALUACIÓN EN DISTINTOS ESCENARIOS DE DEMANDA
# -----------------------------------------------------------------------------
ejecutar_proyecto <- function(ruta_datos = file.path(DIR_DATA, "datos_flujo.csv"), p = params) {
  esc <- cargar_escenarios(ruta_datos)
  esc_exp <- analisis_exploratorio(esc, p)

  resultados <- vector("list", nrow(esc))
  tabla <- data.frame()

  cat("\n================ OPTIMIZACIÓN POR ESCENARIO ================\n")
  for (i in seq_len(nrow(esc))) {
    cat("Optimizando:", esc$escenario[i], "...\n")
    r <- recomendar_semaforo(esc[i, ], p)
    resultados[[i]] <- r

    tabla <- rbind(tabla, data.frame(
      escenario  = esc$escenario[i],
      q.NS = esc$q.NS[i], q.EO = esc$q.EO[i],
      g.NS.opt = r$g.opt["g.NS"], g.EO.opt = r$g.opt["g.EO"],
      C.opt = r$res.opt["C"],
      W.opt = r$res.opt["W"],
      g.NS.web = r$g.web["g.NS"], g.EO.web = r$g.web["g.EO"],
      W.webster = r$res.web["W"],
      W.equitativo = r$res.eq["W"],
      mejora.vs.equit.pct = 100 * (r$res.eq["W"] - r$res.opt["W"]) / r$res.eq["W"],
      no.atendidos.opt = r$res.opt["no_atendidos"],
      row.names = NULL
    ))
  }
  names(resultados) <- esc$escenario

  cat("\n================ RESULTADOS (validación con llegadas nuevas) ====\n")
  print(tabla, digits = 3, row.names = FALSE)
  write.csv(tabla, file.path(DIR_RES, "resultados_optimizacion.csv"), row.names = FALSE)

  graficar(esc_exp, resultados, tabla, p)
  cat("\nListo. Resultados y gráficos guardados en la carpeta 'res/'.\n")
  invisible(list(escenarios = esc_exp, resultados = resultados, tabla = tabla))
}

# -----------------------------------------------------------------------------
# 6. GRÁFICOS
# -----------------------------------------------------------------------------
# Abre un PNG (usa cairo si está disponible para que se vean bien las tildes)
abrir_png <- function(nombre, ancho, alto) {
  tipo <- if (isTRUE(capabilities("cairo"))) "cairo" else getOption("bitmapType")
  png(file.path(DIR_RES, nombre), width = ancho, height = alto,
      res = 110, type = tipo)
}

# Etiquetas de escenario en varias líneas para que no se solapen
etiquetas <- function(x, ancho = 12) {
  vapply(x, function(z) paste(strwrap(z, width = ancho), collapse = "\n"), "")
}

# Barras agrupadas con leyenda arriba (sin tapar las barras) y todas las etiquetas
barras_grupo <- function(m, nombres, cols, ylab, main, leyenda) {
  op <- par(mar = c(6, 4.5, 3, 1)); on.exit(par(op))
  barplot(m, beside = TRUE, col = cols, names.arg = etiquetas(nombres),
          cex.names = 0.8, ylab = ylab, main = main,
          ylim = c(0, max(m, na.rm = TRUE) * 1.3))
  legend("top", legend = leyenda, fill = cols, horiz = TRUE,
         bty = "n", cex = 0.85)
}

graficar <- function(esc, resultados, tabla, p) {

  # 6.1 Exploratorio: flujos por dirección y escenario
  abrir_png("01_flujos_por_escenario.png", 1000, 650)
  m <- rbind(esc$q.NS, esc$q.EO)
  barras_grupo(m, esc$escenario, c("steelblue", "tomato"), "Flujo (veh/h)",
               "Flujo vehicular por dirección y escenario",
               c("Norte-Sur", "Este-Oeste"))
  dev.off()

  # 6.2 Superficie de W(g.NS, g.EO) con el óptimo marcado
  abrir_png("02_superficie_W.png", 1100, 900)
  op <- par(mfrow = c(ceiling(length(resultados) / 2), 2), mar = c(4, 4, 3, 1))
  for (nm in names(resultados)) {
    rj <- resultados[[nm]]$rejilla
    gs <- sort(unique(c(rj$g.NS, rj$g.EO)))
    z <- matrix(NA_real_, length(gs), length(gs))
    z[cbind(match(rj$g.NS, gs), match(rj$g.EO, gs))] <- rj$W
    image(gs, gs, z, col = hcl.colors(50, "YlOrRd", rev = TRUE),
          xlab = "Verde Norte-Sur g.NS (s)", ylab = "Verde Este-Oeste g.EO (s)",
          main = nm)
    points(resultados[[nm]]$g.opt["g.NS"], resultados[[nm]]$g.opt["g.EO"],
           pch = 4, lwd = 3, cex = 1.8)
    legend("topright", legend = "Óptimo", pch = 4, bty = "n")
  }
  par(op); dev.off()

  # 6.3 Comparación de configuraciones
  abrir_png("03_comparacion_configuraciones.png", 1100, 700)
  m <- rbind(tabla$W.equitativo, tabla$W.webster, tabla$W.opt)
  barras_grupo(m, tabla$escenario, c("grey70", "goldenrod", "seagreen"),
               "Tiempo promedio de espera W (s/veh)",
               "Tiempo promedio de espera según configuración",
               c("Equitativa", "Webster", "Optimizada"))
  dev.off()

  # 6.4 Verde recomendado por escenario
  abrir_png("04_verde_recomendado.png", 1000, 650)
  m <- rbind(tabla$g.NS.opt, tabla$g.EO.opt)
  barras_grupo(m, tabla$escenario, c("steelblue", "tomato"), "Tiempo de verde (s)",
               "Distribución recomendada de los tiempos de verde",
               c("g.NS (Norte-Sur)", "g.EO (Este-Oeste)"))
  dev.off()
}

# -----------------------------------------------------------------------------
# EJECUCIÓN
# -----------------------------------------------------------------------------
salida <- ejecutar_proyecto()

# Ejemplo de uso puntual (la app Shiny usa esta misma función):
# r <- recomendar_semaforo(list(q.NS = 900, q.EO = 600, n.NS = 2, n.EO = 1), params)
# r$g.opt; r$res.opt
