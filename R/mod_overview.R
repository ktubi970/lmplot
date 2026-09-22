overview_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(shiny::h2("Overview"), shiny::uiOutput(ns("metrics")),
    shiny::uiOutput(ns("surface_ui")), shiny::div(class = "analysis-chart", plotly::plotlyOutput(ns("main_plot"))),
    shiny::textOutput(ns("chart_summary")), shiny::h3("Coefficient estimates"),
    shiny::tableOutput(ns("coefficients")), shiny::textOutput(ns("variable_mapping")),
    guided_interpretation_ui(ns("guided_interpretation")))
}

overview_server <- function(id, result, generation = shiny::reactive(0L),
    render_main = render_analysis_main_plot, interpret = guided_interpretation) {
  stopifnot(is.function(result), is.function(generation), is.function(render_main), is.function(interpret))
  shiny::moduleServer(id, function(input, output, session) {
    selection <- shiny::reactiveVal(NULL)
    previous_generation <- NULL
    shiny::observeEvent(generation(), {
      if (!identical(previous_generation, generation())) selection(NULL)
      previous_generation <<- generation()
    }, ignoreNULL = FALSE)
    # Task 7 can supply this same payload from point/keyboard navigation.
    shiny::observeEvent(input$observation_selection, {
      event <- input$observation_selection
      current <- result(); shiny::req(current)
      ids <- vapply(analysis_observations(current), `[[`, character(1), "observation_id")
      if (is.list(event) && is.numeric(event$generation) && length(event$generation) == 1L &&
          is.finite(event$generation) && event$generation == generation() &&
          is.character(event$observation_id) && length(event$observation_id) == 1L && event$observation_id %in% ids) {
        selection(list(observation_id = event$observation_id, generation = generation()))
      }
    })
    output$metrics <- shiny::renderUI({
      value <- result()
      if (is.null(value)) return(shiny::p("No analysis yet. Choose settings and select Generate & fit model."))
      labels <- c(sample_size = "Sample size (N)", r_squared = "R-squared", adjusted_r_squared = "Adjusted R-squared",
        deviance_explained = "Deviance explained", pearson_dispersion = "Pearson dispersion",
        population_prediction_correlation_squared = "Fixed-effects correlation-squared",
        conditional_prediction_correlation_squared = "Conditional correlation-squared", aic = "AIC", bic = "BIC")
      keys <- intersect(names(labels), names(value$metrics))
      shiny::tagList(shiny::h3("Metrics"), shiny::tags$dl(lapply(keys, function(key) shiny::tagList(
        shiny::tags$dt(labels[[key]]), shiny::tags$dd(format(value$metrics[[key]], digits = 7))))),
        shiny::p(COMPARISON_CRITERIA_DESCRIPTION))
    })
    output$surface_ui <- shiny::renderUI({
      value <- result(); if (is.null(value) || model_config(value$model_type)$dimensions == 2L) return(NULL)
      shiny::checkboxInput(session$ns("show_surface"), "Show fitted surface", TRUE)
    })
    output$main_plot <- plotly::renderPlotly({
      shiny::req(result())
      render_main(result(), input$show_surface %||% TRUE,
        source = session$ns("observations"), generation = generation())
    })
    output$chart_summary <- shiny::renderText({
      value <- result(); shiny::req(value)
      paste(model_config(value$model_type)$label, "with", nrow(value$data), "observations.",
        "Points show observed responses; the fit shows the model mean response.",
        if (value$model_type == "glmm") "The surface is a population prediction without random intercepts." else "",
        "Inspect the enriched observation table in Data & provenance.")
    })
    output$coefficients <- shiny::renderTable({ shiny::req(result()); result()$coefficients },
      digits = 6, na = "Unavailable", striped = TRUE)
    output$variable_mapping <- shiny::renderText({
      shiny::req(result()); paste(names(result()$labels), unlist(result()$labels), sep = ": ", collapse = "; ")
    })
    guided_interpretation_server("guided_interpretation", result, interpret)
    list(selection = shiny::reactive(selection()))
  })
}
