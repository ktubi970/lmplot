# Shiny facades below consume the committed scientific snapshot only.
label_with_unit <- function(label, unit) {
  if (is.null(unit) || grepl(paste0('(', unit, ')'), label, fixed = TRUE)) return(label)
  paste0(label, ' (', unit, ')')
}

analysis_predicted_label <- function(result) {
  prefix <- if (result$model_type == 'glmm') 'Predicted population mean:' else 'Predicted mean:'
  paste(prefix, label_with_unit(result$labels$z, result$model_brain$units$z))
}

analysis_chart_units <- function(table, result) {
  table$x_unit <- result$model_brain$units$x %||% 'unit not specified'
  if ('Y' %in% names(table)) table$y_unit <- result$model_brain$units$y %||% 'unit not specified'
  table$response_unit <- result$model_brain$units$z %||% 'unit not specified'
  table
}

analysis_chart_observations <- function(result) {
  records <- analysis_observations(result)
  table <- result$data
  table$observation_id <- vapply(records, `[[`, character(1), 'observation_id')
  table$source_index <- vapply(records, `[[`, integer(1), 'index')
  table$prediction_mode <- 'conditional'
  table$fitted <- vapply(records, `[[`, numeric(1), 'prediction')
  table$response_residual <- vapply(records, `[[`, numeric(1), 'residual')
  table$response_unit <- result$model_brain$units$z %||% 'unit not specified'
  table$observed_response_label <- result$model_brain$labels$z
  table$fitted_response_label <- paste('Fitted mean:', result$labels$z)
  table$interval_available <- vapply(records, function(x) x$response_interval$available, logical(1))
  table$interval_lower <- vapply(records, function(x) x$response_interval$lower %||% NA_real_, numeric(1))
  table$interval_upper <- vapply(records, function(x) x$response_interval$upper %||% NA_real_, numeric(1))
  table$interval_level <- vapply(records, function(x) x$response_interval$level, numeric(1))
  table$interval_method <- vapply(records, function(x) x$response_interval$method %||% NA_character_, character(1))
  table$interval_reason <- vapply(records, function(x) x$response_interval$reason %||% NA_character_, character(1))
  analysis_chart_units(table, result)
}

analysis_chart_grid <- function(result) {
  table <- result$prediction_grid
  table$prediction_mode <- if (result$model_type == 'glmm') 'population' else 'conditional'
  table$response_unit <- result$model_brain$units$z %||% 'unit not specified'
  table$predicted_response_label <- analysis_predicted_label(result)
  table$interval_available <- FALSE
  table$interval_reason <- 'This stored prediction grid provides point estimates only.'
  analysis_chart_units(table, result)
}

