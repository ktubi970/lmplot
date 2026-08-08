prediction_grid <- function(df, fit, model_type,
                            length_out = if (model_config(model_type)$dimensions == 2L) 200L else 30L) {
  config <- model_config(model_type)
  x <- seq(min(df$X), max(df$X), length.out = length_out)

  if (config$dimensions == 2L) {
    grid <- data.frame(X = x)
  } else {
    y <- seq(min(df$Y), max(df$Y), length.out = length_out)
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
  resolved <- list(x = "X", y = "Y", z = "Z", group = "Group")
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
  paste0(text, "<br>Residual: ", sprintf("%.3f", data$.residual))
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
      "<br>Fitted ", labels$z, ": ", sprintf("%.3f", curve$.fitted)
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
          line = list(color = "#ef4444"),
          inherit = FALSE
        ) |>
        plotly::layout(
          xaxis = list(title = labels$x),
          yaxis = list(title = labels$z)
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
      opacity = 0.45,
      showscale = FALSE,
      name = "Population fit",
      hovertemplate = paste0(
        labels$x, ": %{x:.3f}<br>",
        labels$y, ": %{y:.3f}<br>",
        labels$z, ": %{z:.3f}<extra>Population fit</extra>"
      ),
      inherit = FALSE
    )
  }

  plotly::layout(
    markers,
    scene = list(
      xaxis = list(title = labels$x),
      yaxis = list(title = labels$y),
      zaxis = list(title = labels$z)
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
  if (!inherits(fit, "merMod")) {
    if (!requireNamespace("ggfortify", quietly = TRUE)) {
      stop("Package 'ggfortify' is required for LM and GLM diagnostics", call. = FALSE)
    }
    return(with_lifecycle_warnings_muffled(
      ggplot2::autoplot(
        fit,
        which = 1:4,
        ncol = 2,
        colour = "#2563eb"
      )
    ))
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
    ggplot2::facet_wrap(~panel, scales = "free") +
    ggplot2::theme_minimal()
}
