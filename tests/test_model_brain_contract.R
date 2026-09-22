library(testthat)
app_root <- if (file.exists('../R/config.R')) '..' else '.'
for (file in c('config.R', 'model_registry.R', 'mod_model.R', 'model_metrics.R',
  'model_diagnostics.R', 'mod_simulation.R', 'mod_visualization.R', 'mod_examples.R',
  'mod_model_brain.R', 'mod_pipeline.R')) source(file.path(app_root, 'R', file), local = TRUE)
source('helper-model-brain.R')

brain_fixture <- function(model = 'lm_3d', link = 'identity', n = 80L) {
  fit_model_brain_case(data.frame(model_type = model, link = link), n = n)
}
fixture_brain <- function(f = brain_fixture(), ...) {
  build_model_brain(f$fit, f$data, f$model_type, f$link, ...)
}

test_that('all registry cases produce complete valid contracts and exact intervals', {
  cases <- model_brain_cases()
  expect_equal(nrow(cases), 15L)
  for (i in seq_len(nrow(cases))) {
    f <- suppressWarnings(fit_model_brain_case(cases[i, ]))
    b <- fixture_brain(f)
    expect_named(b, c('schema_version', 'model_type', 'family', 'link', 'formula',
      'labels', 'units', 'n', 'prediction_modes', 'default_observation_id', 'topology',
      'coefficients', 'observations', 'link_curve', 'global_summaries', 'warnings'))
    expect_identical(validate_model_brain(b), b)
    co <- extract_coefficient_table(f$fit, f$model_type, f$link)
    ri <- predict_response_interval(f$fit, f$data, f$model_type)
    for (j in seq_len(nrow(co))) {
      expect_equal(b$coefficients[[j]]$estimate, co$estimate[j])
      expect_equal(b$coefficients[[j]]$standard_error, co$standard_error[j])
      expect_identical(b$coefficients[[j]]$interval$available, co$interval_available[j])
      if (co$interval_available[j]) {
        expect_equal(b$coefficients[[j]]$interval$lower, co$conf_low[j])
        expect_equal(b$coefficients[[j]]$interval$upper, co$conf_high[j])
      }
    }
    for (mode in b$prediction_modes) {
      obs <- Filter(function(x) x$prediction_mode == mode, b$observations)
      expect_equal(vapply(obs, `[[`, numeric(1), 'index'), seq_len(nrow(f$data)))
      expected <- as.numeric(predict_response(f$fit, f$data, population = mode == 'population'))
      expect_equal(vapply(obs, `[[`, numeric(1), 'prediction'), expected, tolerance = 1e-10)
      for (j in seq_along(obs)) {
        o <- obs[[j]]
        expect_equal(o$eta, sum(vapply(o$contributions, `[[`, numeric(1), 'value')) + o$random_effect$value,
          tolerance = 1e-10)
        inverse <- if (inherits(f$fit, 'glm')) family(f$fit)$linkinv else identity
        expect_equal(o$prediction, as.numeric(inverse(o$eta)), tolerance = 1e-10)
        expect_equal(o$residual, o$observed - o$prediction)
        available <- isTRUE(ri$available) && isTRUE(ri$interval_available[j])
        expect_identical(o$response_interval$available, available)
        if (available) {
          expect_equal(o$response_interval$lower, ri$lower[j])
          expect_equal(o$response_interval$upper, ri$upper[j])
        } else {
          expect_null(o$response_interval$lower)
          expect_null(o$response_interval$upper)
          expect_true(nzchar(o$response_interval$reason))
        }
      }
    }
  }
})