render_analysis_main_plot <- function(result, show_surface = TRUE, source = "overview", generation = 0L) {
  data <- result$data
  records <- analysis_observations(result)
  data$.fitted <- vapply(records, `[[`, numeric(1), "prediction")
  data$.residual <- vapply(records, `[[`, numeric(1), "residual")
  data$.selection <- vapply(records, function(row) as.character(jsonlite::toJSON(
    list(observation_id = row$observation_id, generation = generation), auto_unbox = TRUE)), character(1))
  config <- model_config(result$model_type)
  labels <- normalize_plot_labels(result$model_brain$labels)
  for (key in c('x', 'y', 'z')) labels[[key]] <- label_with_unit(labels[[key]], result$model_brain$units[[key]])
  labels$response_unit <- result$model_brain$units$z %||% 'unit not specified'
  predicted_label <- analysis_predicted_label(result)
  data$.hover <- observed_hover_text(data, labels, config$dimensions == 3L, config$requires_group)
  if (config$dimensions == 2L) {
    plot <- plotly::plot_ly(data, x = ~X, y = ~Z, type = "scatter", mode = "markers",
      source = source, customdata = ~.selection, text = ~.hover, hoverinfo = "text", name = "Observed",
      marker = list(color = '#1d4ed8', opacity = 1))
    grid <- result$prediction_grid
    plot <- plotly::add_lines(plot, x = grid$X, y = grid$.fitted, name = "Mean response",
      hovertemplate = paste0(labels$x, ': %{x:.3f}<br>', predicted_label, ': %{y:.3f}<extra>Mean response</extra>'),
      line = list(color = '#92400e', dash = 'dash'), inherit = FALSE)
    plot <- plotly::layout(plot, xaxis = list(title = labels$x), yaxis = list(title = labels$z))
  } else {
    plot <- plotly::plot_ly(data, x = ~X, y = ~Y, z = ~Z, type = "scatter3d", mode = "markers",
      source = source, customdata = ~.selection, text = ~.hover, hoverinfo = "text", name = "Observed",
      marker = list(size = 4, color = "#1d4ed8", line = list(color = '#ffffff', width = 2)))
    if (isTRUE(show_surface)) {
      grid <- result$prediction_grid
      x <- sort(unique(grid$X)); y <- sort(unique(grid$Y))
      z <- matrix(NA_real_, nrow = length(y), ncol = length(x))
      z[cbind(match(grid$Y, y), match(grid$X, x))] <- grid$.fitted
      plot <- plotly::add_surface(plot, x = x, y = y, z = z, inherit = FALSE,
        name = if (result$model_type == 'glmm') "Population mean response" else "Mean response",
        hovertemplate = paste0(labels$x, ': %{x:.3f}<br>', labels$y, ': %{y:.3f}<br>',
          predicted_label, ': %{z:.3f}<extra>Mean response</extra>'),
        opacity = 1, showscale = FALSE, colorscale = list(list(0, '#0f766e'), list(1, '#0f766e')),
        lighting = list(ambient = .8, diffuse = .2, specular = 0, roughness = 1))
    }
    plot <- plotly::layout(plot, scene = list(xaxis = list(title = labels$x),
      yaxis = list(title = labels$y), zaxis = list(title = labels$z)))
  }
  plot <- plotly::layout(plot,
    title = list(text = result$example$metadata$title %||% model_config(result$model_type)$label),
    font = list(family = "system-ui, sans-serif"))
  plotly::config(plotly::event_register(plot, "plotly_click"), displayModeBar = FALSE,
    scrollZoom = FALSE, doubleClick = FALSE, showTips = FALSE)
}

render_analysis_diagnostics <- function(result) {
  records <- analysis_observations(result)
  data <- data.frame(fitted = vapply(records, `[[`, numeric(1), "prediction"),
    residual = vapply(records, `[[`, numeric(1), "residual"))
  response_unit <- result$model_brain$units$z %||% 'unit not specified'
  fitted_label <- paste(if (result$model_type == 'glmm') 'Conditional fitted mean:' else 'Fitted mean:',
    label_with_unit(result$labels$z, result$model_brain$units$z))
  plot <- plotly::plot_ly(data, x = ~fitted, y = ~residual, type = "scatter", mode = "markers", name = "Response residual",
      hovertemplate = paste0(fitted_label, ': %{x}<br>Response residual (', response_unit, '): %{y}<extra></extra>'),
      marker = list(color = '#1d4ed8', opacity = 1)) |>
    plotly::layout(xaxis = list(title = fitted_label),
      yaxis = list(title = paste('Response residual (observed minus fitted):', result$model_brain$units$z %||% 'unit not specified')),
      shapes = list(list(type = "line", xref = "paper", x0 = 0, x1 = 1, y0 = 0, y1 = 0,
        line = list(dash = "dash"))), font = list(family = "system-ui, sans-serif"))
  plotly::config(plot, displayModeBar = FALSE, staticPlot = TRUE)
}

prediction_grid <- function(df, fit, model_type,
                            length_out = if (model_config(model_type)$dimensions == 2L) 200L else 30L,
                            pad = 0.15) {
  config <- model_config(model_type)
  rx <- range(df$X, na.rm = TRUE)
  dx <- diff(rx)
  if (dx == 0) dx <- 1
  x <- seq(rx[1L] - pad * dx, rx[2L] + pad * dx, length.out = length_out)

  if (config$dimensions == 2L) {
    grid <- data.frame(X = x)
  } else {
    ry <- range(df$Y, na.rm = TRUE)
    dy <- diff(ry)
    if (dy == 0) dy <- 1
    y <- seq(ry[1L] - pad * dy, ry[2L] + pad * dy, length.out = length_out)
    grid <- expand.grid(X = x, Y = y)
    if (config$requires_group) {
      fitted_group <- stats::model.frame(fit)[["Group"]]
      if (!is.factor(fitted_group)) fitted_group <- factor(fitted_group)
      group_levels <- levels(fitted_group)
      grid$Group <- factor(
        rep(group_levels[1L], nrow(grid)),
        levels = group_levels
      )
    }
  }

  grid$.fitted <- as.numeric(
    predict_response(fit, grid, population = config$requires_group)
  )
  grid
}

