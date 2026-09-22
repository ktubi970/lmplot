source(file.path("..", "R", "model_registry.R"))
source(file.path("..", "R", "mod_model.R"))
for (file in c("model_metrics.R", "model_diagnostics.R")) {
  path <- file.path("..", "R", file)
  if (file.exists(path)) source(path)
}

test_that("LM metrics retain neutral numeric comparison values", {
  fit <- stats::lm(mpg ~ wt, mtcars)
  metrics <- extract_model_metrics(fit, "lm_2d", mtcars)
  expect_named(metrics, c("family", "sample_size", "r_squared",
    "adjusted_r_squared", "aic", "bic"))
  expect_equal(metrics$r_squared, summary(fit)$r.squared)
  expect_equal(metrics$adjusted_r_squared, summary(fit)$adj.r.squared)
  expect_equal(metrics$aic, unname(AIC(fit)))
  expect_equal(metrics$bic, unname(BIC(fit)))
  expect_false(any(grepl("optimal|parsim|excellent", unlist(metrics), ignore.case = TRUE)))
})

test_that("GLM metrics use Pearson dispersion and preserve undefined values", {
  fit <- glm(am ~ wt, mtcars, family = binomial())
  metrics <- extract_model_metrics(fit, "glm_binomial", mtcars)
  expect_equal(metrics$deviance_explained, 1 - fit$deviance / fit$null.deviance)
  expect_equal(metrics$pearson_dispersion, sum(residuals(fit, type = "pearson")^2) / fit$df.residual)
  fit$null.deviance <- 0
  fit$df.residual <- 0
  metrics <- extract_model_metrics(fit, "glm_binomial", mtcars)
  expect_identical(metrics$deviance_explained, NA_real_)
  expect_identical(metrics$pearson_dispersion, NA_real_)
  fit$null.deviance <- 1
  fit$deviance <- 2
  expect_identical(extract_model_metrics(fit, "glm_binomial", mtcars)$deviance_explained, -1)
})

test_that("coefficient intervals use LM t limits and GLM labelled Wald limits", {
  fit <- lm(mpg ~ wt, mtcars)
  tab <- extract_coefficient_table(fit, "lm_2d", "identity")
  expect_equal(tab$estimate, unname(coef(fit)))
  expect_equal(tab$conf_low, unname(confint(fit)[, 1]))
  expect_equal(tab$conf_high, unname(confint(fit)[, 2]))
  expect_true(all(tab$interval_available))
  aliased <- lm(mpg ~ wt + I(2 * wt), mtcars)
  alias_tab <- extract_coefficient_table(aliased, "lm_2d", "identity")
  expect_true(is.na(alias_tab$conf_low[3]))
  expect_false(alias_tab$interval_available[3])
  fit <- glm(am ~ wt, mtcars, family = binomial())
  tab <- extract_coefficient_table(fit, "glm_binomial", "logit", level = .9)
  expect_equal(tab$conf_low, unname(confint.default(fit, level = .9)[, 1]))
  expect_match(tab$interval_method[1], "Wald")
})

test_that("LM and GLM intervals target mean responses and preserve rows", {
  fit <- lm(mpg ~ wt, mtcars)
  newdata <- data.frame(wt = c(2, NA, 4))
  interval <- predict_response_interval(fit, newdata, "lm_2d", level = .9)
  reference <- predict(fit, newdata, interval = "confidence", level = .9)
  expect_equal(interval$fit, unname(reference[, "fit"]))
  expect_equal(interval$lower, unname(reference[, "lwr"]))
  expect_equal(interval$upper, unname(reference[, "upr"]))
  expect_match(interval$method, "mean-response")
  for (level in list(0, 1, NA, Inf, c(.9, .95), "95")) {
    expect_error(predict_response_interval(fit, newdata, "lm_2d", level), "level")
  }
  for (family in list(binomial("logit"), binomial("probit"), binomial("cloglog"))) {
    fit <- glm(am ~ wt, mtcars, family = family)
    interval <- predict_response_interval(fit, newdata, "glm_binomial", .9)
    prediction <- predict(fit, newdata, type = "link", se.fit = TRUE)
    expect_equal(interval$lower, unname(family$linkinv(prediction$fit - qnorm(.95) * prediction$se.fit)))
    expect_equal(interval$upper, unname(family$linkinv(prediction$fit + qnorm(.95) * prediction$se.fit)))
    expect_length(interval$fit, 3)
    expect_true(all(interval$lower >= 0 & interval$upper <= 1, na.rm = TRUE))
  }
})