test_that('schema and arithmetic mutations cannot be accepted or sanitized', {
  b <- fixture_brain()
  mutations <- list(
    function(x) { x$schema_version <- 'model-brain/2'; x },
    function(x) { x$model_type <- 'glm_poisson'; x },
    function(x) { x$family <- 'Gamma'; x },
    function(x) { x$formula <- 'Z ~ X'; x },
    function(x) { x$n <- x$n + 1; x },
    function(x) { x$observations[[1]]$index <- 0; x },
    function(x) { x$observations[[1]]$eta <- 99; x },
    function(x) { x$observations[[1]]$prediction <- 99; x },
    function(x) { x$observations[[1]]$residual <- 99; x },
    function(x) { x$observations[[1]]$contributions[[1]]$input <- 2; x },
    function(x) { x$observations[[1]]$contributions <- rev(x$observations[[1]]$contributions); x },
    function(x) { x$topology$nodes <- rev(x$topology$nodes); x },
    function(x) { x$topology$edges[[1]]$target <- 'unknown'; x },
    function(x) { x$topology$nodes[[1]]$role <- 'observed'; x },
    function(x) { x$observations[[1]]$response_interval$lower <- 1e9; x },
    function(x) { x$coefficients[[1]]$interval$level <- 1; x },
    function(x) { x$default_observation_id <- 'unknown'; x },
    function(x) { x$link_curve$prediction[1] <- 99; x },
    function(x) { x$global_summaries$contributions$min <- 99; x })
  for (mutate in mutations) expect_error(validate_model_brain(mutate(b)), 'Model Brain')
  paths <- list(character(), 'labels', 'units', 'topology', c('topology','nodes',1),
    c('topology','edges',1), c('coefficients',1), c('coefficients',1,'interval'),
    c('observations',1), c('observations',1,'inputs'), c('observations',1,'contributions',1),
    c('observations',1,'random_effect'), c('observations',1,'response_interval'),
    'link_curve', 'global_summaries', c('global_summaries','coefficients'))
  change_at <- function(x, path, fn) {
    if (!length(path)) return(fn(x))
    key <- path[1]; if (grepl('^[0-9]+$', key)) key <- as.integer(key)
    x[[key]] <- change_at(x[[key]], path[-1], fn); x
  }
  for (path in paths) expect_error(validate_model_brain(change_at(b, path,
    function(x) { x$unknown <- TRUE; x })), 'Model Brain')
  for (bad in list(NA_real_, NaN, Inf, -Inf)) {
    for (path in list(c('coefficients',1,'estimate'), c('observations',1,'inputs','X'),
      c('observations',1,'contributions',1,'value'), c('observations',1,'random_effect','value'),
      c('observations',1,'eta'), c('observations',1,'prediction'), c('observations',1,'observed'),
      c('observations',1,'residual'), c('link_curve','eta'),
      c('global_summaries','coefficients','sample'))) {
      expect_error(validate_model_brain(change_at(b, path, function(x) bad)), 'Model Brain')
    }
  }
})

test_that('selection is a strict pure lookup and default is the median conditional prediction', {
  f <- brain_fixture(); f$data$sample_id <- paste0('id-', rev(seq_len(nrow(f$data))))
  b <- fixture_brain(f)
  ids <- vapply(b$observations, `[[`, character(1), 'observation_id')
  pred <- vapply(b$observations, `[[`, numeric(1), 'prediction')
  expect_identical(b$default_observation_id, ids[order(pred, ids)[ceiling(length(ids)/2)]])
  expect_identical(select_model_brain_observation(b, 2), b$observations[[2]])
  for (bad in list(0, b$n + 1, 1.5, NA, Inf, '1', numeric())) {
    expect_error(select_model_brain_observation(b, bad), 'Model Brain')
  }
  expect_error(select_model_brain_observation(b, 1, 'population'), 'Model Brain')
  expect_identical(fixture_brain(f, prediction_mode = 'conditional'), b)
  expect_error(fixture_brain(f, prediction_mode = 'population'), 'Model Brain')
})

