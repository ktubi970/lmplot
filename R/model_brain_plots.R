# Pure presentation of the validated, precomputed model-brain/1.0 contract.
brain_view_data <- function(brain, index, prediction_mode = 'conditional') {
  list(observation = select_model_brain_observation(brain, index, prediction_mode),
    brain = brain, n = brain$n, units = brain$units)
}

brain_interval_text <- function(interval) {
  if (!isTRUE(interval$available)) return(interval$reason %||% 'Interval unavailable.')
  sprintf('%g%% mean-response confidence interval [%s, %s] (%s).', 100 * interval$level,
    format(interval$lower, digits = 6), format(interval$upper, digits = 6), interval$method)
}

chart_accessibility_bundle <- function(plot, summary, table, units, n, uncertainty) {
  unit_text <- paste('X units:', units$x %||% 'unit not specified',
    if (!is.null(units$y)) paste('; Y units:', units$y) else '',
    '; eta units:', units$eta, '; response units:', units$z %||% 'unit not specified')
  list(plot = plot, summary = sprintf('%s; N = %d; %s; %s', summary, n, unit_text, uncertainty),
    table = table, units = units, n = n, uncertainty = uncertainty)
}

brain_table_context <- function(table, view) {
  o <- view$observation; i <- o$response_interval
  table$observation_id <- o$observation_id; table$source_index <- o$index
  table$prediction_mode <- o$prediction_mode
  table$x_unit <- view$units$x %||% 'unit not specified'
  table$y_unit <- view$units$y %||% 'unit not specified'
  table$response_unit <- view$units$z %||% 'unit not specified'
  table$observed_response_label <- view$brain$labels$z
  table$response_interval_available <- i$available
  table$response_interval_lower <- i$lower %||% NA_real_
  table$response_interval_upper <- i$upper %||% NA_real_
  table$response_interval_level <- i$level
  table$response_interval_method <- i$method %||% NA_character_
  table$response_interval_reason <- i$reason %||% NA_character_
  table
}

brain_term_units <- function(terms, units) {
  vapply(terms, function(term) {
    if (term == '(Intercept)') return(units$eta)
    paste(units$eta, 'per', units[[tolower(term)]] %||% 'predictor unit (unit not specified)')
  }, character(1), USE.NAMES = FALSE)
}

brain_contribution_table <- function(view) {
  o <- view$observation
  table <- do.call(rbind, lapply(o$contributions, function(x) data.frame(
    role = if (x$order == 1L) 'intercept' else 'fixed term', term = x$term,
    input = x$input, coefficient = x$coefficient, value = x$value, order = x$order)))
  if (o$random_effect$available) table <- rbind(table, data.frame(role = 'random intercept',
    term = paste('Group', o$random_effect$group), input = o$random_effect$value,
    coefficient = 1, value = o$random_effect$value, order = nrow(table) + 1L))
  table$scale <- view$units$eta
  table$input_unit <- vapply(table$term, function(term) {
    if (term == '(Intercept)') return('dimensionless')
    if (startsWith(term, 'Group ')) return(view$units$eta)
    view$units[[tolower(term)]] %||% 'unit not specified'
  }, character(1))
  table$coefficient_unit <- brain_term_units(table$term, view$units)
  table$coefficient_unit[table$role == 'random intercept'] <- 'dimensionless'
  table
}

brain_plot_style <- function(plot, x, y) {
  plotly::config(plotly::layout(plot, xaxis = list(title = x), yaxis = list(title = y),
    font = list(family = 'system-ui, sans-serif', color = '#1e293b'),
    paper_bgcolor = '#ffffff', plot_bgcolor = '#ffffff', showlegend = FALSE),
    displayModeBar = FALSE, staticPlot = TRUE)
}

