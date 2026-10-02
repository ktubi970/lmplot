if (isTRUE(getOption("lmplot.renv_unavailable"))) {
  stop("Restore dependencies explicitly before starting LM Plot Explorer.", call. = FALSE)
}

app_root <- if (file.exists(file.path("R", "config.R"))) "." else ".."
for (file in c("config.R", "model_registry.R", "mod_model.R", "model_metrics.R",
    "model_diagnostics.R", "mod_simulation.R", "mod_examples.R", "mod_visualization.R",
    "mod_model_brain.R", "model_brain_plots.R", "mod_model_brain_ui.R", "mod_pipeline.R", "mod_eli5.R", "app_coordinator.R",
    "mod_configuration.R", "mod_overview.R", "mod_diagnostics.R", "mod_data_provenance.R", "browser_compatibility.R")) {
  source(file.path(app_root, "R", file), local = TRUE)
}
options(shiny.sanitize.errors = TRUE)
trusted_local <- identical(Sys.getenv("LMPLOT_TRUSTED_LOCAL"), "1")
services <- create_analysis_services()

ui <- bslib::page_sidebar(
  title = shiny::tags$header(shiny::h1("LM Plot Explorer"), shiny::span(APP_VERSION, class = "version-badge")),
  theme = bslib::bs_theme(version = 5, base_font = "system-ui"),
  sidebar = bslib::sidebar(configuration_ui("configuration", trusted_local), width = 320),
  shiny::tags$head(shiny::tags$link(rel = "stylesheet", href = "style.css"), shiny::tags$script(shiny::HTML("
    document.documentElement.lang = 'en';
    document.addEventListener('DOMContentLoaded', function() {
      var skip = document.querySelector('.skip-link');
      document.body.insertBefore(skip, document.body.firstChild);
      skip.addEventListener('click', function() { document.getElementById('main-content').focus(); });
      Shiny.addCustomMessageHandler('brain-controls', function(x) { document.getElementById(x.id).disabled = x.disabled; });
      Shiny.addCustomMessageHandler('brain-index-error', function(x) {
        var input = document.getElementById(x.id);
        input.setAttribute('aria-describedby', x.error_id); input.setAttribute('aria-invalid', String(x.invalid));
      });
    });"))),
  shiny::tags$a(href = "#main-content", class = "skip-link", "Skip to main content"),
  shiny::tags$div(id = "analysis-content",
    coordinator_status_ui("analysis_status"),
    shiny::tags$nav(`aria-label` = "Analysis views", bslib::navset_card_tab(id = "main_nav_tabs",
      bslib::nav_panel("Overview", value = "overview", overview_ui("overview")),
      bslib::nav_panel("Diagnostics", value = "diagnostics", diagnostics_ui("diagnostics")),
      bslib::nav_panel("Model Brain", value = "brain", model_brain_ui("brain")),
      bslib::nav_panel("Data & provenance", value = "data_provenance", data_provenance_ui("data_provenance"))))))

ui <- htmltools::tagQuery(ui)$find('main')$addAttrs(id = 'main-content', tabindex = '-1')$allTags()
ui <- htmltools::tagQuery(ui)$find('aside')$addAttrs(`aria-label` = 'Configuration')$allTags()
ui <- adapt_browser_downloads(ui)

server <- function(input, output, session) {
  coordinator <- create_app_coordinator(services, trusted_local, app_root)
  config <- configuration_server("configuration", trusted_local, app_root)
  automatic <- bind_automatic_analysis(config, coordinator)
  coordinator_status_server("analysis_status", coordinator, automatic$pending)
  overview <- overview_server("overview", coordinator$result, coordinator$generation)
  diagnostics_server("diagnostics", coordinator$result)
  data_provenance_server("data_provenance", coordinator$result, coordinator$successful_request)
  brain <- model_brain_server("brain", coordinator$result, coordinator$generation, overview$selection, overview$select_observation)
}

shiny::shinyApp(ui, server)
