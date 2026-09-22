library(testthat)

app_root <- if (file.exists(file.path("..", "R", "config.R"))) ".." else "."
for (file in c("config.R", "model_registry.R", "mod_model.R", "model_metrics.R",
               "model_diagnostics.R", "mod_simulation.R", "mod_visualization.R",
               "mod_examples.R", "mod_model_brain.R", "mod_pipeline.R")) {
  source(file.path(app_root, "R", file), local = TRUE)
}

valid_simulation_payload <- function(model_type = "lm_2d", ...) {
  c(list(schema_version = "lmplot-analysis-request/1.0", data_source = "simulation",
         model_type = model_type), list(...))
}

test_that("service factory validates every injected dependency", {
  services <- create_analysis_services()
  expect_s3_class(services, "analysis_services")
  expect_named(services, c("load_example", "simulate", "evaluate_expert", "fit",
    "metrics", "coefficients", "diagnostics", "prediction_grid", "build_model_brain", "resolve_example"))
  for (name in names(services)) {
    for (bad in list(NULL, 1, "function")) {
      error <- tryCatch(do.call(create_analysis_services, setNames(list(bad), name)), error = identity)
      expect_s3_class(error, "analysis_service_error")
      expect_identical(error$code, "invalid_service")
      expect_match(conditionMessage(error), name, fixed = TRUE)
    }
  }
})

test_that("validated simulation returns canonical assessment and grid", {
  request <- new_analysis_request(valid_simulation_payload(simulation = list(n = 50L, seed = 42L)))
  result <- run_analysis_usecase(request, create_analysis_services(), app_root)
  expect_s3_class(result, "analysis_result")
  expect_named(result, c("data", "display", "example", "fit", "model_type", "link", "code",
    "labels", "metrics", "coefficients", "diagnostics", "prediction_grid", "warnings"))
  expect_null(result$example)
  expect_equal(nrow(result$data), 50L)
  expect_equal(nrow(result$prediction_grid), 30L)
  expect_identical(result$link, "identity")
  expect_s3_class(result$fit, "lm")
  expect_true(nzchar(result$code))
  expect_equal(result$metrics$r_squared, summary(result$fit)$r.squared)
  expect_type(result$warnings, "character")
  expect_match(paste(capture.output(print(result)), collapse = ""), "simulation")
})

test_that("nonlinear diagnostics and custom grid reach the result", {
  request <- new_analysis_request(valid_simulation_payload(simulation = list(n = 150L, seed = 42L, pattern = "quadratic")))
  result <- run_analysis_usecase(request, create_analysis_services(), app_root)
  expect_identical(result$diagnostics$status, "warning")
  expect_true(any(grepl("curvature", result$warnings)))
  request <- new_analysis_request(valid_simulation_payload("lm_3d", grid_length_out = 15))
  expect_equal(nrow(run_analysis_usecase(request, create_analysis_services(), app_root)$prediction_grid), 225L)
})

test_that("real examples resolve lazily and match the requested model", {
  services <- create_analysis_services(simulate = function(...) stop("must not simulate"))
  for (model in c("lm_2d", "glmm")) {
    request <- new_analysis_request(list(schema_version = "lmplot-analysis-request/1.0",
      data_source = "real", model_type = model))
    result <- run_analysis_usecase(request, services, app_root)
    expect_identical(result$example$id, if (model == "lm_2d") "adelie_flipper_mass" else "inner_london_exam")
    expect_equal(nrow(result$data), if (model == "lm_2d") 151L else 4059L)
    expect_match(result$code, "load_real_example")
    if (model == "glmm") expect_s4_class(result$fit, "merMod")
  }
  request <- new_analysis_request(list(schema_version = "lmplot-analysis-request/1.0",
    data_source = "real", model_type = "lm_2d", example_id = "inner_london_exam"))
  expect_error(run_analysis_usecase(request, services, app_root), class = "analysis_request_error")
  services$load_example <- function(...) list(analysis = 1, metadata = list(model_type = "lm_2d"))
  expect_error(run_analysis_usecase(request, services, app_root), class = "analysis_request_error")
})