test_that('record collections cannot become keyed objects and scalar values cannot be matrices', {
  b <- fixture_brain(warnings = 'test warning')
  for (field in c('observations','coefficients','warnings')) {
    bad <- b; names(bad[[field]]) <- paste0('key',seq_along(bad[[field]]))
    expect_error(validate_model_brain(bad), 'Model Brain')
  }
  bad <- b; names(bad$observations[[1]]$contributions) <- c('a','b','c')
  expect_error(validate_model_brain(bad), 'Model Brain')
  bad <- b; bad$warnings[[1]]$unknown <- 'extra'
  expect_error(validate_model_brain(bad), 'Model Brain')
  bad <- b; bad$observations[[1]]$index <- matrix(1)
  expect_error(validate_model_brain(bad), 'Model Brain')
  expect_error(select_model_brain_observation(b, matrix(1)), 'Model Brain')
  bad <- b; bad$observations[[1]]$response_interval$available <- matrix(TRUE)
  expect_error(validate_model_brain(bad), 'Model Brain')
  bad <- b; bad$labels$group <- matrix('Group')
  expect_error(validate_model_brain(bad), 'Model Brain')
})

test_that('builder rejects changed fitted rows and invalid label or mode requests', {
  f <- brain_fixture()
  bad <- f; bad$data$Z[1] <- bad$data$Z[1] + 1
  expect_error(fixture_brain(bad), 'Model Brain')
  bad <- f; bad$data$X[1] <- bad$data$X[1] + 1
  expect_error(fixture_brain(bad), 'Model Brain')
  for (mode in list(NA_character_, c('conditional','population'), 1, 'unknown')) {
    expect_error(fixture_brain(f, prediction_mode = mode), 'Model Brain')
  }
  expect_error(fixture_brain(f, labels = list(x='X', unknown='extra')), 'Model Brain')
  expect_error(fixture_brain(f, labels = list(x='X', x='duplicate')), 'Model Brain')
  expect_error(fixture_brain(f, labels = list(unknown=NULL)), 'Model Brain')
})

test_that('link curve values must remain plain numeric vectors for JSON arrays', {
  b <- fixture_brain()
  for (field in c('eta','prediction')) {
    for (reshape in list(function(x) matrix(x, ncol = 1),
      function(x) array(x, dim = c(length(x), 1, 1)),
      function(x) setNames(x, paste0('point', seq_along(x))),
      function(x) structure(x, class = 'numeric_curve'))) {
      bad <- b; bad$link_curve[[field]] <- reshape(bad$link_curve[[field]])
      expect_error(validate_model_brain(bad), 'Model Brain')
    }
  }
})

test_that('GLMM source groups match fitted rows independently of factor levels', {
  skip_if_not_installed('lme4')
  f <- brain_fixture('glmm')
  b <- fixture_brain(f)
  reordered_levels <- f
  reordered_levels$data$Group <- factor(as.character(f$data$Group),
    levels = rev(unique(as.character(f$data$Group))))
  expect_identical(fixture_brain(reordered_levels), b)
  changed <- f; changed$data$Group <- rev(changed$data$Group)
  delta <- max(abs(predict_response(f$fit, f$data) - predict_response(f$fit, changed$data)))
  expect_gt(delta, 1e-6)
  expect_error(fixture_brain(changed), 'Model Brain')
})

test_that('GLMM group summary ordering is independent of factor level order', {
  skip_if_not_installed('lme4')
  f <- brain_fixture('glmm')
  f$data$Group <- factor(f$data$Group, levels = rev(unique(as.character(f$data$Group))))
  f$fit <- fit_model(f$data, 'glmm', 'identity')
  b <- fixture_brain(f)
  expect_identical(validate_model_brain(b), b)
  effects <- lme4::ranef(f$fit)[[1]]
  expect_equal(b$global_summaries$random_effects$sample,
    unname(effects[order(rownames(effects), method = 'radix'), '(Intercept)']))
})

