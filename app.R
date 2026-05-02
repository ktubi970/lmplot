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
