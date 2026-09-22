diagnostics_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(shiny::h2("Diagnostics"), shiny::h3(shiny::textOutput(ns("heading"))),
    shiny::textOutput(ns("summary")), shiny::tableOutput(ns("checks")),
    shiny::div(class = "analysis-chart", plotly::plotlyOutput(ns("plot"))),
    shiny::p("Response residuals are observed minus fitted responses. Patterns invite investigation; they do not prove model adequacy."),
    shiny::p("The enriched CSV in Data & provenance contains the plotted fitted values and response residuals."))
}

diagnostics_check_table <- function(diagnostics) {
  do.call(rbind, lapply(names(diagnostics$checks), function(name) {
    check <- diagnostics$checks[[name]]
    # Raw optimizer messages remain in the internal result and never enter public HTML.
    value <- if (name == "optimizer_messages") {
      if (isTRUE(check$available)) "Optimizer messages were recorded; convergence needs inspection." else "Unavailable"
    } else if (isTRUE(check$available)) paste(format(check$value, digits = 7), collapse = ", ") else "Unavailable"
    data.frame(Check = gsub("_", " ", name), Value = value, Explanation = check$explanation, check.names = FALSE)
  }))
}

diagnostics_server <- function(id, result, render_diagnostics = render_analysis_diagnostics) {
  stopifnot(is.function(result), is.function(render_diagnostics))
  shiny::moduleServer(id, function(input, output, session) {
    output$heading <- shiny::renderText({
      if (is.null(result())) return("No analysis yet")
      paste(model_config(result()$model_type)$label, "— Diagnostic evidence")
    })
    output$summary <- shiny::renderText({ shiny::req(result()); result()$diagnostics$summary })
    output$checks <- shiny::renderTable({ shiny::req(result()); diagnostics_check_table(result()$diagnostics) }, striped = TRUE)
    output$plot <- plotly::renderPlotly({ shiny::req(result()); render_diagnostics(result()) })
  })
}