test_that("default real requests use injected resolution without a local manifest", {
  root <- tempfile("missing-analysis-root-")
  expect_false(dir.exists(root))
  data <- data.frame(X = seq_len(20), Z = seq_len(20) + rep(c(-1, 1), 10))
  resolver_call <- loader_call <- NULL
  services <- create_analysis_services(
    resolve_example = function(model_type, root) {
      resolver_call <<- list(model_type, root)
      "injected-example"
    },
    load_example = function(id, root) {
      loader_call <<- list(id, root)
      list(id = id, analysis = data, display = data, metadata = list(model_type = "lm_2d"))
    })
  request <- new_analysis_request(list(schema_version = "lmplot-analysis-request/1.0",
    data_source = "real", model_type = "lm_2d"))
  result <- run_analysis_usecase(request, services, root)
  expect_identical(resolver_call, list("lm_2d", root))
  expect_identical(loader_call, list("injected-example", root))
  expect_identical(result$data, data)
  expect_identical(result$example$id, "injected-example")
  expect_s3_class(result$fit, "lm")
})

test_that("service outputs warnings and errors are faithfully propagated", {
  services <- create_analysis_services(
    metrics = function(fit, model_type, data) list(r_squared = .123),
    fit = function(...) {
      warning("fit warning", call. = FALSE)
      fit <- fit_model(...)
      attr(fit, "model_fit_warnings") <- c("fit warning", "stored warning")
      fit
    },
    diagnostics = function(...) {
      warning("diagnostic warning", call. = FALSE)
      list(status = "warning", warnings = c("stored warning", "diagnostic warning", "assessment warning"))
    },
    build_model_brain = function(...) stop("Task 3 must not build a brain"))
  request <- new_analysis_request(valid_simulation_payload())
  expect_silent(result <- run_analysis_usecase(request, services, app_root))
  expect_identical(result$metrics, list(r_squared = .123))
  expect_identical(result$warnings, c("fit warning", "stored warning", "diagnostic warning", "assessment warning"))
  services$metrics <- function(...) stop("assessment failed")
  expect_error(run_analysis_usecase(request, services, app_root), "assessment failed")
})

test_that("Expert execution enforces trust and the four argument contract", {
  code <- "simulate_data('lm_2d', n = n, seed = seed)"
  p <- valid_simulation_payload(simulation = list(n = 25, seed = 31), expert = list(enabled = TRUE, code = code))
  expect_error(new_analysis_request(p), "trusted local", class = "analysis_security_error")
  request <- new_analysis_request(p, TRUE)
  calls <- list()
  services <- create_analysis_services(evaluate_expert = function(code, parameters, model_type, link) {
    calls[[length(calls) + 1L]] <<- list(code, parameters, model_type, link)
    evaluate_expert_simulation(code, parameters, model_type, link)
  })
  result <- run_analysis_usecase(request, services, app_root)
  expect_equal(nrow(result$data), 25L)
  expect_identical(result$code, code)
  expect_identical(calls[[1]], list(code, request$simulation, "lm_2d", "identity"))
  attr(request, "trusted_local") <- FALSE
  expect_error(run_analysis_usecase(request, services, app_root), "trusted local", class = "analysis_security_error")
  expect_length(calls, 1L)
})

test_that("use case rejects legacy and mutated boundaries before service execution", {
  request <- new_analysis_request(valid_simulation_payload())
  services <- create_analysis_services(simulate = function(...) stop("must not execute"))
  expect_error(run_analysis_usecase(list(), services), class = "analysis_request_error")
  expect_error(run_analysis_usecase(request, list()), class = "analysis_service_error")
  for (bad in list(NULL, "", NA_character_, c(".", ".."))) {
    expect_error(run_analysis_usecase(request, services, bad), class = "analysis_request_error")
  }
  mutations <- list(function(x) { x$simulation$n <- 1; x },
    function(x) { x$link <- NULL; x }, function(x) { x$extra <- TRUE; x },
    function(x) { x$example_id <- "id"; x },
    function(x) { x$simulation$n <- 200; x })
  for (mutate in mutations) {
    expect_error(run_analysis_usecase(mutate(request), services), class = "analysis_request_error")
  }
  services$fit <- 1
  expect_error(run_analysis_usecase(request, services), class = "analysis_service_error")
  expect_error(run_analysis_usecase(model_type = "lm_2d", sim_result = list(data = data.frame())), "unused arguments")
})
