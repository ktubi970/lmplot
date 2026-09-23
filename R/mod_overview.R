overview_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(shiny::h2("Overview"), shiny::uiOutput(ns("metrics")),
    shiny::uiOutput(ns("surface_ui")), shiny::div(class = "analysis-chart", role = "region", `aria-label` = "Observed responses and model fit",
      `aria-describedby` = ns("chart_summary"), plotly::plotlyOutput(ns("main_plot"))),
    shiny::textOutput(ns("chart_summary")),
    shiny::tags$details(shiny::tags$summary("View observed response data"), shiny::uiOutput(ns("observations_table"))),
    shiny::downloadLink(ns("observations_download"), "Download observed response data (CSV)"),
    shiny::tags$details(shiny::tags$summary("View prediction grid data"), shiny::uiOutput(ns("grid_table"))),
    shiny::downloadLink(ns("grid_download"), "Download prediction grid data (CSV)"), shiny::h3("Coefficient estimates"),
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
      if (!identical(previous_generation, generation())) {
        current <- result()
        selection(if (is.null(current)) NULL else list(observation_id = current$model_brain$default_observation_id, generation = generation()))
      }
      previous_generation <<- generation()
    }, ignoreNULL = FALSE)
    select_observation <- function(event) {
      current <- result(); if (is.null(current)) return(invisible(FALSE))
      ids <- vapply(analysis_observations(current), `[[`, character(1), "observation_id")
      if (is.list(event) && is.numeric(event$generation) && length(event$generation) == 1L &&
          is.finite(event$generation) && event$generation == generation() &&
          is.character(event$observation_id) && length(event$observation_id) == 1L && event$observation_id %in% ids) {
        selection(list(observation_id = event$observation_id, generation = generation()))
        return(invisible(TRUE))
      }
      invisible(FALSE)
    }
    shiny::observeEvent(input$observation_selection, select_observation(input$observation_selection))
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
      plot <- render_main(result(), input$show_surface %||% TRUE,
        source = session$ns("observations"), generation = generation())
      htmlwidgets::onRender(plot, "function(el, x, data) {
        if (el._brainClick) el.removeListener('plotly_click', el._brainClick);
        el._brainClick = function(event) {
          var point = event && event.points && event.points[0];
          if (!point || !point.data || point.data.name !== 'Observed' || !point.customdata) return;
          try { var key = JSON.parse(point.customdata);
            Shiny.setInputValue(data.input, key, {priority: 'event'}); } catch(e) {}
        };
        el.on('plotly_click', el._brainClick);
      }", data = list(input = session$ns('observation_selection')))
    })
    output$chart_summary <- shiny::renderText({
      value <- result(); shiny::req(value)
      paste(model_config(value$model_type)$label, "with", nrow(value$data), "observations.",
        paste('Points show', value$model_brain$labels$z, '; the fit shows', analysis_predicted_label(value), '.'),
        if (value$model_type == "glmm") "The surface is a population prediction without random intercepts." else "",
        paste('N =', value$model_brain$n, '; response unit:', value$model_brain$units$z %||% 'unit not specified'),
        if (value$model_type == 'glmm') 'Response-scale intervals are unavailable for this GLMM.' else
          'Available 95% mean-response confidence intervals are included in the observed data table; the grid is a point prediction.',
        if (isTRUE(input$show_surface %||% TRUE)) 'Fitted surface shown when applicable.' else 'Fitted surface hidden.',
        "Select an observed point to explore it in Model Brain; keyboard selection is available there.")
    })
    observation_data <- shiny::reactive({ shiny::req(result()); analysis_chart_observations(result()) })
    output$observations_table <- shiny::renderUI(accessible_data_table(observation_data(), 'Observed responses and fitted values'))
    output$observations_download <- shiny::downloadHandler(filename = function() 'lmplot-observations.csv',
      content = function(file) write_chart_csv(observation_data(), file))
    output$grid_table <- shiny::renderUI({ shiny::req(result()); accessible_data_table(analysis_chart_grid(result()), 'Mean-response prediction grid') })
    output$grid_download <- shiny::downloadHandler(filename = function() 'lmplot-prediction-grid.csv',
      content = function(file) { shiny::req(result()); write_chart_csv(analysis_chart_grid(result()), file) })
    output$coefficients <- shiny::renderTable({ shiny::req(result());
      table <- result()$coefficients
      table$units <- brain_term_units(table$term, result()$model_brain$units)
      table },
      digits = 6, na = "Unavailable", striped = TRUE)
    output$variable_mapping <- shiny::renderText({
      shiny::req(result()); paste(names(result()$labels), unlist(result()$labels), sep = ": ", collapse = "; ")
    })
    guided_interpretation_server("guided_interpretation", result, interpret)
    list(selection = shiny::reactive(selection()), select_observation = select_observation)
  })
}
