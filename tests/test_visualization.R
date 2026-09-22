source(file.path("..", "R", "model_registry.R"))
source(file.path("..", "R", "mod_model.R"))
source(file.path("..", "R", "mod_simulation.R"))
visualization_path <- file.path("..", "R", "mod_visualization.R")
if (file.exists(visualization_path)) source(visualization_path)

.beta_model_cache <- new.env(parent = emptyenv())
fit_beta_model <- function(model_type, seed = 10L) {
  key <- paste(model_type, seed, sep = "_")
  if (exists(key, envir = .beta_model_cache, inherits = FALSE)) {
    return(get(key, envir = .beta_model_cache))
  }
  link <- model_config(model_type)$default_link
  df <- simulate_data(model_type, link, seed = seed)
  res <- list(df = df, fit = fit_model(df, model_type, link))
  assign(key, res, envir = .beta_model_cache)
  res
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

test_that("valid GLMM fitting and enrichment preserve every input row", {
  df <- simulate_data("glmm", "identity", n = 103L, groups = 7L, seed = 19L)
  fit <- fit_model(df, "glmm", "identity")
  enriched <- enrich_data(df, fit)

  expect_length(fitted_response(fit), nrow(df))
  expect_length(response_residuals(fit), nrow(df))
  expect_equal(nrow(enriched), nrow(df))
  expect_identical(enriched[setdiff(names(enriched), c(".fitted", ".residual"))], df)
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

test_that("prediction_grid expands bounds according to pad parameter", {
  model <- fit_beta_model("lm_2d")
  df <- model$df
  grid_default <- prediction_grid(df, model$fit, "lm_2d", pad = 0.15)
  grid_zero <- prediction_grid(df, model$fit, "lm_2d", pad = 0)

  rx <- range(df$X, na.rm = TRUE)
  dx <- diff(rx)

  expect_equal(min(grid_zero$X), min(rx))
  expect_equal(max(grid_zero$X), max(rx))
  expect_equal(min(grid_default$X), min(rx) - 0.15 * dx)
  expect_equal(max(grid_default$X), max(rx) + 0.15 * dx)
})

test_that("3D plots include initial camera eye position", {
  model <- fit_beta_model("lm_3d")
  plot <- build_main_plot(model$df, model$fit, "lm_3d")
  built <- plotly::plotly_build(plot)

  expect_equal(built$x$layout$scene$camera$eye$x, 1.8)
  expect_equal(built$x$layout$scene$camera$eye$y, 1.8)
  expect_equal(built$x$layout$scene$camera$eye$z, 1.5)
})

