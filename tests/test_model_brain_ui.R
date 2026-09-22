source(file.path('..', 'app.R'), local = TRUE)

test_that('chart CSV retains double precision and explicit missing numeric values', {
  expect_true(exists('write_chart_csv')); if (!exists('write_chart_csv')) return()
  path <- tempfile(fileext = '.csv'); on.exit(unlink(path))
  values <- data.frame(value = c(1.0000000000000002, 1.2345678901234567, NA_real_),
    interval_available = c(TRUE, TRUE, FALSE), reason = c('', '', 'unavailable'))
  write_chart_csv(values, path)
  expect_identical(read.csv(path)$value, values$value)
  expect_identical(read.csv(path)$interval_available, values$interval_available)
})

brain_fixture <- function(model = 'lm_2d', link = NULL) {
  run_analysis_usecase(new_analysis_request(list(schema_version = 'lmplot-analysis-request/1.0',
    data_source = 'simulation', model_type = model, link = link,
    simulation = list(n = 40L, seed = 12L))), create_analysis_services(), root = '..')
}

test_that('Brain renderers preserve stored contributions, intervals and curve samples', {
  expect_true(exists('brain_view_data')); if (!exists('brain_view_data')) return()
  value <- brain_fixture('glm_binomial_2d', 'probit')
  brain <- value$model_brain; o <- brain$observations[[3]]
  view <- brain_view_data(brain, 3L)
  eq <- exact_equation_view(view); waterfall <- contribution_waterfall(view)
  expect_equal(eq$table$value[eq$table$role == 'prediction'], o$prediction)
  expect_equal(waterfall$table$value, c(vapply(o$contributions, `[[`, numeric(1), 'value'), o$eta))
  expect_equal(tail(waterfall$table$end, 1), o$eta)
  expect_true(all(c('positive', 'negative', 'zero', 'total')[match(waterfall$table$status,
    c('positive', 'negative', 'zero', 'total'))] == waterfall$table$status))
  curve <- link_transformation_plot(view)
  expect_equal(curve$table$eta[-nrow(curve$table)], brain$link_curve$eta)
  expect_equal(tail(curve$table$prediction, 1), o$prediction)
  coefficients <- coefficient_overview_plot(view)
  expect_equal(coefficients$table$lower, vapply(brain$coefficients, function(x) x$interval$lower, numeric(1)))
  for (bundle in list(eq, waterfall, curve, coefficients)) {
    expect_named(bundle, c('plot', 'summary', 'table', 'units', 'n', 'uncertainty'))
    expect_equal(bundle$n, 40L); expect_match(bundle$summary, 'N = 40')
    expect_true(is.data.frame(bundle$table)); expect_true(nzchar(bundle$uncertainty))
  }
})

test_that('GLMM group alternatives retain every group and mark population effects inactive', {
  expect_true(exists('brain_view_data')); if (!exists('brain_view_data')) return()
  brain <- brain_fixture('glmm')$model_brain
  conditional <- brain_view_data(brain, 2L); population <- brain_view_data(brain, 2L, 'population')
  random <- random_effect_plot(population)
  expect_equal(nrow(random$table), length(unique(as.character(brain_fixture('glmm')$data$Group))))
  expect_equal(sum(random$table$count), brain$n)
  expect_false(any(random$table$active)); expect_equal(sum(random$table$selected), 1L)
  expect_match(random$summary, 'inactive'); expect_match(random$uncertainty, 'unavailable')
  expect_equal(population$observation$random_effect$value, 0)
  expect_equal(conditional$observation$index, population$observation$index)
})

test_that('all supported Brain renderers need no scientific recomputation', {
  pairs <- do.call(rbind, lapply(names(MODEL_REGISTRY), function(id) data.frame(model_type = id, link = MODEL_REGISTRY[[id]]$links)))
  fixtures <- lapply(seq_len(nrow(pairs)), function(i) {
    pair <- pairs[i, ]; brain_fixture(pair$model_type, pair$link)$model_brain
  })
  forbidden <- function(...) stop('Scientific recomputation during presentation')
  env <- environment(brain_view_data)
  names <- c('fit_model', 'predict_response', 'predict_response_interval', 'build_model_brain',
    'validate_model_brain', 'diagnose_model', 'extract_model_metrics', 'run_analysis_usecase')
  originals <- mget(names, envir = env)
  withr::defer(list2env(originals, envir = env))
  list2env(setNames(rep(list(forbidden), length(names)), names), envir = env)
  for (brain in fixtures) {
    view <- brain_view_data(brain, 3L)
    for (render in list(exact_equation_view, contribution_waterfall, link_transformation_plot, coefficient_overview_plot, random_effect_plot)) {
      bundle <- render(view)
      expect_equal(bundle$n, 40L)
      if (!is.null(bundle$plot)) expect_s3_class(plotly::plotly_build(bundle$plot), 'plotly')
    }
  }
})

