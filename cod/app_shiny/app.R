# =============================================================================
# Aplicación Shiny: Optimización de tiempos semafóricos
# -----------------------------------------------------------------------------
# Objetivo específico 5 del proyecto: una aplicación interactiva que permita
# introducir distintas condiciones de flujo vehicular, ejecutar la optimización
# y visualizar la configuración semafórica recomendada y los indicadores.
#
# Requiere el paquete 'shiny' y el archivo cod/modelo_semaforos.R.
# Para ejecutarla:   shiny::runApp("cod/app_shiny")   (o botón "Run App" en RStudio)
# =============================================================================

library(shiny)

# =============================================================================
# 1. MODELO (compartido con el script de análisis)
# =============================================================================
# Está en cod/modelo_semaforos.R. La app busca el archivo un nivel arriba de
# su carpeta (cod/app_shiny/ -> cod/) y, por si acaso, en otras ubicaciones.
ruta_modelo <- c("../modelo_semaforos.R", "cod/modelo_semaforos.R", "modelo_semaforos.R")
ruta_modelo <- ruta_modelo[file.exists(ruta_modelo)][1]
if (is.na(ruta_modelo))
  stop("No se encontró modelo_semaforos.R. Debe estar en la carpeta cod/, ",
       "un nivel arriba de la carpeta de la app.")
source(ruta_modelo, local = TRUE)

# Escenarios predefinidos (los dos primeros son datos reales del MOPT 2023)
ESCENARIOS <- data.frame(
  nombre = c("MOPT mañana (7:30-8:30)", "MOPT tarde (16:30-17:30)",
             "Flujo bajo", "Flujo equilibrado",
             "Predominio Norte-Sur", "Alta demanda"),
  q.NS = c(298, 384, 300, 800, 1300, 1200),
  q.EO = c(955, 699, 250, 800,  400, 1000),
  n.NS = 2, n.EO = 2,
  stringsAsFactors = FALSE
)

# =============================================================================
# 2. INTERFAZ
# =============================================================================
fmt <- function(x, d = 1) format(round(x, d), decimal.mark = ",", nsmall = d)