enrich_data <- function(df, fit) {
  df$.fitted <- fitted_response(fit)
  df$.residual <- response_residuals(fit)
  df
}

normalize_plot_labels <- function(labels = NULL) {
  resolved <- list(x = "X", y = "Y", z = "Z", group = "Group",
    predicted = 'Predicted mean response', response_unit = 'unit not specified')
  if (is.null(labels)) return(resolved)
  if (!is.list(labels)) {
    stop("Plot labels must be supplied as a named list", call. = FALSE)
  }
  supplied <- intersect(names(labels), names(resolved))
  for (name in supplied) {
    value <- labels[[name]]
    if (!is.character(value) || length(value) != 1L ||
        is.na(value) || !nzchar(value)) {
      stop("Plot label '", name, "' must be one non-empty string",
           call. = FALSE)
    }
    resolved[[name]] <- value
  }
  resolved
}

observed_hover_text <- function(data, labels, include_y, include_group) {
  text <- paste0(labels$x, ": ", sprintf("%.3f", data$X))
  if (include_y) {
    text <- paste0(text, "<br>", labels$y, ": ", sprintf("%.3f", data$Y))
  }
  text <- paste0(text, "<br>", labels$z, ": ", sprintf("%.3f", data$Z))
  if (include_group) {
    text <- paste0(text, "<br>", labels$group, ": ", data$Group)
  }
  paste0(text, '<br>Response residual (', labels$response_unit %||% 'unit not specified', '): ',
    sprintf("%.3f", data$.residual))
}

build_main_plot <- function(df, fit, model_type, show_surface = TRUE,
                            labels = NULL) {
  config <- model_config(model_type)
  labels <- normalize_plot_labels(labels)
  enriched <- enrich_data(df, fit)
  enriched$.observed_hover <- observed_hover_text(
    enriched,
    labels,
    include_y = config$dimensions == 3L,
    include_group = config$requires_group
  )

  if (config$dimensions == 2L) {
    curve <- enriched[order(enriched$X), ]
    curve$.fitted_hover <- paste0(
      labels$x, ": ", sprintf("%.3f", curve$X),
      "<br>", labels$predicted, ": ", sprintf("%.3f", curve$.fitted)
    )
    return(
      plotly::plot_ly(
        enriched,
        x = ~X,
        y = ~Z,
        type = "scatter",
        mode = "markers",
        text = ~.observed_hover,
        hoverinfo = "text",
        marker = list(color = "#2563eb", opacity = 0.65),
        name = "Observed"
      ) |>
        plotly::add_trace(
          data = curve,
          x = ~X,
          y = ~.fitted,
          type = "scatter",
          mode = "lines",
          text = ~.fitted_hover,
          hoverinfo = "text",
          name = "Fitted",
          line = list(color = "#e11d48", width = 2.5),
          inherit = FALSE
        ) |>
        plotly::layout(
          font = list(family = "Inter, -apple-system, sans-serif", color = "#1e293b"),
          hoverlabel = list(
            bgcolor = "#0f172a",
            font = list(family = "Inter, sans-serif", color = "#ffffff", size = 12)
          ),
          legend = list(orientation = "h", y = -0.1, x = 0.5, xanchor = "center"),
          xaxis = list(title = labels$x, gridcolor = "#f1f5f9", zerolinecolor = "#cbd5e1"),
          yaxis = list(title = labels$z, gridcolor = "#f1f5f9", zerolinecolor = "#cbd5e1")
        )
    )
  }

  markers <- if (config$requires_group) {
    plotly::plot_ly(
      enriched,
      x = ~X,
      y = ~Y,
      z = ~Z,
      color = ~Group,
      colors = grDevices::hcl.colors(nlevels(enriched$Group),
                                    palette = "Dynamic"),
      type = "scatter3d",
      mode = "markers",
      text = ~.observed_hover,
      hoverinfo = "text",
      marker = list(size = 4)
    )
  } else {
    plotly::plot_ly(
      enriched,
      x = ~X,
      y = ~Y,
      z = ~Z,
      type = "scatter3d",
      mode = "markers",
      text = ~.observed_hover,
      hoverinfo = "text",
      marker = list(size = 4, color = "#2563eb", opacity = 0.7),
      name = "Observed"
    )
  }

  if (isTRUE(show_surface)) {
    grid <- prediction_grid(df, fit, model_type)
    x <- sort(unique(grid$X))
    y <- sort(unique(grid$Y))
    z <- matrix(NA_real_, nrow = length(y), ncol = length(x))
    z[cbind(match(grid$Y, y), match(grid$X, x))] <- grid$.fitted
    markers <- plotly::add_surface(
      markers,
      x = x,
      y = y,
      z = z,
      colorscale = "Viridis",
      opacity = 0.45,
      showscale = FALSE,
      name = "Population fit",
      hovertemplate = paste0(
        labels$x, ": %{x:.3f}<br>",
        labels$y, ": %{y:.3f}<br>",
        labels$predicted, ": %{z:.3f}<extra>Population fit</extra>"
      ),
      inherit = FALSE
    )
  }

  plotly::layout(
    markers,
    font = list(family = "Inter, -apple-system, sans-serif", color = "#1e293b"),
    hoverlabel = list(
      bgcolor = "#0f172a",
      font = list(family = "Inter, sans-serif", color = "#ffffff", size = 12)
    ),
    legend = list(orientation = "h", y = -0.1, x = 0.5, xanchor = "center"),
    scene = list(
      xaxis = list(title = labels$x, gridcolor = "#f1f5f9", zerolinecolor = "#cbd5e1"),
      yaxis = list(title = labels$y, gridcolor = "#f1f5f9", zerolinecolor = "#cbd5e1"),
      zaxis = list(title = labels$z, gridcolor = "#f1f5f9", zerolinecolor = "#cbd5e1"),
      camera = list(
        eye = list(x = 1.8, y = 1.8, z = 1.5)
      )
    )
  )
}

