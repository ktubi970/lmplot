library(testthat)

app_root <- if (file.exists(file.path("..", "R", "config.R"))) ".." else "."
source(file.path(app_root, "R", "config.R"), local = TRUE)
source(file.path(app_root, "R", "model_registry.R"), local = TRUE)
source(file.path(app_root, "R", "mod_model.R"), local = TRUE)
source(file.path(app_root, "R", "model_metrics.R"), local = TRUE)
source(file.path(app_root, "R", "model_diagnostics.R"), local = TRUE)
source(file.path(app_root, "R", "mod_simulation.R"), local = TRUE)
source(file.path(app_root, "R", "mod_visualization.R"), local = TRUE)
source(file.path(app_root, "R", "mod_examples.R"), local = TRUE)
source(file.path(app_root, "R", "mod_pipeline.R"), local = TRUE)

test_that("create_analysis_pipeline creates a customizable pipeline with DI", {
  pipeline <- create_analysis_pipeline()
  expect_type(pipeline, "list")
  expect_named(pipeline, c("fit", "predict", "kpis", "coefficients", "diagnostics", "grid", "metrics", "intervals"))
  expect_true(is.function(pipeline$fit))
  expect_true(is.function(pipeline$predict))
  expect_true(is.function(pipeline$kpis))
  expect_true(is.function(pipeline$coefficients))
  expect_true(is.function(pipeline$diagnostics))
  expect_true(is.function(pipeline$grid))

  # Test custom dependency injection
  mock_fit_called <- FALSE
  mock_fit <- function(df, model_type, link) {
    mock_fit_called <<- TRUE
    stats::lm(Z ~ X, data = df)
  }

  custom_pipeline <- create_analysis_pipeline(fit_fn = mock_fit)
  df <- data.frame(X = 1:20, Z = 2 * (1:20) + rnorm(20))
  res <- custom_pipeline$fit(df, "lm_2d", "identity")
  expect_true(mock_fit_called)
  expect_s3_class(res, "lm")
})

test_that("run_analysis_usecase executes simulation workflow correctly", {
  result <- run_analysis_usecase(
    data_source = "simulation",
    model_type = "lm_2d",
    link = "identity",
    sim_params = list(n = 50L, seed = 42L),
    root = app_root
  )

  expect_s3_class(result, "analysis_result")
  expect_named(
    result,
    c("data", "display", "example", "fit", "model_type", "link", "code",
      "labels", "kpis", "coefficients", "linearity_diag", "prediction_grid", "metrics", "diagnostics", "response_interval")
  )
  expect_null(result$example)
  expect_equal(nrow(result$data), 50L)
  expect_equal(result$model_type, "lm_2d")
  expect_equal(result$link, "identity")
  expect_s3_class(result$fit, "lm")
  expect_true(nzchar(result$code))
  expect_false(is.null(result$linearity_diag))
  expect_false(is.null(result$prediction_grid))
  expect_equal(result$diagnostics$status, "information")
  expect_equal(result$metrics$r_squared, summary(result$fit)$r.squared)
  expect_true(result$response_interval$available)
})

test_that("run_analysis_usecase handles non-linear pattern simulation", {
  result_quad <- run_analysis_usecase(
    data_source = "simulation",
    model_type = "lm_2d",
    link = "identity",
    sim_params = list(n = 150L, seed = 42L, pattern = "quadratic"),
    root = app_root
  )

  expect_s3_class(result_quad, "analysis_result")
  expect_equal(result_quad$diagnostics$status, "warning")
  expect_true(any(grepl("curvature", result_quad$diagnostics$warnings)))
})

test_that("run_analysis_usecase executes real data workflow correctly", {
  result <- run_analysis_usecase(
    data_source = "real",
    model_type = "lm_2d",
    root = app_root
  )

  expect_s3_class(result, "analysis_result")
  expect_false(is.null(result$example))
  expect_equal(result$example$id, "adelie_flipper_mass")
  expect_equal(nrow(result$data), 151L)
  expect_true("Flipper length (mm)" %in% result$labels$x || nzchar(result$labels$x))
  expect_s3_class(result$fit, "lm")
  expect_true(grepl("load_real_example", result$code))
})

test_that("run_analysis_usecase supports GLMM on real data", {
  result <- run_analysis_usecase(
    data_source = "real",
    model_type = "glmm",
    root = app_root
  )

  expect_s3_class(result, "analysis_result")
  expect_equal(result$example$id, "inner_london_exam")
  expect_s4_class(result$fit, "merMod")
  expect_equal(nrow(result$data), 4059L)
})

test_that("run_analysis_usecase respects dependency injection pipeline", {
  custom_kpis <- list(r2_status = "perfect", r2_value = "1.00", health_value = "100")
  mock_pipeline <- create_analysis_pipeline(
    kpis_fn = function(fit, model_type, metrics, diagnostics) custom_kpis
  )

  result <- run_analysis_usecase(
    data_source = "simulation",
    model_type = "lm_2d",
    pipeline = mock_pipeline,
    root = app_root
  )

  expect_identical(result$kpis, custom_kpis)
})

test_that("assessment services are injected and their values reach presentation", {
  pipeline <- create_analysis_pipeline(metrics_fn = function(fit, model_type, data) {
    metrics <- extract_model_metrics(fit, model_type, data)
    metrics$r_squared <- .123
    metrics
  }, diag_fn = function(fit, data, model_type) {
    list(strategy = "lm", status = "warning", summary = "Injected diagnostic result",
      checks = list(), warnings = "Injected warning")
  })
  result <- run_analysis_usecase(model_type = "lm_2d", pipeline = pipeline, root = app_root)
  expect_identical(result$metrics$r_squared, .123)
  expect_identical(result$kpis$r2_value, "12.3%")
  expect_identical(result$kpis$health_sub, "Injected diagnostic result")
})

test_that("run_analysis_usecase rejects invalid arguments", {
  expect_error(
    run_analysis_usecase(data_source = "invalid", model_type = "lm_2d", root = app_root),
    "'arg' should be one of"
  )
  expect_error(
    run_analysis_usecase(data_source = "simulation", model_type = "unknown_model", root = app_root),
    "Unknown model type"
  )
  expect_error(
    run_analysis_usecase(data_source = "simulation", model_type = "lm_2d", link = "invalid_link", root = app_root),
    "Invalid link"
  )
})

test_that("run_analysis_usecase respects grid_length_out and print.analysis_result works", {
  result_custom_grid <- run_analysis_usecase(
    data_source = "simulation",
    model_type = "lm_3d",
    grid_length_out = 15L,
    root = app_root
  )

  expect_equal(nrow(result_custom_grid$prediction_grid), 15L * 15L)

  # Test print method
  printed <- capture.output(print(result_custom_grid))
  expect_true(any(grepl("<AnalysisResult: lm_3d", printed)))
  expect_true(any(grepl("simulation", printed)))
})
