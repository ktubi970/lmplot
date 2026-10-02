source(file.path("..", "app.R"), local = TRUE)

test_that("configuration changes fit the latest request and view navigation never refits", {
  expect_true(exists("bind_automatic_analysis")); if (!exists("bind_automatic_analysis")) return()
  fits <- 0L
  counted <- create_analysis_services(fit = function(...) { fits <<- fits + 1L; fit_model(...) })
  shiny::testServer(function(input, output, session) {
    config <- configuration_server("config", root = "..")
    coordinator <- create_app_coordinator(counted, root = "..", logger = function(e) NULL)
    automatic <- bind_automatic_analysis(config, coordinator, delay = 300)
  }, {
    session$setInputs(`config-model_type` = "lm_2d", `config-data_source` = "simulation",
      `config-link_sel` = "identity", `config-simulation-n` = 40L, `config-simulation-seed` = 12L)
    session$elapse(350)
    expect_equal(nrow(coordinator$result()$data), 40L)
    expect_equal(fits, 1L)
    # Numeric inputs acknowledge defaults as doubles after server-rendered controls bind.
    session$setInputs(`config-simulation-n` = 40, `config-simulation-seed` = 12,
      `config-simulation-groups` = 5)
    session$elapse(350)
    expect_equal(fits, 1L)
    session$setInputs(`config-simulation-beta0` = 2L, `config-simulation-sigma` = 1L)
    session$elapse(350)
    expect_equal(fits, 1L)
    session$setInputs(`config-model_type` = "lm_3d")
    expect_true(automatic$pending())
    session$elapse(350)
    expect_identical(coordinator$result()$model_type, "lm_3d")
    expect_equal(fits, 2L)
    session$setInputs(`config-simulation-n` = 41L)
    session$elapse(150)
    session$setInputs(`config-simulation-n` = 42L)
    session$elapse(350)
    expect_equal(nrow(coordinator$result()$data), 42L)
    expect_equal(fits, 3L)
    expect_false(automatic$pending())
    session$setInputs(main_nav_tabs = "brain", `brain-observation_index` = 7L,
      `overview-show_surface` = FALSE)
    session$elapse(350)
    expect_equal(fits, 3L)
  })
})

test_that("automatic fitting waits for the current link and uses the selected real example", {
  expect_true(exists("bind_automatic_analysis")); if (!exists("bind_automatic_analysis")) return()
  fits <- 0L
  counted <- create_analysis_services(fit = function(...) { fits <<- fits + 1L; fit_model(...) })
  shiny::testServer(function(input, output, session) {
    config <- configuration_server("config", root = "..")
    coordinator <- create_app_coordinator(counted, root = "..", logger = function(e) NULL)
    automatic <- bind_automatic_analysis(config, coordinator, delay = 300)
  }, {
    session$setInputs(`config-model_type` = "lm_2d", `config-data_source` = "simulation",
      `config-link_sel` = "identity", `config-simulation-n` = 40L)
    session$elapse(350)
    session$setInputs(`config-model_type` = "glm_gamma", `config-link_sel` = "log")
    session$elapse(350)
    expect_equal(fits, 1L)
    expect_true(automatic$pending())
    session$setInputs(`config-link_sel` = "inverse")
    session$elapse(350)
    expect_equal(fits, 2L)
    expect_identical(coordinator$result()$link, "inverse")
    session$setInputs(`config-data_source` = "real")
    session$elapse(350)
    expect_equal(fits, 2L)
    session$setInputs(`config-link_sel` = "log")
    session$elapse(350)
    expect_equal(fits, 3L)
    expect_equal(nrow(coordinator$result()$data), 270L)
    expect_identical(coordinator$successful_request()$example_id, "forest_fire_positive_area")
    session$setInputs(`config-simulation-n` = 0L)
    session$elapse(350)
    expect_equal(fits, 3L)
  })
})

test_that("invalid automatic requests preserve committed results and recover without running forged code", {
  expect_true(exists("bind_automatic_analysis")); if (!exists("bind_automatic_analysis")) return()
  fits <- 0L
  counted <- create_analysis_services(fit = function(...) { fits <<- fits + 1L; fit_model(...) })
  shiny::testServer(function(input, output, session) {
    config <- configuration_server("config", root = "..")
    coordinator <- create_app_coordinator(counted, root = "..", logger = function(e) NULL)
    automatic <- bind_automatic_analysis(config, coordinator, delay = 300)
  }, {
    session$setInputs(`config-model_type` = "lm_2d", `config-data_source` = "simulation",
      `config-link_sel` = "identity", `config-simulation-n` = 40L)
    session$elapse(350)
    committed <- coordinator$result()
    session$setInputs(`config-simulation-n` = 0L)
    session$elapse(350)
    expect_true(coordinator$stale())
    expect_identical(coordinator$result(), committed)
    expect_equal(fits, 1L)
    expect_match(coordinator$public_error(), "Analysis failed")
    session$setInputs(`config-simulation-n` = 45L, `config-simulation-expert_mode` = TRUE,
      `config-simulation-code` = "stop('FORGED_PRIVATE_CODE')")
    session$elapse(350)
    expect_identical(coordinator$result(), committed)
    expect_equal(fits, 1L)
    expect_false(grepl("FORGED_PRIVATE_CODE", coordinator$public_error(), fixed = TRUE))
    session$setInputs(`config-simulation-expert_mode` = FALSE)
    session$elapse(350)
    expect_equal(fits, 2L)
    expect_equal(nrow(coordinator$result()$data), 45L)
    expect_false(coordinator$stale())
    expect_null(coordinator$public_error())
  })
})
