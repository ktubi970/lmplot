source(file.path("..", "R", "config.R"))
source(file.path("..", "R", "model_registry.R"))
source(file.path("..", "R", "mod_model.R"))
source(file.path("..", "R", "mod_simulation.R"))
source(file.path("..", "R", "mod_model_brain.R"))
source("helper-model-brain.R")

test_that("all 15 model/link cases reproduce R predictions", {
  cases <- model_brain_cases()
  expect_equal(nrow(cases), 15L)

  for (i in seq_len(nrow(cases))) {
    fit_warnings <- character()
    fixture <- withCallingHandlers(
      fit_model_brain_case(cases[i, ]),
      warning = function(warning) {
        fit_warnings <<- c(fit_warnings, conditionMessage(warning))
        invokeRestart("muffleWarning")
      }
    )
    if (length(fit_warnings)) {
      expect_identical(cases$model_type[[i]], "glm_gamma")
      expect_identical(cases$link[[i]], "identity")
      expect_identical(fit_warnings, "glm.fit: algorithm did not converge")
    }
    brain <- build_model_brain(
      fixture$fit, fixture$data, fixture$model_type, fixture$link
    )
    conditional <- Filter(
      function(observation) observation$prediction_mode == "conditional",
      brain$observations
    )
    expected <- as.numeric(predict_response(fixture$fit, fixture$data))
    tolerance <- pmax(1e-10, 1e-8 * abs(expected))
    expected_eta <- if (inherits(fixture$fit, "glm")) {
      as.numeric(stats::predict(fixture$fit, fixture$data, type = "link"))
    } else {
      expected
    }
    eta_tolerance <- pmax(1e-10, 1e-8 * abs(expected_eta))
    actual <- vapply(conditional, `[[`, numeric(1), "prediction")
    reconstructed_eta <- vapply(conditional, function(observation) {
      sum(vapply(observation$contributions, `[[`, numeric(1), "value")) +
        if (isTRUE(observation$random_effect$active)) {
          observation$random_effect$value
        } else {
          0
        }
    }, numeric(1))
    eta <- vapply(conditional, `[[`, numeric(1), "eta")

    expect_length(conditional, nrow(fixture$data))
    expect_true(all(abs(actual - expected) <= tolerance),
      info = paste(fixture$model_type, fixture$link)
    )
    expect_true(all(abs(eta - expected_eta) <= eta_tolerance),
      info = paste(fixture$model_type, fixture$link)
    )
    complete <- all(vapply(
      conditional, `[[`, logical(1), "decomposition_complete"
    ))
    if (complete) {
      expect_true(all(abs(eta - reconstructed_eta) <= tolerance),
        info = paste(fixture$model_type, fixture$link)
      )
    } else {
      expect_identical(fixture$model_type, "glmm")
      expect_false(brain$random_effect_available)
    }
  }
})

test_that("observation records preserve residuals and term arithmetic", {
  fixture <- fit_model_brain_case(data.frame(
    model_type = "glm_gamma", link = "log", stringsAsFactors = FALSE
  ))
  brain <- build_model_brain(
    fixture$fit, fixture$data, fixture$model_type, fixture$link
  )
  conditional <- Filter(
    function(observation) observation$prediction_mode == "conditional",
    brain$observations
  )

  expect_equal(
    vapply(conditional, `[[`, numeric(1), "residual"),
    response_residuals(fixture$fit),
    tolerance = 1e-12
  )
  for (observation in conditional) {
    non_bias <- Filter(
      function(contribution) contribution$term != "(Intercept)",
      observation$contributions
    )
    for (contribution in non_bias) {
      expect_equal(
        contribution$input * contribution$coefficient,
        contribution$value,
        tolerance = 1e-12
      )
    }
  }
})

test_that("observation IDs prefer a valid business ID and otherwise use row numbers", {
  business <- data.frame(
    sample_id = c("sample-b", "sample-a", "sample-c"),
    X = c(1, 2, 3)
  )
  expect_identical(
    model_brain_observation_ids(business),
    business$sample_id
  )
  expect_identical(
    model_brain_observation_ids(transform(business, sample_id = "duplicate")),
    c("1", "2", "3")
  )
  expect_identical(
    model_brain_observation_ids(transform(business, sample_id = c("a", NA, "c"))),
    c("1", "2", "3")
  )

  fit <- stats::lm(Z ~ X, data = data.frame(X = 1:3, Z = c(2, 4, 5)))
  first <- build_model_brain(fit, business |> transform(Z = c(2, 4, 5)), "lm_2d", "identity")
  second <- build_model_brain(fit, business |> transform(Z = c(2, 4, 5)), "lm_2d", "identity")
  first_ids <- vapply(first$observations, `[[`, character(1), "observation_id")
  second_ids <- vapply(second$observations, `[[`, character(1), "observation_id")
  expect_identical(first_ids, second_ids)
  expect_false(anyDuplicated(first_ids) > 0L)
})

test_that("tolerance is scaled without weakening its absolute floor", {
  expected <- c(0, 0.001, -2, 1e8)
  expect_equal(
    model_brain_tolerance(expected),
    pmax(1e-10, 1e-8 * abs(expected))
  )
})

test_that("labels are normalized without inferred units", {
  fixture <- fit_model_brain_case(data.frame(
    model_type = "lm_2d", link = "identity", stringsAsFactors = FALSE
  ))
  brain <- build_model_brain(
    fixture$fit,
    fixture$data,
    fixture$model_type,
    fixture$link,
    labels = list(x = "Flipper length (mm)", z = "Body mass (g)")
  )

  expect_identical(brain$labels$x, "Flipper length (mm)")
  expect_identical(brain$labels$z, "Body mass (g)")
  expect_identical(brain$labels$y, "Y")
  expect_null(brain$labels$units)
})

