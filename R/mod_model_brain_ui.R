# Accessible chart sections share one authoritative table with their download.
write_chart_csv <- function(data, file) {
  # Seventeen significant digits round-trip IEEE doubles; keep the bundle numeric.
  exported <- lapply(data, function(column) {
    if (!is.double(column)) return(column)
    vapply(column, function(value) if (is.na(value)) NA_character_ else sprintf('%.17g', value), character(1))
  })
  utils::write.csv(as.data.frame(exported, check.names = FALSE), file, row.names = FALSE, na = '')
}

chart_section_ui <- function(ns, key, title, plot = TRUE) {
  shiny::tags$section(class = 'chart-section', `aria-labelledby` = ns(paste0(key, '_heading')),
    shiny::h3(id = ns(paste0(key, '_heading')), title),
    shiny::textOutput(ns(paste0(key, '_summary'))),
    if (plot) shiny::div(role = 'region', `aria-label` = title,
      `aria-describedby` = ns(paste0(key, '_summary')), plotly::plotlyOutput(ns(paste0(key, '_plot')))),
    shiny::tags$details(shiny::tags$summary(paste('View', tolower(title), 'data')),
      shiny::uiOutput(ns(paste0(key, '_table')))),
    shiny::downloadLink(ns(paste0(key, '_download')), paste('Download', tolower(title), 'data (CSV)')))
}

accessible_data_table <- function(data, caption) {
  total <- nrow(data)
  if (total > 100L) {
    caption <- paste(caption, sprintf('— Showing 100 of %d rows. Download the CSV for all rows.', total))
    data <- head(data, 100L)
  }
  shiny::div(class = 'scientific-table-scroll', tabindex = '0', role = 'region', `aria-label` = caption,
    shiny::tags$table(class = 'table table-striped scientific-table', shiny::tags$caption(caption),
      shiny::tags$thead(shiny::tags$tr(lapply(names(data), function(name) shiny::tags$th(scope = 'col', name)))),
      shiny::tags$tbody(lapply(seq_len(nrow(data)), function(i) shiny::tags$tr(lapply(data, function(column) {
        value <- column[i]
        shiny::tags$td(class = if (is.numeric(column)) 'numeric' else NULL,
          if (is.na(value)) 'Unavailable' else if (is.numeric(column)) format(value, digits = 15, trim = TRUE) else as.character(value))
      }))))))
}

bind_chart_bundle <- function(output, key, bundle, title) {
  output[[paste0(key, '_summary')]] <- shiny::renderText({ shiny::req(bundle()); bundle()$summary })
  output[[paste0(key, '_plot')]] <- plotly::renderPlotly({ shiny::req(bundle()$plot); bundle()$plot })
  output[[paste0(key, '_table')]] <- shiny::renderUI({ shiny::req(bundle()); accessible_data_table(bundle()$table, title) })
  output[[paste0(key, '_download')]] <- shiny::downloadHandler(
    filename = function() paste0('lmplot-', key, '.csv'), content = function(file) {
      shiny::req(bundle()); write_chart_csv(bundle()$table, file)
    })
}

model_brain_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(shiny::h2('Model Brain'),
    shiny::div(id = ns('observation_summary'), `aria-live` = 'polite', `aria-atomic` = 'true', role = 'status',
      class = 'shiny-text-output'),
    shiny::tags$fieldset(id = ns('controls'), disabled = 'disabled',
      shiny::tags$legend('Explore an observation'),
      shiny::div(class = 'brain-navigation', shiny::actionButton(ns('previous'), 'Previous'),
        shiny::actionButton(ns('next'), 'Next')),
      shiny::p('Previous at the first observation wraps to the last; Next at the last wraps to the first.'),
      htmltools::tagAppendAttributes(shiny::numericInput(ns('observation_index'), 'Observation number', 1, min = 1, step = 1),
        `data-index-control` = ns('observation_index')),
      shiny::div(id = ns('index_error'), role = 'alert', class = 'shiny-text-output'),
      shiny::conditionalPanel(sprintf("output['%s']", ns('is_mixed')),
        shiny::selectInput(ns('prediction_mode'), 'Prediction mode', c('Conditional' = 'conditional', 'Population' = 'population')))),
    shiny::conditionalPanel(sprintf("output['%s']", ns('has_result')),
      chart_section_ui(ns, 'equation', 'Exact equation', FALSE),
      chart_section_ui(ns, 'contribution', 'Contribution waterfall'),
      chart_section_ui(ns, 'link', 'Link transformation'),
      chart_section_ui(ns, 'coefficient', 'Coefficient overview'),
      shiny::conditionalPanel(sprintf("output['%s']", ns('is_mixed')),
        chart_section_ui(ns, 'random', 'Random effects'))))
}

