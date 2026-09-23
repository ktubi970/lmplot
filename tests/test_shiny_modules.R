source(file.path("..", "app.R"), local = TRUE)

test_that("configuration validates source-exclusive requests and rejects forged Expert", {
  expect_true(exists("configuration_server"))
  if (!exists("configuration_server")) return()
  shiny::testServer(configuration_server, args = list(root = ".."), {
    session$setInputs(model_type = "lm_2d", data_source = "simulation")
    expect_s3_class(new_analysis_request(payload()), "analysis_request")
    expect_false("example_id" %in% names(payload()))
    session$setInputs(`simulation-expert_mode` = TRUE, `simulation-code` = "stop('forged')")
    expect_error(payload(), class = "analysis_security_error")
    session$setInputs(data_source = "real")
    expect_false(any(c("simulation", "expert") %in% names(payload())))
    expect_s3_class(new_analysis_request(payload()), "analysis_request")
  })
})

test_that("configuration resets shared links and ignores delayed prior selections", {
  expect_true(exists("configuration_server"))
  if (!exists("configuration_server")) return()
  shiny::testServer(configuration_server, args = list(root = ".."), {
    session$setInputs(model_type = "glm_poisson", data_source = "simulation")
    session$setInputs(link_sel = "log")
    session$setInputs(link_sel = "identity")
    expect_identical(payload()$link, "identity")
    session$setInputs(model_type = "glm_gamma")
    session$setInputs(link_sel = "identity")
    expect_identical(payload()$link, "inverse")
    session$setInputs(link_sel = "inverse")
    session$setInputs(link_sel = "log")
    expect_identical(payload()$link, "log")
    session$setInputs(data_source = "real")
    expect_identical(payload()$link, "log")
    expect_match(output$link_ui$html, "literature-backed")
  })
})

test_that("a same-default model switch accepts the next visible link selection", {
  shiny::testServer(configuration_server, args = list(root = ".."), {
    session$setInputs(model_type = "glm_binomial_2d", data_source = "simulation")
    session$setInputs(link_sel = "logit")
    expect_identical(payload()$link, "logit")
    session$setInputs(model_type = "glm_binomial")
    expect_identical(payload()$link, "logit")
    session$setInputs(link_sel = "probit")
    expect_identical(payload()$link, "probit")
  })
})

test_that("views render committed values without scientific recomputation", {
  for (name in c("overview_server", "diagnostics_server", "data_provenance_server")) expect_true(exists(name), info = name)
  if (!exists("overview_server")) return()
  fixture <- run_analysis_usecase(new_analysis_request(list(schema_version = "lmplot-analysis-request/1.0",
    model_type = "lm_2d", data_source = "simulation", simulation = list(n = 40L))), create_analysis_services(), "..")
  fail <- function(...) stop("Scientific recomputation from renderer")
  rlang::local_bindings(fit_model = fail, predict_response = fail, extract_model_metrics = fail,
    extract_coefficient_table = fail, diagnose_model = fail, build_model_brain = fail, prediction_grid = fail,
    .env = environment(overview_server))
  value <- shiny::reactiveVal(NULL)
  shiny::testServer(overview_server, args = list(result = value), {
    expect_match(output$metrics$html, "No analysis yet")
    value(fixture); session$flushReact()
    expect_match(output$metrics$html, "40")
    expect_false(is.null(output$main_plot))
    session$setInputs(show_surface = FALSE, `guided_interpretation-show` = 1)
    expect_match(output$`guided_interpretation-content`$html, "association")
    expect_match(output$coefficients, "Student t")
  })
  value(NULL)
  shiny::testServer(diagnostics_server, args = list(result = value), {
    expect_match(output$heading, "No analysis yet")
    value(fixture); session$flushReact()
    expect_match(output$heading, "LM")
    expect_match(output$checks, "curvature")
    expect_false(is.null(output$plot))
  })
  value(NULL)
  shiny::testServer(data_provenance_server, args = list(result = value), {
    expect_match(output$provenance$html, "No analysis yet")
    value(fixture); session$flushReact()
    downloaded <- read.csv(output$download, check.names = FALSE)
    expect_equal(nrow(downloaded), 40)
    expect_equal(downloaded$.fitted, vapply(fixture$model_brain$observations, `[[`, numeric(1), "prediction"))
    expect_equal(downloaded$.residual, fixture$data$Z - downloaded$.fitted)
    expect_identical(output$code, fixture$code)
  })
})