test_that('selection is shared, generation guarded and navigation never recomputes analysis', {
  expect_true(exists('model_brain_server')); if (!exists('model_brain_server')) return()
  calls <- 0L
  builds <- 0L; validations <- 0L
  counted <- create_analysis_services(fit = function(...) { calls <<- calls + 1L; fit_model(...) },
    build_model_brain = function(...) { builds <<- builds + 1L; build_model_brain(...) },
    validate_model_brain = function(...) { validations <<- validations + 1L; validate_model_brain(...) })
  shiny::testServer(function(input, output, session) {
    coordinator <- create_app_coordinator(counted, root = '..')
    overview <- overview_server('overview', coordinator$result, coordinator$generation)
    brain <- model_brain_server('brain', coordinator$result, coordinator$generation,
      overview$selection, overview$select_observation)
  }, {
    session$flushReact(); expect_null(brain$selected_observation())
    payload <- list(schema_version = 'lmplot-analysis-request/1.0', data_source = 'simulation',
      model_type = 'lm_2d', simulation = list(n = 40L, seed = 12L))
    coordinator$analyze(payload); session$flushReact()
    expect_equal(brain$selected_observation()$observation_id, coordinator$result()$model_brain$default_observation_id)
    session$setInputs(`brain-observation_index` = 1)
    session$setInputs(`brain-previous` = 1); expect_equal(brain$selected_index(), 40)
    session$setInputs(`brain-next` = 1); expect_equal(brain$selected_index(), 1)
    session$setInputs(`brain-observation_index` = 1.5); expect_equal(brain$selected_index(), 1)
    expect_match(output$`brain-index_error`, 'whole number')
    session$setInputs(`overview-observation_selection` = list(observation_id = '7', generation = 1))
    expect_equal(brain$selected_index(), 7)
    expect_equal(overview$selection()$observation_id, '7')
    for (event in list(list(observation_id = '8', generation = 0), list(pointNumber = 8),
        list(observation_id = 'missing', generation = 1))) {
      session$setInputs(`overview-observation_selection` = event)
      expect_equal(brain$selected_index(), 7)
    }
    csv <- read.csv(output$`brain-equation_download`)
    expect_true(all(csv$observation_id == '7')); expect_equal(calls, 1L)
    expect_equal(c(builds, validations), c(1L, 1L))
    capture.output(coordinator$analyze(stop('deliberate failed replacement')), type = 'message')
    session$flushReact(); expect_equal(brain$selected_index(), 7)
    expect_identical(read.csv(output$`brain-equation_download`), csv)
    payload$simulation$n <- 30L
    coordinator$analyze(payload); session$flushReact()
    expect_equal(brain$selected_observation()$observation_id, coordinator$result()$model_brain$default_observation_id)
    expect_equal(calls, 2L)
  })
})

test_that('GLMM mode changes preserve source identity and select stored mode values', {
  value <- brain_fixture('glmm')
  shiny::testServer(function(input, output, session) {
    result <- shiny::reactive(value); generation <- shiny::reactive(1L)
    overview <- overview_server('overview', result, generation)
    brain <- model_brain_server('brain', result, generation, overview$selection, overview$select_observation)
  }, {
    session$flushReact()
    session$setInputs(`brain-observation_index` = 7L)
    session$setInputs(`brain-prediction_mode` = 'population')
    expect_equal(brain$selected_index(), 7L)
    expect_identical(brain$selected_observation(), value$model_brain$observations[[47L]])
    table <- read.csv(output$`brain-random_download`)
    expect_false(any(table$active)); expect_true(all(table$prediction_mode == 'population'))
    session$setInputs(`brain-prediction_mode` = 'forged')
    expect_equal(brain$selected_mode(), 'population')
  })
})