test_that("lme4 GLMM modes use the fitted random intercept exactly", {
  skip_if_not_installed("lme4")
  fixture <- fit_model_brain_case(data.frame(
    model_type = "glmm", link = "identity", stringsAsFactors = FALSE
  ))
  skip_if_not(inherits(fixture$fit, "merMod"), "fit_model did not select lme4")
  brain <- build_model_brain(
    fixture$fit, fixture$data, fixture$model_type, fixture$link
  )
  conditional <- Filter(
    function(observation) observation$prediction_mode == "conditional",
    brain$observations
  )
  population <- Filter(
    function(observation) observation$prediction_mode == "population",
    brain$observations
  )
  fitted_intercepts <- lme4::ranef(fixture$fit)[[1L]][, "(Intercept)"]
  names(fitted_intercepts) <- rownames(lme4::ranef(fixture$fit)[[1L]])
  expected_random <- unname(fitted_intercepts[as.character(fixture$data$Group)])

  expect_identical(brain$prediction_modes, c("conditional", "population"))
  expect_true(brain$random_effect_available)
  expect_true(brain$decomposition_complete)
  expect_equal(
    vapply(conditional, function(x) x$random_effect$value, numeric(1)),
    expected_random,
    tolerance = 1e-12
  )
  expect_true(all(vapply(conditional, function(x) x$random_effect$active, logical(1))))
  expect_equal(
    vapply(conditional, `[[`, numeric(1), "prediction"),
    as.numeric(predict_response(fixture$fit, fixture$data, population = FALSE)),
    tolerance = 1e-10
  )
  expect_equal(
    vapply(population, `[[`, numeric(1), "prediction"),
    as.numeric(predict_response(fixture$fit, fixture$data, population = TRUE)),
    tolerance = 1e-10
  )
  expect_true(all(vapply(population, function(x) !x$random_effect$active, logical(1))))
  expect_true(all(vapply(population, function(x) x$random_effect$value == 0, logical(1))))
})

test_that("nlme GLMM modes use the fitted random intercept exactly", {
  skip_if_not_installed("nlme")
  data <- simulate_data("glmm", "identity", n = 80L, seed = 77L, groups = 5L)
  data$Group <- factor(data$Group)
  fit <- nlme::lme(Z ~ X + Y, random = ~ 1 | Group, data = data)
  brain <- build_model_brain(fit, data, "glmm", "identity")
  conditional <- Filter(
    function(observation) observation$prediction_mode == "conditional",
    brain$observations
  )
  population <- Filter(
    function(observation) observation$prediction_mode == "population",
    brain$observations
  )
  fitted_intercepts <- nlme::ranef(fit)[, "(Intercept)"]
  names(fitted_intercepts) <- rownames(nlme::ranef(fit))
  expected_random <- unname(fitted_intercepts[as.character(data$Group)])

  expect_identical(brain$prediction_modes, c("conditional", "population"))
  expect_true(brain$random_effect_available)
  expect_true(brain$decomposition_complete)
  expect_equal(
    vapply(conditional, function(x) x$random_effect$value, numeric(1)),
    expected_random,
    tolerance = 1e-12
  )
  expect_equal(
    vapply(conditional, `[[`, numeric(1), "prediction"),
    as.numeric(predict_response(fit, data, population = FALSE)),
    tolerance = 1e-10
  )
  expect_equal(
    vapply(population, `[[`, numeric(1), "prediction"),
    as.numeric(predict_response(fit, data, population = TRUE)),
    tolerance = 1e-10
  )
  expect_true(all(vapply(population, function(x) !x$random_effect$active, logical(1))))
  expect_true(all(vapply(population, function(x) x$random_effect$value == 0, logical(1))))
})

test_that("fixed-factor GLMM fallback exposes only an incomplete conditional mode", {
  data <- simulate_data("glmm", "identity", n = 80L, seed = 91L, groups = 5L)
  data$Group <- factor(data$Group)
  fit <- stats::lm(Z ~ X + Y + Group, data = data)
  brain <- build_model_brain(fit, data, "glmm", "identity")
  conditional <- brain$observations
  expected_warning <- list(
    code = "glmm_random_effect_unavailable",
    scope = "model",
    message = paste(
      "The stats::lm GLMM fallback has no exact random-intercept branch;",
      "only conditional predictions are available and the decomposition is incomplete."
    )
  )

  expect_identical(brain$prediction_modes, "conditional")
  expect_false(brain$random_effect_available)
  expect_false(brain$decomposition_complete)
  expect_identical(brain$warnings, list(expected_warning))
  expect_true(all(vapply(conditional, function(x) !x$random_effect$available, logical(1))))
  expect_true(all(vapply(conditional, function(x) !x$random_effect$active, logical(1))))
  expect_true(all(vapply(conditional, function(x) is.na(x$random_effect$value), logical(1))))
  expect_true(all(!vapply(conditional, `[[`, logical(1), "decomposition_complete")))
  contribution_terms <- unique(unlist(lapply(conditional, function(observation) {
    vapply(observation$contributions, `[[`, character(1), "term")
  })))
  expect_identical(contribution_terms, c("(Intercept)", "X", "Y"))
  expect_equal(
    vapply(conditional, `[[`, numeric(1), "prediction"),
    as.numeric(stats::predict(fit, newdata = data)),
    tolerance = 1e-10
  )
})
