# Main entry point for the Shiny 3‑D Linear Model Explorer
# The UI, server logic and Plotly 3‑D plot will be added later.

library(shiny)
library(plotly)
library(shinythemes)

ui <- fluidPage(
  theme = shinythemes::shinytheme("darkly"),
  tags$head(tags$link(rel = "stylesheet", href = "style.css")),
  titlePanel("Random 3‑D Linear Model Explorer"),
  sidebarLayout(
    sidebarPanel(
      actionButton("regen", "Regenerate Data"),
      checkboxInput("show_plane", "Show Regression Plane", TRUE),
      downloadButton("download_csv", "Export CSV")
    ),
    mainPanel(
      plotlyOutput("plot3d", height = "700px")
    )
  )
)

# Helper: generate random data ------------------------------------------------
generate_data <- function(n = 200) {
  set.seed(as.numeric(Sys.time()))
  x <- runif(n, 0, 10)
  y <- runif(n, 0, 10)
  eps <- rnorm(n, 0, 1)
  z <- 2 + 1.5 * x - 0.8 * y + eps
  data.frame(X = x, Y = y, Z = z)
}

# Helper: fit linear model ----------------------------------------------------
fit_model <- function(df) {
  lm(Z ~ X + Y, data = df)
}

# Server Logic ----------------------------------------------------------------
server <- function(input, output, session) {
  data <- reactiveVal(generate_data())
  model <- reactive({ fit_model(data()) })

  observeEvent(input$regen, {
    data(generate_data())
  })

  output$plot3d <- renderPlotly({
    df <- data()
    coeffs <- coef(model())
    scatter <- plot_ly(df, x = ~X, y = ~Y, z = ~Z,
                       type = "scatter3d", mode = "markers",
                       marker = list(color = "#ff6f91", size = 4))
    p <- scatter
    if (input$show_plane) {
      grid <- seq(0, 10, length.out = 30)
      grid_df <- expand.grid(X = grid, Y = grid)
      grid_df$Z <- coeffs[1] + coeffs[2] * grid_df$X + coeffs[3] * grid_df$Y
      surface_mat <- matrix(grid_df$Z, nrow = length(grid), ncol = length(grid))
      p <- add_surface(p, x = grid, y = grid, z = surface_mat,
                       opacity = 0.6, showscale = FALSE,
                       colorscale = list(c(0, "#4e79a7"), c(1, "#a0cbe8")))
    }
    p %>% layout(
      title = sprintf("Linear Model: Z = %.2f + %.2f·X + %.2f·Y",
                      coeffs[1], coeffs[2], coeffs[3]),
      scene = list(xaxis = list(title = "X"),
                   yaxis = list(title = "Y"),
                   zaxis = list(title = "Z")),
      paper_bgcolor = "#1e1e2f",
      plot_bgcolor = "#24243d"
    )
  })

  output$download_csv <- downloadHandler(
    filename = function() { paste0("lm_data_", Sys.Date(), ".csv") },
    content = function(file) {
      write.csv(data(), file, row.names = FALSE)
    }
  )
}

shinyApp(ui, server)