exact_equation_view <- function(view) {
  o <- view$observation; table <- brain_contribution_table(view)
  terms <- sprintf('(%s × %s)', format(table$coefficient, digits = 6), format(table$input, digits = 6))
  equation <- paste(paste(terms, collapse = ' + '), '=', format(o$eta, digits = 6),
    paste0('(', view$units$eta, '); inverse ', view$brain$link, ' link ='), format(o$prediction, digits = 6))
  for (key in c('eta', 'prediction', 'observed', 'residual')) table <- rbind(table,
    data.frame(role = key, term = key, input = NA_real_, coefficient = NA_real_, value = o[[key]],
      order = nrow(table) + 1L, scale = if (key == 'eta') view$units$eta else view$units$z %||% 'response: unit not specified',
      input_unit = NA_character_, coefficient_unit = NA_character_))
  chart_accessibility_bundle(NULL, paste(equation,
    'Observed:', format(o$observed, digits = 6), '; residual:', format(o$residual, digits = 6),
    '. Displayed numbers are rounded; CSV preserves stored precision. Response unit:', view$units$z %||% 'unit not specified'),
    brain_table_context(table, view), view$units, view$n, brain_interval_text(o$response_interval))
}

contribution_waterfall <- function(view) {
  table <- brain_contribution_table(view); o <- view$observation
  table$start <- c(0, head(cumsum(table$value), -1)); table$end <- cumsum(table$value)
  table$status <- ifelse(table$value > 0, 'positive', ifelse(table$value < 0, 'negative', 'zero'))
  table <- rbind(table, data.frame(role = 'eta', term = 'Total eta', input = NA_real_, coefficient = NA_real_,
    value = o$eta, order = nrow(table) + 1L, scale = view$units$eta,
    input_unit = NA_character_, coefficient_unit = NA_character_, start = 0, end = o$eta, status = 'total'))
  colors <- c(positive = '#0f766e', negative = '#92400e', zero = '#475569', total = '#1d4ed8')
  plot <- plotly::plot_ly(x = table$term, y = table$value, base = table$start,
    type = 'bar', marker = list(color = unname(colors[table$status]), line = list(color = '#1e293b', width = 1)),
    text = paste(table$status, sprintf('%+.6g', table$value)), textposition = 'outside', cliponaxis = FALSE,
    hovertext = paste(table$term, sprintf('%+.6g', table$value), table$scale), hoverinfo = 'text')
  chart_accessibility_bundle(brain_plot_style(plot, 'Ordered contribution', view$units$eta),
    paste('Signed contributions finish at stored eta =', format(o$eta, digits = 6), '; scale:', view$units$eta),
    brain_table_context(table, view), view$units, view$n, 'Decomposition of fitted values; contribution uncertainty is not estimated.')
}

link_transformation_plot <- function(view) {
  curve <- view$brain$link_curve; o <- view$observation
  table <- data.frame(kind = 'curve', eta = curve$eta, prediction = curve$prediction, valid = curve$valid)
  table <- rbind(table, data.frame(kind = 'selected observation', eta = o$eta, prediction = o$prediction, valid = TRUE))
  table$eta_unit <- view$units$eta
  table$response_unit <- view$units$z %||% 'unit not specified'
  plot <- plotly::plot_ly(x = curve$eta, y = ifelse(curve$valid, curve$prediction, NA_real_),
    type = 'scatter', mode = 'lines', connectgaps = FALSE, line = list(color = '#1d4ed8', width = 3),
    hovertemplate = paste0('Eta (', view$units$eta, '): %{x}<br>Predicted mean (',
      view$units$z %||% 'unit not specified', '): %{y}<extra></extra>'))
  plot <- plotly::add_trace(plot, x = o$eta, y = o$prediction, type = 'scatter', mode = 'markers',
    marker = list(symbol = 'diamond', size = 12, color = '#92400e'), inherit = FALSE,
    hovertemplate = paste0('Selected eta (', view$units$eta, '): %{x}<br>Predicted mean (',
      view$units$z %||% 'unit not specified', '): %{y}<extra></extra>'))
  plot <- plotly::layout(plot, shapes = list(list(type = 'line', x0 = o$eta, x1 = o$eta,
    y0 = 0, y1 = o$prediction, line = list(dash = 'dash', color = '#475569'))))
  chart_accessibility_bundle(brain_plot_style(plot, paste('Eta:', view$units$eta),
    paste('Prediction:', view$units$z %||% 'response unit not specified')),
    paste('Inverse', view$brain$link, 'link; diamond marks the selected observation. Deterministic transformation, not a confidence band.'),
    brain_table_context(table, view), view$units, view$n, brain_interval_text(o$response_interval))
}

