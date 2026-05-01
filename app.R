library(shiny)
library(bslib)
library(plotly)
library(DT)
library(ggfortify)
library(shinyAce)

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
        # Simulation UI placeholders
        uiOutput("sim_controls")
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
  # Server logic to be implemented
  output$main_plot <- renderPlotly({
    plot_ly(type = "scatter", mode = "markers") |> 
      layout(title = "En attente de données...")
  })
}

shinyApp(ui, server)