css <- "
body { background:#f6f7f9; }
.tarjeta { background:#fff; border-radius:10px; padding:14px 10px; text-align:center;
           box-shadow:0 1px 3px rgba(0,0,0,.12); margin-bottom:12px; }
.tarjeta .num { font-size:30px; font-weight:700; line-height:1.1; }
.tarjeta .lab { font-size:12px; color:#666; text-transform:uppercase; letter-spacing:.04em; }
.verde { color:#2e8b57; } .azul { color:#4682b4; } .rojo { color:#e5533d; } .gris { color:#444; }
.caja { background:#fff; border-radius:10px; padding:14px 18px; margin-bottom:12px;
        box-shadow:0 1px 3px rgba(0,0,0,.12); }
.aviso { background:#fff4e5; border-left:4px solid #f0a030; padding:10px 14px;
         border-radius:6px; margin-bottom:12px; }
.semaforo { display:inline-block; width:14px; height:14px; border-radius:50%; margin-right:3px; }
"

ui <- fluidPage(
  tags$head(tags$style(HTML(css))),
  titlePanel(
    div(span(class = "semaforo", style = "background:#e5533d"),
        span(class = "semaforo", style = "background:#f0c030"),
        span(class = "semaforo", style = "background:#2e8b57"),
        "Optimización de tiempos semafóricos")),
  p("Modifique el flujo vehicular y las características de la intersección; ",
    "la aplicación busca el reparto de luz verde que minimiza el tiempo ",
    "promedio de espera de los vehículos."),

  sidebarLayout(
    sidebarPanel(
      width = 3,
      selectInput("preset", "Escenario predefinido",
                  choices = c("Personalizado", ESCENARIOS$nombre),
                  selected = ESCENARIOS$nombre[1]),
      h4("Flujo vehicular (veh/h)"),
      numericInput("q.NS", "Norte-Sur", value = ESCENARIOS$q.NS[1], min = 0, max = 4000, step = 50),
      numericInput("q.EO", "Este-Oeste", value = ESCENARIOS$q.EO[1], min = 0, max = 4000, step = 50),
      h4("Carriles que atiende cada fase"),
      numericInput("n.NS", "Norte-Sur", value = 2, min = 1, max = 6, step = 1),
      numericInput("n.EO", "Este-Oeste", value = 2, min = 1, max = 6, step = 1),
      checkboxInput("avanzado", "Mostrar parámetros avanzados", FALSE),
      conditionalPanel(
        "input.avanzado",
        numericInput("s", "Flujo de saturación (veh/h/carril)", 1800, min = 1000, max = 2400, step = 50),
        numericInput("L", "Transición/despeje por ciclo L (s)", 8, min = 0, max = 30, step = 1),
        numericInput("g_min", "Verde mínimo (s)", 10, min = 5, max = 60, step = 1),
        numericInput("g_max", "Verde máximo (s)", 90, min = 20, max = 180, step = 5),
        numericInput("C_max", "Ciclo máximo (s)", 150, min = 40, max = 240, step = 5),
        numericInput("g_base", "Verde del reparto equitativo (s)", 30, min = 5, max = 90, step = 1),
        numericInput("T_sim", "Duración simulada (s)", 3600, min = 600, max = 7200, step = 600),
        numericInput("n_rep", "Repeticiones de la simulación", 10, min = 2, max = 50, step = 1),
        numericInput("paso", "Paso de la búsqueda (s)", 5, min = 1, max = 10, step = 1),
        numericInput("semilla", "Semilla aleatoria", 2025, step = 1)
      ),
      actionButton("optimizar", "Optimizar", class = "btn-success btn-lg",
                   style = "width:100%; margin-top:8px;"),
      p(style = "color:#777; font-size:12px; margin-top:8px;",
        "Con 10 repeticiones el cálculo tarda unos segundos. ",
        "Más repeticiones dan resultados más estables.")
    ),

    mainPanel(
      width = 9,
      tabsetPanel(
        tabPanel("Resultado recomendado",
                 br(),
                 uiOutput("aviso"),
                 uiOutput("tarjetas"),
                 uiOutput("interpretacion"),
                 h4("Indicadores por configuración"),
                 tableOutput("tabla")),
        tabPanel("Gráficos",
                 br(),
                 h4("Tiempo promedio de espera"),
                 plotOutput("g_espera", height = "300px"),
                 h4("Filas de vehículos durante los primeros 15 minutos"),
                 plotOutput("g_cola", height = "300px"),
                 h4("Mapa de búsqueda"),
                 p("Cada cuadro es una combinación de verde Norte-Sur y Este-Oeste; ",
                   "el color indica el tiempo promedio de espera (más claro = menos espera)."),
                 plotOutput("g_mapa", height = "420px")),
        tabPanel("Cómo funciona",
                 br(),
                 div(class = "caja",
                     h4("El modelo"),
                     p("Una intersección con dos fases: cuando una calle tiene luz verde, la otra espera. ",
                       "Entre fases hay un tiempo de transición L. El ciclo dura ",
                       strong("C = g.NS + g.EO + L"), "."),
                     p("Se simula el período segundo a segundo. Los vehículos llegan al azar según el flujo de ",
                       "cada calle; con verde salen al ritmo del flujo de saturación por carril y el resto ",
                       "forma fila (el primero en llegar es el primero en salir)."),
                     p("El indicador principal es el tiempo promedio de espera ",
                       strong("W = (1/n) Σ wᵢ"), ", donde wᵢ es la espera del vehículo i."),
                     h4("La optimización"),
                     p("Se prueban combinaciones de g.NS y g.EO entre el verde mínimo y el máximo ",
                       "(con ciclo máximo), primero en una rejilla gruesa y luego refinando de 1 en 1 segundo. ",
                       "Se elige la de menor W. La configuración elegida se valida con llegadas nuevas y se compara ",
                       "con un reparto equitativo y con la fórmula de Webster."),
                     h4("Limitaciones"),
                     p("Modelo simplificado: no incluye peatones, giros por separado, accidentes ni coordinación ",
                       "con otras intersecciones. Los resultados sirven para comparar formas de repartir el verde, ",
                       "no para decidir si conviene instalar un semáforo."),
                     p(em("Datos reales: MOPT (2023), informe MOPT-03-05-01-0587-2023, RN 124 con RN 122, San Antonio de Alajuela.")))
        )
      )
    )
  )
)

# =============================================================================
# 3. SERVIDOR
# =============================================================================
server <- function(input, output, session) {

  # Al elegir un escenario predefinido, se rellenan los campos
  observeEvent(input$preset, {
    if (input$preset != "Personalizado") {
      e <- ESCENARIOS[ESCENARIOS$nombre == input$preset, ]
      updateNumericInput(session, "q.NS", value = e$q.NS)
      updateNumericInput(session, "q.EO", value = e$q.EO)
      updateNumericInput(session, "n.NS", value = e$n.NS)
      updateNumericInput(session, "n.EO", value = e$n.EO)
    }
  })

  # Ejecuta la optimización al presionar el botón (y una vez al abrir la app)
  resultado <- eventReactive(input$optimizar, {
    validate(
      need(is.numeric(input$q.NS) && is.numeric(input$q.EO) &&
             input$q.NS >= 0 && input$q.EO >= 0, "Los flujos deben ser números no negativos."),
      need(input$q.NS + input$q.EO > 0, "Al menos una dirección debe tener tránsito."),
      need(input$n.NS >= 1 && input$n.EO >= 1, "Cada fase necesita al menos un carril."),
      need(input$g_min < input$g_max, "El verde mínimo debe ser menor que el máximo."),
      need(2 * input$g_min + input$L <= input$C_max,
           "El ciclo máximo es muy corto para respetar el verde mínimo de ambas fases."),
      need(input$paso >= 1 && input$n_rep >= 1, "Revise paso y repeticiones.")
    )
    esc <- list(q.NS = input$q.NS, q.EO = input$q.EO,
                n.NS = input$n.NS, n.EO = input$n.EO)
    p <- list(s = input$s, L = input$L, g_min = input$g_min, g_max = input$g_max,
              C_max = input$C_max, g_base = input$g_base, T_sim = input$T_sim,
              n_rep = input$n_rep, paso = input$paso, semilla = input$semilla)

    r <- withProgress(message = "Optimizando…", detail = "Probando combinaciones de verde",
                      value = 0, {
      out <- recomendar_semaforo(esc, p, cb = function(f) setProgress(value = f))
      setProgress(value = 1)
      out
    })
    r$esc <- esc; r$p <- p
    r$Y <- esc$q.NS / (p$s * esc$n.NS) + esc$q.EO / (p$s * esc$n.EO)
    r
  }, ignoreNULL = FALSE)

  # --- Avisos -----------------------------------------------------------------
  output$aviso <- renderUI({
    r <- resultado()
    av <- character(0)
    if (r$Y >= 0.95)
      av <- c(av, "La intersección está saturada (carga ≥ 0,95): la demanda es casi igual o mayor que la capacidad y las filas crecen, por lo que ningún reparto de verde elimina la congestión.")
    else if (r$Y >= 0.8)
      av <- c(av, "La intersección está muy cargada (carga ≥ 0,8): pequeñas variaciones del flujo pueden generar filas largas.")
    if (r$res.opt["no_atendidos"] > 0.05 * r$esc$q.NS * r$p$T_sim / 3600 + 0.05 * r$esc$q.EO * r$p$T_sim / 3600)
      av <- c(av, "Una parte importante de los vehículos no alcanza a cruzar durante el período simulado.")
    if (any(r$g.opt == r$p$g_min))
      av <- c(av, paste0("Una de las fases quedó en el verde mínimo permitido (", r$p$g_min,
                         " s). Si el modelo quisiera menos, el límite lo impone la restricción de verde mínimo."))
    if (length(av) == 0) return(NULL)
    div(class = "aviso", lapply(av, function(x) p(x, style = "margin:2px 0;")))
  })

  # --- Tarjetas con la configuración recomendada ------------------------------
  output$tarjetas <- renderUI({
    r <- resultado()
    mejora <- 100 * (r$res.eq["W"] - r$res.opt["W"]) / r$res.eq["W"]
    tar <- function(num, lab, clase)
      column(2, div(class = "tarjeta", div(class = paste("num", clase), num), div(class = "lab", lab)))
    fluidRow(
      tar(paste(r$g.opt["g.NS"], "s"), "Verde Norte-Sur", "azul"),
      tar(paste(r$g.opt["g.EO"], "s"), "Verde Este-Oeste", "rojo"),
      tar(paste(r$res.opt["C"], "s"), "Ciclo total", "gris"),
      column(3, div(class = "tarjeta", div(class = "num verde", paste(fmt(r$res.opt["W"]), "s")),
                    div(class = "lab", "Espera promedio por vehículo"))),
      column(3, div(class = "tarjeta", div(class = "num verde", paste0(fmt(mejora, 0), " %")),
                    div(class = "lab", paste0("Menos espera que ", r$p$g_base, " s / ", r$p$g_base, " s"))))
    )
  })

  # --- Interpretación en lenguaje sencillo ------------------------------------
  output$interpretacion <- renderUI({
    r <- resultado(); e <- r$esc
    pNS <- 100 * e$q.NS / (e$q.NS + e$q.EO)
    mayor <- if (r$g.opt["g.NS"] > r$g.opt["g.EO"]) "Norte-Sur"
             else if (r$g.opt["g.NS"] < r$g.opt["g.EO"]) "Este-Oeste" else NA
    txt <- paste0(
      "Con ", fmt(e$q.NS, 0), " veh/h en Norte-Sur y ", fmt(e$q.EO, 0), " veh/h en Este-Oeste (",
      fmt(pNS, 0), " % y ", fmt(100 - pNS, 0), " % del tránsito), se recomienda dar ",
      r$g.opt["g.NS"], " s de verde a Norte-Sur y ", r$g.opt["g.EO"], " s a Este-Oeste, en un ciclo de ",
      r$res.opt["C"], " s. ",
      if (!is.na(mayor)) paste0("La dirección ", mayor, " recibe más verde porque tiene más demanda por atender. ")
      else "Ambas direcciones reciben el mismo verde porque su demanda es similar. ",
      "Cada vehículo espera en promedio ", fmt(r$res.opt["W"]), " s, frente a ",
      fmt(r$res.eq["W"]), " s con el reparto equitativo y ", fmt(r$res.web["W"]), " s con Webster.")
    div(class = "caja", strong("En palabras simples"), p(txt))
  })

  # --- Tabla de indicadores ---------------------------------------------------
  output$tabla <- renderTable({
    r <- resultado()
    fila <- function(nombre, g, res)
      data.frame(
        `Configuración` = nombre,
        `Verde N-S (s)` = as.character(g["g.NS"]),
        `Verde E-O (s)` = as.character(g["g.EO"]),
        `Ciclo (s)` = as.character(res["C"]),
        `W global (s/veh)` = fmt(res["W"]),
        `W Norte-Sur` = fmt(res["W.NS"]),
        `W Este-Oeste` = fmt(res["W.EO"]),
        `No atendidos (veh)` = fmt(res["no_atendidos"]),
        check.names = FALSE)
    rbind(fila("Optimizada", r$g.opt, r$res.opt),
          fila("Webster (referencia)", r$g.web, r$res.web),
          fila(paste0("Equitativa (", r$p$g_base, "/", r$p$g_base, ")"), r$g.eq, r$res.eq))
  }, striped = TRUE, bordered = TRUE, align = "lrrrrrrr")

  # --- Gráfico: espera por configuración y dirección --------------------------
  output$g_espera <- renderPlot({
    r <- resultado()
    m <- rbind(c(r$res.eq["W"],  r$res.eq["W.NS"],  r$res.eq["W.EO"]),
               c(r$res.web["W"], r$res.web["W.NS"], r$res.web["W.EO"]),
               c(r$res.opt["W"], r$res.opt["W.NS"], r$res.opt["W.EO"]))
    m[is.na(m)] <- 0
    cols <- c("grey70", "goldenrod", "seagreen")
    par(mar = c(3, 4.5, 1, 1), las = 1)
    barplot(m, beside = TRUE, col = cols, names.arg = c("Global", "Norte-Sur", "Este-Oeste"),
            ylab = "Espera promedio (s/veh)", ylim = c(0, max(m) * 1.3))
    legend("top", legend = c("Equitativa", "Webster", "Optimizada"), fill = cols,
           horiz = TRUE, bty = "n")
  })

  # --- Gráfico: filas en el tiempo --------------------------------------------
  output$g_cola <- renderPlot({
    r <- resultado()
    ver <- min(900, r$p$T_sim)
    a <- serie_cola(r$g.opt["g.NS"], r$g.opt["g.EO"], r$esc, r$arr_val, r$p)
    b <- serie_cola(r$g.eq["g.NS"],  r$g.eq["g.EO"],  r$esc, r$arr_val, r$p)
    a <- a[a$t <= ver, ]; b <- b[b$t <= ver, ]
    ymax <- max(a$NS, a$EO, b$NS, b$EO, 1)
    par(mfrow = c(1, 2), mar = c(4, 4.5, 3, 1), las = 1)
    for (dir in c("NS", "EO")) {
      plot(b$t / 60, b[[dir]], type = "l", col = "grey55", lwd = 1.5, ylim = c(0, ymax * 1.05),
           xlab = "Tiempo (min)", ylab = "Vehículos en fila",
           main = if (dir == "NS") "Norte-Sur" else "Este-Oeste")
      lines(a$t / 60, a[[dir]], col = "seagreen", lwd = 2)
      if (dir == "NS")
        legend("topright", legend = c("Equitativa", "Optimizada"),
               col = c("grey55", "seagreen"), lwd = 2, bty = "n", cex = 0.85)
    }
  })

  # --- Gráfico: mapa de búsqueda ----------------------------------------------
  output$g_mapa <- renderPlot({
    r <- resultado()
    rj <- r$rejilla
    gs <- sort(unique(c(rj$g.NS, rj$g.EO)))
    z <- matrix(NA_real_, length(gs), length(gs))
    z[cbind(match(rj$g.NS, gs), match(rj$g.EO, gs))] <- rj$W
    par(mar = c(4.5, 4.5, 1, 1), las = 1)
    image(gs, gs, z, col = hcl.colors(50, "YlOrRd", rev = TRUE),
          xlab = "Verde Norte-Sur (s)", ylab = "Verde Este-Oeste (s)")
    points(r$g.opt["g.NS"], r$g.opt["g.EO"], pch = 4, lwd = 3, cex = 2)
    points(r$g.web["g.NS"], r$g.web["g.EO"], pch = 5, lwd = 2, cex = 1.6)
    points(r$g.eq["g.NS"],  r$g.eq["g.EO"],  pch = 1, lwd = 2, cex = 1.6)
    legend("topright", legend = c("Óptimo", "Webster", "Equitativa"),
           pch = c(4, 5, 1), pt.lwd = 2, bg = "white")
  })
}

shinyApp(ui, server)