test_that("public and trusted configuration controls are capability-gated and namespaced", {
  expect_true(exists("configuration_ui"))
  if (!exists("configuration_ui")) return()
  public <- as.character(configuration_ui("one"))
  trusted <- as.character(configuration_ui("two", trusted_local = TRUE))
  expect_false(grepl("expert_mode|two-", public))
  expect_match(public, "one-model_type")
  expect_match(trusted, "two-simulation-expert_mode")
})

test_that("Overview selection uses stable identities and rejects stale result events", {
  fixture <- run_analysis_usecase(new_analysis_request(list(schema_version = "lmplot-analysis-request/1.0",
    model_type = "lm_2d", data_source = "simulation", simulation = list(n = 40L))), create_analysis_services(), "..")
  fail <- function(...) stop("Selection must not recompute science")
  rlang::local_bindings(fit_model = fail, predict_response = fail, diagnose_model = fail,
    build_model_brain = fail, .env = environment(overview_server))
  current <- shiny::reactiveVal(fixture); token <- shiny::reactiveVal(list(value = 1L, failed = FALSE))
  generation <- shiny::reactive(token()$value)
  shiny::testServer(overview_server, args = list(result = current, generation = generation), {
    session$flushReact()
    session$setInputs(observation_selection = list(observation_id = "12", generation = 1))
    expect_identical(session$returned$selection(), list(observation_id = "12", generation = 1L))
    token(list(value = 1L, failed = TRUE)); session$flushReact()
    expect_identical(session$returned$selection(), list(observation_id = "12", generation = 1L))
    token(list(value = 2L, failed = FALSE)); session$flushReact()
    seeded <- list(observation_id = fixture$model_brain$default_observation_id, generation = 2L)
    expect_identical(session$returned$selection(), seeded)
    session$setInputs(observation_selection = list(observation_id = "12", generation = 1))
    expect_identical(session$returned$selection(), seeded)
    session$setInputs(observation_selection = list(observation_id = "not-a-row", generation = 2))
    expect_identical(session$returned$selection(), seeded)
  })
  built <- plotly::plotly_build(render_analysis_main_plot(fixture, generation = 1L))
  points <- Filter(function(trace) identical(trace$mode, "markers"), built$x$data)[[1]]
  metadata <- jsonlite::fromJSON(points$customdata[[12]])
  expect_identical(metadata$observation_id, "12")
  expect_equal(metadata$generation, 1)
})

test_that('diagnostic guidance exposes known advice without raw optimizer details', {
  fixture <- run_analysis_usecase(new_analysis_request(list(schema_version = 'lmplot-analysis-request/1.0',
    model_type = 'lm_2d', data_source = 'simulation', simulation = list(n = 40L))), create_analysis_services(), '..')
  fixture$diagnostics$warnings <- c('Residual spread varies with fitted values; inspect variance assumptions.',
    'SECRET optimizer exception /private/path')
  shiny::testServer(diagnostics_server, args = list(result = shiny::reactive(fixture)), {
    expect_match(output$guidance$html, 'Residual spread varies')
    expect_false(grepl('SECRET|/private/path', output$guidance$html))
  })
})

test_that("configuration instances keep disjoint draft state", {
  shiny::testServer(function(input, output, session) {
    first <- configuration_server("first", root = "..")
    second <- configuration_server("second", root = "..")
  }, {
    session$setInputs(`first-model_type` = "glm_poisson", `second-model_type` = "lm_2d",
      `first-simulation-n` = 50L, `second-simulation-n` = 70L)
    expect_identical(first$payload()$model_type, "glm_poisson")
    expect_identical(second$payload()$model_type, "lm_2d")
    expect_equal(first$payload()$simulation$n, 50)
    expect_equal(second$payload()$simulation$n, 70)
  })
})