test_that('GLMM always contains both modes and rejects legacy fits and malformed pairs', {
  skip_if_not_installed('lme4')
  f <- brain_fixture('glmm'); b <- fixture_brain(f)
  expect_identical(fixture_brain(f, prediction_mode = 'population'), b)
  expect_identical(b$prediction_modes, c('conditional','population'))
  re <- lme4::ranef(f$fit)[[1]]
  for (i in seq_len(b$n)) {
    c <- select_model_brain_observation(b, i, 'conditional')
    p <- select_model_brain_observation(b, i, 'population')
    expect_identical(c$contributions, p$contributions)
    expect_equal(c$random_effect$value, re[as.character(f$data$Group[i]), '(Intercept)'])
    expect_true(c$random_effect$active); expect_true(c$random_effect$available)
    expect_false(p$random_effect$active); expect_equal(p$random_effect$value, 0)
    expect_identical(c$response_interval, list(available = FALSE, level = .95,
      lower = NULL, upper = NULL, reason = 'Response-scale intervals are unavailable for this GLMM.', method = NULL))
  }
  bad <- b; bad$observations <- bad$observations[-1]
  expect_error(validate_model_brain(bad), 'Model Brain')
  bad <- b; bad$observations[[b$n+1]]$random_effect$active <- TRUE
  expect_error(validate_model_brain(bad), 'Model Brain')
  expect_error(build_model_brain(lm(Z ~ X + Y + Group, f$data), f$data, 'glmm', 'identity'), 'merMod')
})

test_that('analysis builds and validates exactly once and navigation never refits', {
  fits <- builds <- validations <- 0L
  services <- create_analysis_services(fit = function(...) { fits <<- fits+1L; fit_model(...) },
    build_model_brain = function(...) { builds <<- builds+1L; build_model_brain(...) },
    validate_model_brain = function(brain) { validations <<- validations+1L; validate_model_brain(brain) })
  request <- new_analysis_request(list(schema_version = 'lmplot-analysis-request/1.0',
    data_source = 'simulation', model_type = 'lm_3d'))
  r <- run_analysis_usecase(request, services, app_root)
  expect_identical(c(fits, builds, validations), c(1L,1L,1L))
  for (i in 1:20) expect_identical(select_model_brain_observation(r$model_brain, i), r$model_brain$observations[[i]])
  expect_identical(c(fits, builds, validations), c(1L,1L,1L))
  expect_error(create_analysis_services(validate_model_brain = NULL), 'callable')
  if (requireNamespace('lme4', quietly = TRUE)) {
    mixed <- new_analysis_request(list(schema_version = 'lmplot-analysis-request/1.0',
      data_source = 'simulation', model_type = 'glmm'))
    result <- run_analysis_usecase(mixed, services, app_root)
    for (mode in c('conditional','population')) for (i in 1:10) {
      selected <- select_model_brain_observation(result$model_brain, i, mode)
      expect_identical(selected$prediction_mode, mode)
      expect_equal(selected$index, i)
    }
    expect_identical(c(fits, builds, validations), c(2L,2L,2L))
  }
  services$validate_model_brain <- function(brain) stop('validator rejected')
  expect_error(run_analysis_usecase(request, services, app_root), 'validator rejected')
})

test_that('warnings are ordered records and the 5000-row contract stays within budget', {
  f <- brain_fixture(n = 5000L)
  elapsed <- system.time(b <- fixture_brain(f, warnings = c('first', 'first', 'second')))[['elapsed']]
  bytes <- as.numeric(object.size(b))
  cat(sprintf('\nMODEL_BRAIN_BUDGET elapsed=%.3f seconds bytes=%d\n', elapsed, bytes))
  expect_identical(b$warnings, list(list(code='analysis_warning', scope='analysis', message='first'),
    list(code='analysis_warning', scope='analysis', message='second')))
  expect_length(b$observations, 5000)
  expect_identical(validate_model_brain(b), b)
  expect_lt(elapsed, 2); expect_lt(bytes, 40 * 1024^2)
})
