# =============================================================================
# Modelo de la intersección semaforizada (módulo compartido)
# -----------------------------------------------------------------------------
# Contiene SOLO las funciones del modelo, sin ejecutar nada. Lo usan:
#   - cod/optimizacion_semaforos.R  (análisis y reporte)
#   - cod/app_shiny/app.R           (aplicación Shiny)
# Así el modelo vive en un único lugar y ambos dan los mismos resultados.
#
# Funciones:
#   generar_llegadas()     llegadas aleatorias (Poisson) por segundo
#   espera_direccion()     fila y espera w_i de cada vehículo en una dirección
#   evaluar_config()       indicadores de una configuración (g.NS, g.EO): W, W.NS, W.EO...
#   webster()              reparto de referencia (método de Webster)
#   evaluar_rejilla()      evalúa muchas combinaciones de verde
#   recomendar_semaforo()  optimización completa + validación
#   serie_cola()           longitud de la fila en el tiempo (para gráficos)
# =============================================================================

generar_llegadas <- function(q, T_sim, n_rep) {
  matrix(rpois(T_sim * n_rep, lambda = q / 3600), nrow = T_sim, ncol = n_rep)
}

# Cola de una dirección: espera de cada vehículo (w_i) y vehículos no atendidos
espera_direccion <- function(llegadas, inicio_verde, g, C, cap_seg) {
  T_sim <- length(llegadas)
  tau   <- (0:(T_sim - 1)) %% C
  verde <- (tau >= inicio_verde) & (tau < inicio_verde + g)
  S <- cumsum(verde * cap_seg)          # capacidad acumulada
  A <- cumsum(llegadas)                 # llegadas acumuladas
  D <- S + pmin(0, cummin(A - S))       # salidas acumuladas
  n <- A[T_sim]
  if (n == 0) return(list(w = numeric(0), no_atendidos = 0L))
  idx_llegada <- rep.int(seq_len(T_sim), llegadas)
  Dfl <- floor(D + 1e-9)
  idx_salida <- findInterval(seq_len(n) - 1, Dfl) + 1L
  atendido <- idx_salida <= T_sim
  idx_salida[!atendido] <- T_sim
  list(w = idx_salida - idx_llegada, no_atendidos = sum(!atendido))
}

# Indicadores de una configuración (g.NS, g.EO): W = (1/n) * sum(w_i)
evaluar_config <- function(g.NS, g.EO, esc, arr, p) {
  g.NS <- unname(g.NS); g.EO <- unname(g.EO)
  C      <- g.NS + g.EO + p$L
  cap.NS <- p$s * esc$n.NS / 3600
  cap.EO <- p$s * esc$n.EO / 3600
  suma <- c(NS = 0, EO = 0); n <- c(NS = 0, EO = 0); no_at <- 0
  for (r in seq_len(ncol(arr$NS))) {
    a <- espera_direccion(arr$NS[, r], 0,              g.NS, C, cap.NS)
    b <- espera_direccion(arr$EO[, r], g.NS + p$L / 2, g.EO, C, cap.EO)
    suma["NS"] <- suma["NS"] + sum(a$w); n["NS"] <- n["NS"] + length(a$w)
    suma["EO"] <- suma["EO"] + sum(b$w); n["EO"] <- n["EO"] + length(b$w)
    no_at <- no_at + a$no_atendidos + b$no_atendidos
  }
  c(W            = unname(sum(suma) / sum(n)),
    W.NS         = unname(if (n["NS"] > 0) suma["NS"] / n["NS"] else NA),
    W.EO         = unname(if (n["EO"] > 0) suma["EO"] / n["EO"] else NA),
    no_atendidos = unname(no_at / ncol(arr$NS)),
    C            = unname(C))
}