with_lifecycle_warnings_muffled <- function(expr) {
  withCallingHandlers(
    expr,
    lifecycle_warning_deprecated = function(warning) {
      invokeRestart("muffleWarning")
    }
  )
}

build_diagnostic_plot <- function(fit) {
  custom_theme <- ggplot2::theme_minimal() +
    ggplot2::theme(
      text = ggplot2::element_text(color = "#1e293b"),
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold", color = "#0f172a")
    )

  if (!inherits(fit, "merMod")) {
    if (!requireNamespace("ggfortify", quietly = TRUE)) {
      stop("Package 'ggfortify' is required for LM and GLM diagnostics", call. = FALSE)
    }
    res <- with_lifecycle_warnings_muffled(
      ggplot2::autoplot(
        fit,
        which = 1:4,
        ncol = 2,
        colour = "#2563eb",
        smooth.colour = "#e11d48",
        ad.colour = "#e11d48"
      )
    )
    if (inherits(res, "ggmultiplot")) {
      res@plots <- lapply(res@plots, function(p) p + custom_theme)
    }
    return(res)
  }

  fitted <- fitted_response(fit)
  residual <- response_residuals(fit)
  qq <- stats::qqnorm(residual, plot.it = FALSE)
  diagnostics <- rbind(
    data.frame(panel = "Residuals vs fitted", x = fitted, y = residual),
    data.frame(panel = "Normal Q-Q", x = qq$x, y = qq$y)
  )

  ggplot2::ggplot(diagnostics, ggplot2::aes(x, y)) +
    ggplot2::geom_point(alpha = 0.65, colour = "#2563eb") +
    ggplot2::geom_smooth(
      data = function(d) d[d$panel == "Residuals vs fitted", ],
      method = "loess", formula = y ~ x, se = FALSE, colour = "#e11d48", linewidth = 0.8
    ) +
    ggplot2::geom_line(
      data = function(d) {
        sub <- d[d$panel == "Normal Q-Q", ]
        if (nrow(sub) == 0) return(sub)
        rng <- range(c(sub$x, sub$y), na.rm = TRUE)
        data.frame(panel = "Normal Q-Q", x = rng, y = rng)
      },
      linetype = "dashed", colour = "#e11d48", linewidth = 0.8
    ) +
    ggplot2::facet_wrap(~panel, scales = "free") +
    custom_theme
}
