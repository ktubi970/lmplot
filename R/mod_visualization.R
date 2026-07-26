prediction_grid <- function(df, fit, model_type, length_out = 30L) {
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

build_main_plot <- function(df, fit, model_type, show_surface = TRUE) {
  config <- model_config(model_type)
  enriched <- enrich_data(df, fit)

  if (config$dimensions == 2L) {
    curve <- enriched[order(enriched$X), ]
    return(
      plotly::plot_ly(
        enriched,
        x = ~X,
        y = ~Z,
        type = "scatter",
        mode = "markers",
        text = ~sprintf(
          "X: %.3f<br>Z: %.3f<br>Residual: %.3f",
          X,
          Z,
          .residual
        ),
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
          name = "Fitted",
          line = list(color = "#ef4444"),
          inherit = FALSE
        ) |>
        plotly::layout(
          xaxis = list(title = "X"),
          yaxis = list(title = "Z")
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
      inherit = FALSE
    )
  }

  plotly::layout(
    markers,
    scene = list(
      xaxis = list(title = "X"),
      yaxis = list(title = "Y"),
      zaxis = list(title = "Z")
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
