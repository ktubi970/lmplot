library(shiny)
library(bslib)
library(plotly)
library(DT)
library(ggfortify)
library(shinyAce)
library(shinyWidgets)

# Modules
source("R/mod_simulation.R")

ui <- page_sidebar(
  title = "LM Plot Explorer",
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  sidebar = sidebar(
    title = "Configuration",
    accordion(
      accordion_panel(
        "RÉGRESSION LINÉAIRE",
        radioButtons("model_type", "Type:", choices = c("lm" = "lm"), selected = "lm")
      ),
      accordion_panel(
        "MODÈLES GÉNÉRALISÉS",
        "Bientôt disponible..."
      ),
      accordion_panel(
        "EFFETS MIXTES",
        "Bientôt disponible..."
      )
    ),
    actionButton("refresh", "Générer & Ajuster", class = "btn-success w-100 mt-3")
  ),
  layout_column_wrap(
    width = 1,
    card(
      card_header("Régression Interactive"),
      plotlyOutput("main_plot", height = "350px")
    ),
    layout_column_wrap(
      width = 1/2,
      card(
        card_header("Simulation & Code"),
        sim_ui("sim_mod")
      ),
      navset_card_tab(
        title = "Diagnostics & Résultats",
        nav_panel("Diagnostics", plotOutput("diag_plot")),
        nav_panel("Données", DTOutput("data_table")),
        nav_panel("Summary", verbatimTextOutput("model_summary"))
      )
    )
  )
)

server <- function(input, output, session) {
  # Server logic
  sim_data <- sim_server("sim_mod")
  
  output$main_plot <- renderPlotly({
    df <- sim_data()
    req(df)
    
    p <- ggplot(df, aes(x = x, y = y)) +
      geom_point(color = "#3498db", alpha = 0.6) +
      geom_smooth(method = "lm", color = "#e74c3c", se = TRUE) +
      theme_minimal()
      
    ggplotly(p)
  })
  
  output$data_table <- renderDT({
    req(sim_data())
    datatable(sim_data(), options = list(pageLength = 5))
  })
  
  output$diag_plot <- renderPlot({
    df <- sim_data()
    req(df)
    fit <- lm(y ~ x, data = df)
    autoplot(fit, which = 1:4, ncol = 2) + theme_minimal()
  })
  
  output$model_summary <- renderPrint({
    df <- sim_data()
    req(df)
    summary(lm(y ~ x, data = df))
  })
}

shinyApp(ui, server)