# Referencia clásica de Webster
webster <- function(esc, p) {
  y.NS <- esc$q.NS / (p$s * esc$n.NS)
  y.EO <- esc$q.EO / (p$s * esc$n.EO)
  Y    <- y.NS + y.EO
  C0   <- if (Y < 0.95) (1.5 * p$L + 5) / (1 - Y) else p$C_max
  C0   <- min(C0, p$C_max)
  g_ef <- C0 - p$L
  g.NS <- if (Y > 0) round(g_ef * y.NS / Y) else p$g_min
  g.EO <- round(g_ef - g.NS)
  c(g.NS = min(max(g.NS, p$g_min), p$g_max),
    g.EO = min(max(g.EO, p$g_min), p$g_max))
}

evaluar_rejilla <- function(rej, esc, arr, p, cb = NULL) {
  n <- nrow(rej)
  out <- matrix(NA_real_, n, 5,
                dimnames = list(NULL, c("W", "W.NS", "W.EO", "no_atendidos", "C")))
  for (i in seq_len(n)) {
    out[i, ] <- evaluar_config(rej$g.NS[i], rej$g.EO[i], esc, arr, p)
    if (!is.null(cb) && i %% 10 == 0) cb(i / n)
  }
  cbind(rej, out)
}

# Optimización: rejilla gruesa + refinamiento local de 1 s + validación
recomendar_semaforo <- function(esc, p, cb = NULL) {
  set.seed(p$semilla)
  arr_opt <- list(NS = generar_llegadas(esc$q.NS, p$T_sim, p$n_rep),
                  EO = generar_llegadas(esc$q.EO, p$T_sim, p$n_rep))
  set.seed(p$semilla + 1000)
  arr_val <- list(NS = generar_llegadas(esc$q.NS, p$T_sim, p$n_rep),
                  EO = generar_llegadas(esc$q.EO, p$T_sim, p$n_rep))

  factible <- function(rej) rej[rej$g.NS + rej$g.EO + p$L <= p$C_max, ]

  gs  <- seq(p$g_min, p$g_max, by = p$paso)
  rej <- factible(expand.grid(g.NS = gs, g.EO = gs))
  rej_eval <- evaluar_rejilla(rej, esc, arr_opt, p,
                              cb = if (!is.null(cb)) function(f) cb(0.85 * f))
  mejor <- rej_eval[which.min(rej_eval$W), ]

  if (p$paso > 1) {
    vec <- function(c0) seq(max(p$g_min, c0 - p$paso + 1),
                            min(p$g_max, c0 + p$paso - 1))
    fina <- factible(expand.grid(g.NS = vec(mejor$g.NS), g.EO = vec(mejor$g.EO)))
    fina_eval <- evaluar_rejilla(fina, esc, arr_opt, p)
    cand  <- rbind(mejor, fina_eval)
    mejor <- cand[which.min(cand$W), ]
  }
  if (!is.null(cb)) cb(0.92)

  g.opt <- c(g.NS = mejor$g.NS, g.EO = mejor$g.EO)
  g.web <- webster(esc, p)
  g.eq  <- c(g.NS = p$g_base, g.EO = p$g_base)
  val <- function(g) evaluar_config(g["g.NS"], g["g.EO"], esc, arr_val, p)

  list(g.opt = g.opt, g.web = g.web, g.eq = g.eq,
       res.opt = val(g.opt), res.web = val(g.web), res.eq = val(g.eq),
       rejilla = rej_eval, arr_val = arr_val)
}

# Longitud de la fila (vehículos) segundo a segundo, para una réplica
serie_cola <- function(g.NS, g.EO, esc, arr, p) {
  g.NS <- unname(g.NS); g.EO <- unname(g.EO)
  C <- g.NS + g.EO + p$L
  una <- function(llegadas, inicio, g, cap) {
    T_sim <- length(llegadas)
    tau   <- (0:(T_sim - 1)) %% C
    verde <- (tau >= inicio) & (tau < inicio + g)
    S <- cumsum(verde * cap); A <- cumsum(llegadas)
    D <- S + pmin(0, cummin(A - S))
    A - floor(D + 1e-9)
  }
  data.frame(
    t  = seq_len(nrow(arr$NS)),
    NS = una(arr$NS[, 1], 0,              g.NS, p$s * esc$n.NS / 3600),
    EO = una(arr$EO[, 1], g.NS + p$L / 2, g.EO, p$s * esc$n.EO / 3600))
}
