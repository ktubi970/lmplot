diagnostics_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(shiny::h2("Diagnostics"), shiny::uiOutput(ns('guidance')),
    shiny::tags$section(class = "chart-section", `aria-labelledby` = ns("plot_heading"),
      shiny::div(class = "chart-heading", shiny::h3(id = ns("plot_heading"), "Residuals vs fitted responses")),
      shiny::div(class = "analysis-chart", role = 'region', `aria-label` = 'Response residuals versus fitted values',
        `aria-describedby` = ns('chart_summary'), plotly::plotlyOutput(ns("plot"), height = "420px")),
      shiny::tags$details(class = "chart-details", shiny::tags$summary('Details & data'),
        shiny::textOutput(ns('chart_summary')), shiny::uiOutput(ns('chart_table')),
        shiny::downloadLink(ns('chart_download'), 'Download residuals (CSV)'))),
    shiny::tags$details(id = ns("checks_details"), class = "view-details", shiny::tags$summary("Diagnostic checks"),
      shiny::h3(shiny::textOutput(ns("heading"))), shiny::textOutput(ns("summary")), shiny::tableOutput(ns("checks")),
      shiny::p("Patterns invite investigation; they do not prove model adequacy.")))
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
    output$summary <- shiny::renderText({ shiny::req(result());
      paste(analysis_prediction_context(result()), result()$diagnostics$summary) })
    output$checks <- shiny::renderTable({ shiny::req(result()); diagnostics_check_table(result()$diagnostics) }, striped = TRUE)
    output$plot <- plotly::renderPlotly({ shiny::req(result()); render_diagnostics(result()) })
    output$guidance <- shiny::renderUI({
      shiny::req(result())
      known <- c('Exploratory residual curvature detected; inspect functional form and influential observations.',
        'Residual spread varies with fitted values; inspect variance assumptions.',
        'GLM fitting algorithm did not converge.',
        'Near-boundary probabilities; inspect sparse outcomes, separation and coefficient uncertainty.',
        'Singular fit: a random-effect variance is at or near its boundary (tolerance 1e-4).')
      guidance <- intersect(result()$diagnostics$warnings, known)
      if (length(guidance)) shiny::div(class = "diagnostic-guidance", role = "note",
        shiny::tags$ul(lapply(guidance, shiny::tags$li)))
    })
    output$chart_summary <- shiny::renderText({
      shiny::req(result()); paste('Response residuals versus fitted responses; N =', result()$model_brain$n,
        '; response unit:', result()$model_brain$units$z %||% 'unit not specified',
        '. The dashed line marks zero residual. Descriptive observed-minus-fitted values; no residual confidence interval is estimated.',
        analysis_prediction_context(result()),
        result()$diagnostics$summary)
    })
    shiny::outputOptions(output, "chart_summary", suspendWhenHidden = FALSE)
    data <- shiny::reactive({ shiny::req(result()); analysis_chart_observations(result()) })
    output$chart_table <- shiny::renderUI(accessible_data_table(data(), 'Response residuals versus fitted values'))
    output$chart_download <- shiny::downloadHandler(filename = function() 'lmplot-residuals.csv',
      content = function(file) write_chart_csv(data(), file))
    shiny::outputOptions(output, "chart_download", suspendWhenHidden = FALSE)
  })
}
