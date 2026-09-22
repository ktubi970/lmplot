library(testthat)

app_root <- if (file.exists(file.path("..", "R", "config.R"))) ".." else "."
for (file in c("config.R", "model_registry.R", "mod_model.R", "model_metrics.R",
               "model_diagnostics.R", "mod_simulation.R", "mod_visualization.R",
               "mod_examples.R", "mod_model_brain.R", "mod_pipeline.R")) {
  source(file.path(app_root, "R", file), local = TRUE)
}

valid_simulation_payload <- function() {
  list(schema_version = "lmplot-analysis-request/1.0", data_source = "simulation",
       model_type = "lm_2d")
}

test_that("request defaults are normalized without accepting extra fields", {
  request <- new_analysis_request(valid_simulation_payload())
  expect_s3_class(request, "analysis_request")
  expect_identical(request$link, "identity")
  expect_identical(request$grid_length_out, 30L)
  expect_identical(request$simulation, list(n = 200L, seed = 123L, beta0 = 2,
    beta1 = .5, beta2 = -.25, sigma = 1, shape = 2, group_sd = 1,
    groups = 5L, pattern = "linear"))
  expect_identical(request$expert, list(enabled = FALSE, code = NULL))
  expect_false(attr(request, "trusted_local"))
  expect_false("trusted_local" %in% names(request))
  p <- valid_simulation_payload()
  p$link <- NULL
  p$grid_length_out <- NULL
  expect_identical(new_analysis_request(p), request)
})

test_that("request rejects malformed objects and required scalar types", {
  p <- valid_simulation_payload()
  malformed <- list(NULL, 1, new.env(), pairlist(a = 1), data.frame(a = 1),
    as.pairlist(p), unname(p), c(p, p[1]), setNames(p, c("", "data_source", "model_type")))
  for (bad in malformed) expect_error(new_analysis_request(bad), class = "analysis_request_error")
  for (key in c("schema_version", "data_source", "model_type")) {
    for (bad in list(NULL, NA_character_, "", 1, factor(p[[key]]), list(p[[key]]), c("a", "b"))) {
      candidate <- p
      candidate[key] <- list(bad)
      expect_error(new_analysis_request(candidate), class = "analysis_request_error")
    }
  }
  for (key in c("schema_version", "data_source", "model_type")) {
    candidate <- p
    candidate[[key]] <- "unsupported"
    expect_error(new_analysis_request(candidate), class = "analysis_request_error")
  }
  for (key in c("typo", "trusted_local", "sim_result")) {
    candidate <- p
    candidate[key] <- list(NULL)
    expect_error(new_analysis_request(candidate), class = "analysis_request_error")
  }
})

test_that("link grid and source presence are strictly validated", {
  p <- valid_simulation_payload()
  for (bad in list("log", "", NA_character_, 1, list("identity"), factor("identity"))) {
    p$link <- bad
    expect_error(new_analysis_request(p), class = "analysis_request_error")
  }
  p$link <- NULL
  for (bad in list(numeric(), character(), 1, 201, 2.5, NA_real_, Inf, "30", TRUE, c(2, 3), c(n = 30), factor(30))) {
    p$grid_length_out <- bad
    expect_error(new_analysis_request(p), class = "analysis_request_error")
  }
  for (good in c(2, 200)) {
    p$grid_length_out <- good
    expect_identical(new_analysis_request(p)$grid_length_out, as.integer(good))
  }
  p <- valid_simulation_payload()
  p["example_id"] <- list(NULL)
  expect_error(new_analysis_request(p), class = "analysis_request_error")
  p <- valid_simulation_payload()
  p$data_source <- "real"
  expect_null(new_analysis_request(p)$simulation)
  for (key in c("simulation", "expert")) {
    candidate <- p
    candidate[key] <- list(NULL)
    expect_error(new_analysis_request(candidate), class = "analysis_request_error")
  }
  for (bad in list(1, "", NA_character_, list("id"))) {
    p$example_id <- bad
    expect_error(new_analysis_request(p), class = "analysis_request_error")
  }
})

test_that("simulation validates nested keys types and every public bound", {
  p <- valid_simulation_payload()
  for (bad in list(1, data.frame(n = 50), list(50), list(n = 50, n = 60), list(typo = NULL))) {
    p$simulation <- bad
    expect_error(new_analysis_request(p), class = "analysis_request_error")
  }
  cases <- list(n = list(9, 2001, 20.5), seed = list(-1, 2147483648, .5),
    groups = list(4, 21, 5.5), beta0 = list(-3.1, 5.1), beta1 = list(-2.1, 2.1),
    beta2 = list(-2.1, 2.1), sigma = list(0, 5.1), shape = list(.4, 10.1),
    group_sd = list(-.1, 4.1), pattern = list("invalid", "", NA_character_))
  for (key in names(cases)) {
    invalid <- c(cases[[key]], list(NULL, NA, Inf, "50", TRUE, list(50), c(1, 2), c(value = 1)))
    for (bad in invalid) {
      p$simulation <- setNames(list(bad), key)
      expect_error(new_analysis_request(p), class = "analysis_request_error")
    }
  }
  p$simulation <- list(n = 10, groups = 11)
  expect_error(new_analysis_request(p), class = "analysis_request_error")
  p$simulation <- list(n = 10, groups = 10, seed = 0)
  expect_identical(new_analysis_request(p)$simulation$n, 10L)
})

test_that("Expert requires the exact schema and a trusted local capability", {
  p <- valid_simulation_payload()
  for (bad in list(list(enabled = FALSE), list(code = NULL), list(enabled = FALSE, code = "x"),
    list(enabled = 1, code = "x"), list(enabled = NA, code = NULL),
    list(enabled = TRUE, code = " "), list(enabled = FALSE, code = NULL, extra = NULL))) {
    p$expert <- bad
    expect_error(new_analysis_request(p, TRUE), class = "analysis_request_error")
  }
  p$expert <- list(enabled = TRUE, code = "data.frame(X=1:20, Z=1:20)")
  for (untrusted in list(FALSE, NA, 1, "TRUE", c(TRUE, TRUE))) {
    error <- tryCatch(new_analysis_request(p, untrusted), error = identity)
    expect_s3_class(error, "analysis_security_error")
    expect_identical(error$code, "expert_not_trusted")
    expect_match(conditionMessage(error), "trusted local")
  }
  expect_s3_class(new_analysis_request(p, TRUE), "analysis_request")
})
