library(shiny)
library(shinyWidgets)
library(shinyAce)

sim_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(
      class = "d-flex justify-content-between align-items-center mb-3",
      span(class = "label", "Mode de simulation"),
      switchInput(
        ns("expert_mode"),
        value = FALSE,
        size = "small",
        onLabel = "Expert",
        offLabel = "Standard"
      )
    ),
    uiOutput(ns("controls_ui"))
  )
}

sim_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    output$controls_ui <- renderUI({
      if (!isTRUE(input$expert_mode)) {
        tagList(
          sliderInput(ns("beta1"), "Pente (beta1)", min = -2, max = 2, value = 0.5, step = 0.1),
          sliderInput(ns("sigma"), "Bruit (sigma)", min = 0.1, max = 5, value = 1, step = 0.1),
          numericInput(ns("n"), "Taille d'echantillon (n)", value = 100, min = 10, max = 1000),
          numericInput(ns("seed"), "Graine (Seed)", value = 123)
        )
      } else {
        aceEditor(
          ns("code"),
          value = "set.seed(input$seed)\nn <- input$n\nx <- rnorm(n)\ny <- 2 + 0.5*x + rnorm(n, 0, 1)\ndata.frame(x=x, y=y)",
          mode = "r",
          theme = "monokai",
          height = "200px"
        )
      }
    })

    reactive_data <- reactive({
      if (!isTRUE(input$expert_mode)) {
        req(input$beta1, input$sigma, input$n, input$seed)
        set.seed(input$seed)
        x <- rnorm(input$n)
        y <- 2 + input$beta1 * x + rnorm(input$n, 0, input$sigma)
        data.frame(x = x, y = y)
      } else {
        req(input$code)
        env <- new.env()
        env$input <- input
        tryCatch({
          eval(parse(text = input$code), envir = env)
        }, error = function(e) {
          showNotification(paste("Erreur dans le code expert:", e$message), type = "error")
          NULL
        })
      }
    })

    return(reactive_data)
  })
}