coefficient_overview_plot <- function(view) {
  table <- do.call(rbind, lapply(view$brain$coefficients, function(x) data.frame(term = x$term,
    estimate = x$estimate, standard_error = x$standard_error, available = x$interval$available,
    lower = x$interval$lower %||% NA_real_, upper = x$interval$upper %||% NA_real_, level = x$interval$level,
    method = x$interval$method %||% NA_character_, reason = x$interval$reason %||% NA_character_)))
  table$units <- brain_term_units(table$term, view$units)
  plot <- plotly::plot_ly(x = table$estimate, y = table$term, type = 'scatter', mode = 'markers',
    marker = list(color = '#1d4ed8', size = 10),
    text = paste(table$term, format(table$estimate, digits = 6), table$units), hoverinfo = 'text',
    error_x = list(type = 'data', symmetric = FALSE, array = table$upper - table$estimate,
      arrayminus = table$estimate - table$lower, color = '#475569'))
  plot <- plotly::layout(plot, shapes = list(list(type = 'line', x0 = 0, x1 = 0, yref = 'paper',
    y0 = 0, y1 = 1, line = list(dash = 'dash', color = '#475569'))))
  chart_accessibility_bundle(brain_plot_style(plot, 'Coefficient estimate (units vary by term)', 'Term'),
    paste('Coefficients in model order; raw magnitudes are not a ranking of importance.',
      paste(table$term, table$units, sep = ': ', collapse = '; ')),
    brain_table_context(table, view), view$units, view$n, '95% coefficient confidence intervals where available; missing bounds remain unavailable.')
}

random_effect_plot <- function(view) {
  o <- view$observation
  if (!o$random_effect$available) return(chart_accessibility_bundle(NULL, 'Random effects are not applicable.',
    data.frame(), view$units, view$n, 'Not applicable.'))
  records <- view$brain$observations[seq_len(view$n)]
  groups <- vapply(records, function(x) x$random_effect$group, character(1))
  ids <- sort(unique(groups), method = 'radix')
  table <- data.frame(group = ids, value = vapply(ids, function(id) records[[match(id, groups)]]$random_effect$value, numeric(1)),
    count = as.integer(table(factor(groups, levels = ids))), selected = ids == o$random_effect$group,
    active = o$prediction_mode == 'conditional', units = view$units$eta)
  plot <- plotly::plot_ly(x = table$value, y = table$group, type = 'scatter', mode = 'markers',
    text = paste('Group', table$group, format(table$value, digits = 6), table$units), hoverinfo = 'text',
    marker = list(color = '#0f766e', size = 10, symbol = ifelse(table$selected, 'diamond', 'circle')))
  plot <- plotly::layout(plot, shapes = list(list(type = 'line', x0 = 0, x1 = 0, yref = 'paper',
    y0 = 0, y1 = 1, line = list(dash = 'dash', color = '#475569'))))
  chart_accessibility_bundle(brain_plot_style(plot, paste('Random intercept:', view$units$eta), 'Group'),
    paste(length(ids), 'groups. Selected group', o$random_effect$group, 'uses a diamond;',
      if (o$random_effect$active) 'conditional effects active.' else 'population mode: effects inactive; selected contribution is zero.'),
    brain_table_context(table, view), view$units, view$n, 'Random-effect intervals unavailable. Response-scale intervals are unavailable for this GLMM.')
}