test_that("inverse and sqrt link intervals cannot reverse bounds or cross a branch silently", {
  fit <- glm(mpg ~ wt, mtcars, family = Gamma("inverse"))
  interval <- predict_response_interval(fit, mtcars, "glm_gamma")
  pred <- predict(fit, mtcars, type = "link", se.fit = TRUE)
  expect_equal(interval$lower, unname(1 / (pred$fit + qnorm(.975) * pred$se.fit)))
  expect_equal(interval$upper, unname(1 / (pred$fit - qnorm(.975) * pred$se.fit)))
  distant <- predict_response_interval(fit, data.frame(wt = -2), "glm_gamma")
  expect_false(distant$interval_available)
  expect_true(is.na(distant$lower))
})

test_that("GLMM correlations separate population and conditional predictions", {
  skip_if_not_installed("lme4")
  fit <- lme4::lmer(Reaction ~ Days + (1 | Subject), lme4::sleepstudy)
  metrics <- extract_model_metrics(fit, "glmm", lme4::sleepstudy)
  y <- lme4::sleepstudy$Reaction
  expect_equal(metrics$population_prediction_correlation_squared, unname(cor(y, predict(fit, re.form = NA))^2))
  expect_equal(metrics$conditional_prediction_correlation_squared, unname(cor(y, predict(fit, re.form = NULL))^2))
  expect_false(any(c("marginal_r_squared", "conditional_r_squared") %in% names(metrics)))
  expect_identical(squared_prediction_correlation(rep(1, 3), 1:3), NA_real_)
  expect_identical(predict_response_interval(fit, lme4::sleepstudy, "glmm"),
    list(available = FALSE, level = .95, reason = "Response-scale intervals are unavailable for this GLMM."))
  expect_false(any(extract_coefficient_table(fit, "glmm", "identity")$interval_available))
})

test_that("family diagnostic strategies return information without validity verdicts", {
  expect_named(DIAGNOSTIC_STRATEGIES, c("lm", "binomial", "count_gamma", "glmm"))
  fits <- list(lm(mpg ~ wt, mtcars), glm(am ~ wt, mtcars, family = binomial()),
    glm(cyl ~ wt, mtcars, family = poisson()), glm(mpg ~ wt, mtcars, family = Gamma("log")))
  ids <- c("lm_2d", "glm_binomial", "glm_poisson", "glm_gamma")
  expected <- c("lm", "binomial", "count_gamma", "count_gamma")
  for (i in seq_along(fits)) {
    diagnostic <- diagnose_model(fits[[i]], mtcars, ids[i])
    expect_named(diagnostic, c("strategy", "status", "summary", "checks", "warnings"))
    expect_identical(diagnostic$strategy, expected[i])
    expect_false(any(grepl("adequate|valid model|successful|converged.*OK", unlist(diagnostic), ignore.case = TRUE)))
  }
})

test_that("GLMM diagnostics expose optimizer messages singularity and unknown codes", {
  skip_if_not_installed("lme4")
  fit <- lme4::lmer(Reaction ~ Days + (1 | Subject), lme4::sleepstudy)
  fit@optinfo$conv$opt <- 7L
  fit@optinfo$conv$lme4$messages <- "fixture convergence warning"
  diagnostic <- diagnose_model(fit, lme4::sleepstudy, "glmm")
  expect_identical(diagnostic$status, "warning")
  expect_match(paste(diagnostic$warnings, collapse = " "), "7.*|fixture convergence warning")
  expect_true(any(grepl("fixture convergence warning", diagnostic$warnings)))
  balanced <- expand.grid(Days = 0:9, Subject = factor(1:8))
  balanced$Reaction <- 10 + balanced$Days + rep(c(-1, 1), 40)
  fit <- suppressMessages(lme4::lmer(Reaction ~ Days + (1 | Subject), balanced))
  expect_true(lme4::isSingular(fit))
  diagnostic <- diagnose_model(fit, lme4::sleepstudy, "glmm")
  expect_true(any(grepl("singular", diagnostic$warnings, ignore.case = TRUE)))
  expect_false(any(grepl("success|converged.*OK", unlist(diagnostic), ignore.case = TRUE)))
  fit@optinfo$conv$opt <- NULL
  expect_false(diagnose_model(fit, lme4::sleepstudy, "glmm")$checks$optimizer_code$available)
})
