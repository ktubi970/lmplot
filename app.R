app_root <- if (file.exists(file.path("R", "config.R"))) "." else ".."
for (file in c("config.R", "model_registry.R", "mod_model.R", "model_metrics.R",
    "model_diagnostics.R", "mod_simulation.R", "mod_examples.R", "mod_visualization.R",
    "mod_model_brain.R", "mod_pipeline.R", "mod_eli5.R", "app_coordinator.R",
    "mod_configuration.R", "mod_overview.R", "mod_diagnostics.R", "mod_data_provenance.R")) {
  source(file.path(app_root, "R", file), local = TRUE)
}
options(shiny.sanitize.errors = TRUE)
trusted_local <- identical(Sys.getenv("LMPLOT_TRUSTED_LOCAL"), "1")
services <- create_analysis_services()

ui <- bslib::page_sidebar(
  title = shiny::tags$header(shiny::h1("LM Plot Explorer"), shiny::span(APP_VERSION, class = "version-badge")),
  theme = bslib::bs_theme(version = 5, base_font = "system-ui"),
  sidebar = bslib::sidebar(configuration_ui("configuration", trusted_local), width = 320),
  shiny::tags$head(shiny::tags$link(rel = "stylesheet", href = "style.css")),
  shiny::tags$a(href = "#main-content", class = "skip-link", "Skip to main content"),
  shiny::tags$main(id = "main-content", tabindex = "-1",
    coordinator_status_ui("analysis_status"),
    bslib::navset_card_tab(id = "main_nav_tabs",
      bslib::nav_panel("Overview", value = "overview", overview_ui("overview")),
      bslib::nav_panel("Diagnostics", value = "diagnostics", diagnostics_ui("diagnostics")),
      bslib::nav_panel("Model Brain", value = "brain", shiny::div(id = "brain-panel",
        shiny::h2("Model Brain"), shiny::p("Observation explanations will be available in the next workflow update."))),
      bslib::nav_panel("Data & provenance", value = "data_provenance", data_provenance_ui("data_provenance")))))

server <- function(input, output, session) {
  coordinator <- create_app_coordinator(services, trusted_local, app_root)
  config <- configuration_server("configuration", trusted_local, app_root)
  shiny::observeEvent(config$generate(), {
    coordinator$analyze(config$payload())
  }, ignoreInit = TRUE, ignoreNULL = TRUE)
  coordinator_status_server("analysis_status", coordinator)
  overview <- overview_server("overview", coordinator$result, coordinator$generation)
  diagnostics_server("diagnostics", coordinator$result)
  data_provenance_server("data_provenance", coordinator$result, coordinator$successful_request)
  # Task 7 consumes coordinator$result, coordinator$generation and overview$selection in the reserved Brain panel.
}

shiny::shinyApp(ui, server)
