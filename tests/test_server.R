withr::local_envvar(LMPLOT_TRUSTED_LOCAL = NA)
source(file.path("..", "app.R"), local = TRUE)

test_that("coordinator retains success, logs details, sanitizes failures and recovers", {
  expect_true(exists("create_app_coordinator"))
  if (!exists("create_app_coordinator")) return()
  shiny::testServer(function(input, output, session) {
    coordinator <- create_app_coordinator(create_analysis_services(), root = "..")
  }, {
    payload <- list(schema_version = "lmplot-analysis-request/1.0", data_source = "simulation",
      model_type = "lm_2d", simulation = list(n = 40L, seed = 12L))
    expect_null(coordinator$result())
    expect_true(coordinator$analyze(payload))
    previous <- coordinator$result(); request <- coordinator$successful_request()
    generation <- coordinator$generation()
    log <- capture.output(expect_false(coordinator$analyze(stop(simpleError("SECRET /private/path", call = quote(secret_operation()))))), type = "message")
    expect_match(paste(log, collapse = " "), "SECRET /private/path", fixed = TRUE)
    expect_match(paste(log, collapse = " "), "secret_operation")
    expect_identical(coordinator$result(), previous)
    expect_identical(coordinator$successful_request(), request)
    expect_identical(coordinator$generation(), generation)
    expect_true(coordinator$stale()); expect_false(coordinator$running())
    expect_identical(coordinator$public_error(), "Analysis failed. Review the settings and try again.")
    expect_true(coordinator$analyze(payload))
    expect_false(coordinator$stale()); expect_null(coordinator$public_error())
    expect_false(identical(coordinator$generation(), generation))
  })
})

test_that("service and logger failure preserves results; first failure is not stale", {
  expect_true(exists("create_app_coordinator"))
  if (!exists("create_app_coordinator")) return()
  calls <- 0L
  service <- create_analysis_services(fit = function(...) {
    calls <<- calls + 1L
    if (calls != 2L) stop("SECRET service failure")
    fit_model(...)
  })
  shiny::testServer(function(input, output, session) {
    coordinator <- create_app_coordinator(service, root = "..", logger = function(e) stop("logger failed"))
  }, {
    payload <- list(schema_version = "lmplot-analysis-request/1.0", data_source = "simulation", model_type = "lm_2d")
    capture.output(coordinator$analyze(payload), type = "message")
    expect_null(coordinator$result()); expect_false(coordinator$stale()); expect_false(coordinator$running())
    expect_true(coordinator$analyze(payload)); previous <- coordinator$result()
    capture.output(coordinator$analyze(payload), type = "message")
    expect_identical(coordinator$result(), previous)
    expect_true(coordinator$stale()); expect_false(coordinator$running())
  })
})

test_that("automatic app updates replace data only after the next analysis succeeds", {
  expect_true(exists("create_app_coordinator"))
  if (!exists("create_app_coordinator")) return()
  shiny::testServer(server, {
    session$setInputs(`configuration-model_type` = "glm_binomial_2d", `configuration-data_source` = "simulation",
      `configuration-link_sel` = "logit")
    expect_true(exists("coordinator"))
    expect_identical(coordinator$result()$model_type, "glm_binomial_2d")
    expect_equal(nrow(coordinator$result()$data), 200L)
    session$setInputs(`configuration-simulation-n` = 40L)
    session$elapse(350)
    previous <- coordinator$result()
    expect_identical(previous$model_type, "glm_binomial_2d")
    csv <- read.csv(output$`data_provenance-download`)
    session$setInputs(`configuration-model_type` = "glm_gamma", `configuration-simulation-n` = 90L)
    expect_identical(coordinator$result(), previous)
    expect_identical(read.csv(output$`data_provenance-download`), csv)
    session$setInputs(`configuration-link_sel` = "inverse")
    session$elapse(350)
    expect_identical(coordinator$result()$model_type, "glm_gamma")
    expect_equal(nrow(read.csv(output$`data_provenance-download`)), 90L)
  })
})

test_that("all registered models and real examples use the canonical workflow", {
  shiny::testServer(server, {
    session$flushReact()
    simulation_links <- c(lm_2d = "identity", lm_3d = "identity", glm_binomial_2d = "logit",
      glm_binomial = "logit", glm_poisson = "log", glm_gamma = "inverse", glmm = "identity")
    for (source in c("simulation", "real")) for (id in model_ids()) {
      session$setInputs(`configuration-model_type` = id, `configuration-data_source` = source,
        `configuration-simulation-n` = 40L)
      session$setInputs(`configuration-link_sel` = if (source == "real" && id == "glm_gamma") "log" else simulation_links[[id]])
      session$elapse(350)
      value <- coordinator$result()
      expect_identical(value$model_type, id, info = paste(source, id))
      expect_identical(is.null(value$example), source == "simulation")
      expect_identical(coordinator$public_error(), NULL)
      expect_false(is.null(output$`overview-main_plot`))
      expect_false(is.null(output$`diagnostics-plot`))
      expect_equal(nrow(read.csv(output$`data_provenance-download`)), nrow(value$data))
      if (source == "real") {
        html <- output$`data_provenance-provenance`$html
        expect_match(html, value$example$metadata$license_name, fixed = TRUE)
        expect_match(html, value$example$metadata$source_sha256, fixed = TRUE)
      }
    }
  })
})

test_that("trusted Expert runs only through the boundary and invalid GLMM retains CSV", {
  withr::local_envvar(LMPLOT_TRUSTED_LOCAL = "1")
  app <- new.env(parent = environment(server)); source(file.path("..", "app.R"), local = app)
  shiny::testServer(app$server, {
    session$flushReact()
    session$setInputs(`configuration-model_type` = "lm_2d", `configuration-data_source` = "simulation",
      `configuration-link_sel` = "identity",
      `configuration-simulation-n` = 40L, `configuration-simulation-expert_mode` = TRUE,
      `configuration-simulation-code` = "simulate_data('lm_2d', n = n, seed = seed)")
    session$elapse(350)
    previous <- coordinator$result(); expect_equal(nrow(previous$data), 40)
    csv <- read.csv(output$`data_provenance-download`)
    session$setInputs(`configuration-model_type` = "glmm",
      `configuration-simulation-code` = "data.frame(X=1:40, Y=1:40, Z=1:40, Group=rep(1:4,10))")
    log <- capture.output(session$elapse(350), type = "message")
    expect_match(paste(log, collapse = " "), "at least 5 observed groups")
    expect_identical(coordinator$result(), previous)
    expect_identical(read.csv(output$`data_provenance-download`), csv)
    expect_true(coordinator$stale())
    expect_false(grepl("observed groups", output$`analysis_status-error`))
  })
})

test_that("separate sessions start empty and only literal trust flag enables Expert", {
  for (flag in c("true", "TRUE", "yes", "0", "")) {
    withr::local_envvar(LMPLOT_TRUSTED_LOCAL = flag)
    app <- new.env(parent = environment(server)); source(file.path("..", "app.R"), local = app)
    expect_false(grepl("expert_mode", as.character(app$ui)))
    shiny::testServer(app$server, { expect_null(coordinator$result()); expect_equal(coordinator$generation(), 0L) })
  }
})
