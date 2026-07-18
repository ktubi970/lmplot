source(file.path("..", "R", "mod_model.R"))
source(file.path("..", "R", "mod_simulation.R"))
visualization_path <- file.path("..", "R", "mod_visualization.R")
if (file.exists(visualization_path)) source(visualization_path)

fit_beta_model <- function(model_type, seed = 10L) {
  link <- model_config(model_type)$default_link
  df <- simulate_data(model_type, link, seed = seed)
  list(df = df, fit = fit_model(df, model_type, link))
}

test_that("prediction grids contain finite response-scale fits", {
  for (model_type in model_ids()) {
    model <- fit_beta_model(model_type)
    grid <- prediction_grid(model$df, model$fit, model_type, length_out = 12L)
    config <- model_config(model_type)

    expect_equal(nrow(grid), if (config$dimensions == 2L) 12L else 12L^2L)
    expect_true(all(is.finite(grid$.fitted)))

    prediction_data <- grid[setdiff(names(grid), ".fitted")]
    expected <- predict_response(
      model$fit,
      prediction_data,
      population = config$requires_group
    )
    expect_equal(grid$.fitted, as.numeric(expected))
  }
})

test_that("GLMM prediction grids represent a population surface", {
  model <- fit_beta_model("glmm")
  grid <- prediction_grid(model$df, model$fit, "glmm", length_out = 4L)

  expect_s3_class(grid$Group, "factor")
  expect_identical(levels(grid$Group), levels(model$df$Group))
  conditional <- predict_response(model$fit, grid, population = FALSE)
  population <- predict_response(model$fit, grid, population = TRUE)
  expect_equal(grid$.fitted, as.numeric(population))
  expect_false(isTRUE(all.equal(grid$.fitted, as.numeric(conditional))))
})

test_that("GLMM surfaces accept character group data", {
  link <- model_config("glmm")$default_link
  df <- simulate_data("glmm", link, seed = 11L)
  df$Group <- as.character(df$Group)
  fit <- fit_model(df, "glmm", link)

  grid <- prediction_grid(df, fit, "glmm", length_out = 4L)
  expected_levels <- levels(stats::model.frame(fit)$Group)
  expect_s3_class(grid$Group, "factor")
  expect_identical(levels(grid$Group), expected_levels)
  expect_true(all(is.finite(grid$.fitted)))

  built <- plotly::plotly_build(
    build_main_plot(df, fit, "glmm", show_surface = TRUE)
  )
  surface_count <- sum(vapply(built$x$data, function(trace) {
    identical(trace$type, "surface")
  }, logical(1)))
  expect_equal(surface_count, 1L)
})

test_that("enrichment adds exactly fitted values and response residuals", {
  for (model_type in model_ids()) {
    model <- fit_beta_model(model_type)
    original_names <- names(model$df)
    enriched <- enrich_data(model$df, model$fit)

    expect_equal(nrow(enriched), nrow(model$df))
    expect_identical(names(enriched), c(original_names, ".fitted", ".residual"))
    expect_equal(enriched$.fitted, fitted_response(model$fit))
    expect_equal(enriched$.residual, response_residuals(model$fit))
  }
})

test_that("2D LM plot contains observations and an X-ordered fitted line", {
  model <- fit_beta_model("lm_2d")
  plot <- build_main_plot(model$df, model$fit, "lm_2d")
  built <- plotly::plotly_build(plot)

  expect_s3_class(plot, "plotly")
  expect_length(built$x$data, 2L)
  expect_identical(built$x$data[[1L]]$type, "scatter")
  expect_identical(built$x$data[[1L]]$mode, "markers")
  expect_identical(built$x$data[[2L]]$mode, "lines")
  expect_true(all(diff(as.numeric(built$x$data[[2L]]$x)) >= 0))
})

test_that("3D plots contain point clouds and optional response surfaces", {
  for (model_type in c(
    "lm_3d",
    "glm_binomial",
    "glm_poisson",
    "glm_gamma",
    "glmm"
  )) {
    model <- fit_beta_model(model_type)
    with_surface <- plotly::plotly_build(
      build_main_plot(model$df, model$fit, model_type, show_surface = TRUE)
    )
    without_surface <- plotly::plotly_build(
      build_main_plot(model$df, model$fit, model_type, show_surface = FALSE)
    )

    surface_index <- which(vapply(with_surface$x$data, function(trace) {
      identical(trace$type, "surface")
    }, logical(1)))
    expect_length(surface_index, 1L)
    expect_false(any(vapply(without_surface$x$data, function(trace) {
      identical(trace$type, "surface")
    }, logical(1))))
    expect_true(any(vapply(without_surface$x$data, function(trace) {
      identical(trace$type, "scatter3d") && identical(trace$mode, "markers")
    }, logical(1))))
  }
})

test_that("surface matrix rows map to Y and columns map to X", {
  model <- fit_beta_model("glm_gamma")
  built <- plotly::plotly_build(
    build_main_plot(model$df, model$fit, "glm_gamma", show_surface = TRUE)
  )
  surface <- built$x$data[[which(vapply(built$x$data, function(trace) {
    identical(trace$type, "surface")
  }, logical(1)))]]
  x <- as.numeric(surface$x)
  y <- as.numeric(surface$y)
  z <- surface$z

  expect_equal(dim(z), c(length(y), length(x)))
  corners <- expand.grid(x_index = c(1L, length(x)), y_index = c(1L, length(y)))
  expected <- predict_response(
    model$fit,
    data.frame(X = x[corners$x_index], Y = y[corners$y_index])
  )
  actual <- mapply(function(x_index, y_index) z[y_index, x_index],
                   corners$x_index, corners$y_index)
  expect_equal(as.numeric(actual), as.numeric(expected))
})

test_that("GLMM observations retain group color mapping", {
  model <- fit_beta_model("glmm")
  built <- plotly::plotly_build(
    build_main_plot(model$df, model$fit, "glmm", show_surface = FALSE)
  )
  point_traces <- Filter(function(trace) identical(trace$type, "scatter3d"), built$x$data)

  expect_equal(length(point_traces), nlevels(model$df$Group))
  expect_setequal(vapply(point_traces, `[[`, character(1), "name"), levels(model$df$Group))
})

test_that("diagnostic plots use supported representations", {
  lm_model <- fit_beta_model("lm_2d")
  glm_model <- fit_beta_model("glm_binomial")
  glmm_model <- fit_beta_model("glmm")

  expect_s4_class(build_diagnostic_plot(lm_model$fit), "ggmultiplot")
  expect_s4_class(build_diagnostic_plot(glm_model$fit), "ggmultiplot")

  glmm_plot <- build_diagnostic_plot(glmm_model$fit)
  expect_s3_class(glmm_plot, "ggplot")
  expect_setequal(
    unique(glmm_plot$data$panel),
    c("Residuals vs fitted", "Normal Q-Q")
  )
})

test_that("diagnostic warning filtering preserves non-lifecycle warnings", {
  expect_warning(
    result <- with_lifecycle_warnings_muffled({
      warning("ordinary diagnostic warning", call. = FALSE)
      "result"
    }),
    "ordinary diagnostic warning"
  )
  expect_identical(result, "result")
})