model_brain_server <- function(id, result, generation, selection, select_observation) {
  stopifnot(is.function(result), is.function(generation), is.function(selection), is.function(select_observation))
  shiny::moduleServer(id, function(input, output, session) {
    mode <- shiny::reactiveVal('conditional'); index_error <- shiny::reactiveVal('')
    selected_index <- shiny::reactive({
      if (is.null(result()) || is.null(selection())) return(NULL)
      match(selection()$observation_id, vapply(analysis_observations(result()), `[[`, character(1), 'observation_id'))
    })
    selected_observation <- shiny::reactive({
      if (is.null(selected_index())) return(NULL)
      select_model_brain_observation(result()$model_brain, selected_index(), mode())
    })
    shiny::observeEvent(generation(), {
      mode('conditional'); index_error('')
      shiny::updateSelectInput(session, 'prediction_mode', selected = 'conditional')
    })
    shiny::observe({
      available <- !is.null(result())
      session$sendCustomMessage('brain-controls', list(id = session$ns('controls'), disabled = !available))
      if (available && !is.null(selected_index())) shiny::updateNumericInput(session, 'observation_index',
        value = selected_index(), max = result()$model_brain$n)
    })
    choose <- function(index) {
      shiny::req(result())
      if (!is.numeric(index) || length(index) != 1L || !is.finite(index) || index != floor(index) ||
          index < 1 || index > result()$model_brain$n) {
        index_error(paste('Enter a whole number from 1 to', result()$model_brain$n)); return(invisible(FALSE))
      }
      index_error('')
      record <- select_model_brain_observation(result()$model_brain, index)
      select_observation(list(observation_id = record$observation_id, generation = generation()))
    }
    shiny::observeEvent(input$observation_index, choose(input$observation_index), ignoreInit = TRUE)
    shiny::observeEvent(input$previous, { shiny::req(selected_index()); choose((selected_index() - 2L) %% result()$model_brain$n + 1L) })
    shiny::observeEvent(input[['next']], { shiny::req(selected_index()); choose(selected_index() %% result()$model_brain$n + 1L) })
    shiny::observeEvent(input$prediction_mode, {
      if (!is.null(result()) && input$prediction_mode %in% result()$model_brain$prediction_modes) mode(input$prediction_mode)
    })
    output$has_result <- shiny::reactive(!is.null(result()))
    output$is_mixed <- shiny::reactive(!is.null(result()) && result()$model_type == 'glmm')
    shiny::outputOptions(output, 'has_result', suspendWhenHidden = FALSE)
    shiny::outputOptions(output, 'is_mixed', suspendWhenHidden = FALSE)
    output$index_error <- shiny::renderText(index_error())
    shiny::observe({ session$sendCustomMessage('brain-index-error', list(id = session$ns('observation_index'),
      error_id = session$ns('index_error'), invalid = nzchar(index_error()))) })
    output$observation_summary <- shiny::renderText({
      o <- selected_observation()
      if (is.null(o)) return('No analysis yet. Choose settings and select Generate & fit model.')
      sprintf('Observation %d of %d, ID %s; %s. Predicted mean %s; observed %s; residual %s. Response unit: %s. %s',
        o$index, result()$model_brain$n, o$observation_id, o$prediction_mode,
        format(o$prediction, digits = 6), format(o$observed, digits = 6), format(o$residual, digits = 6),
        result()$model_brain$units$z %||% 'unit not specified',
        brain_interval_text(o$response_interval))
    })
    view <- shiny::reactive({ shiny::req(selected_index()); brain_view_data(result()$model_brain, selected_index(), mode()) })
    renderers <- list(equation = exact_equation_view, contribution = contribution_waterfall,
      link = link_transformation_plot, coefficient = coefficient_overview_plot, random = random_effect_plot)
    for (key in names(renderers)) local({
      name <- key; render <- renderers[[name]]
      bundle <- shiny::reactive(render(view()))
      bind_chart_bundle(output, name, bundle, paste('Model Brain', name, 'data'))
    })
    list(selected_index = selected_index, selected_mode = shiny::reactive(mode()), selected_observation = selected_observation)
  })
}
