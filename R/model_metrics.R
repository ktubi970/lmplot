# Numeric assessment services. Presentation and scientific interpretation live elsewhere.
COMPARISON_CRITERIA_DESCRIPTION <- paste(
  "AIC and BIC are comparison criteria for candidates fitted to the same response,",
  "observations, weights, offsets and likelihood convention; lower values order",
  "compatible candidates. Compare different mixed-model fixed effects using ML, not REML."
)

validate_interval_level <- function(level) {
  if (!is.numeric(level) || length(level) != 1L || !is.finite(level) || level <= 0 || level >= 1) {
    stop("level must be a finite number strictly between zero and one", call. = FALSE)
  }
  invisible(level)
}

squared_prediction_correlation <- function(observed, predicted) {
  keep <- is.finite(observed) & is.finite(predicted)
  if (sum(keep) < 2L) return(NA_real_)
  value <- suppressWarnings(stats::cor(observed[keep], predicted[keep]))
  if (is.finite(value)) unname(value^2) else NA_real_
}

pearson_residual_dispersion <- function(fit) {
  pearson <- stats::residuals(fit, type = "pearson")
  df <- stats::df.residual(fit)
  if (length(df) == 1L && is.finite(df) && df > 0 && all(is.finite(pearson))) sum(pearson^2) / df else NA_real_
}

lm_metrics <- function(fit, data) {
  s <- summary(fit)
  list(r_squared = unname(s$r.squared), adjusted_r_squared = unname(s$adj.r.squared))
}

glm_metrics <- function(fit, data) {
  null <- fit$null.deviance
  residual <- fit$deviance
  explained <- if (length(null) == 1L && is.finite(null) && null > 0 && is.finite(residual)) {
    1 - residual / null
  } else NA_real_
  list(deviance_explained = unname(explained), pearson_dispersion = pearson_residual_dispersion(fit))
}

glmm_metrics <- function(fit, data) {
  observed <- stats::model.response(stats::model.frame(fit))
  list(
    population_prediction_correlation_squared = squared_prediction_correlation(observed, stats::predict(fit, re.form = NA)),
    conditional_prediction_correlation_squared = squared_prediction_correlation(observed, stats::predict(fit, re.form = NULL))
  )
}

METRIC_STRATEGIES <- list(lm = lm_metrics, glm = glm_metrics, glmm = glmm_metrics)

extract_model_metrics <- function(fit, model_type, data = NULL) {
  config <- model_config(model_type)
  metrics <- c(list(family = config$family, sample_size = unname(stats::nobs(fit))),
    METRIC_STRATEGIES[[config$fit_strategy]](fit, data),
    list(aic = tryCatch(unname(stats::AIC(fit)), error = function(e) NA_real_),
         bic = tryCatch(unname(stats::BIC(fit)), error = function(e) NA_real_)))
  attr(metrics, "comparison_description") <- COMPARISON_CRITERIA_DESCRIPTION
  metrics
}

extract_coefficient_table <- function(fit, model_type = NULL, link = NULL, level = .95) {
  validate_interval_level(level)
  estimates <- if (inherits(fit, "merMod")) lme4::fixef(fit, add.dropped = TRUE) else stats::coef(fit)
  terms <- names(estimates)
  coefs <- summary(fit)$coefficients
  rows <- match(terms, rownames(coefs))
  ci <- matrix(NA_real_, length(terms), 2L, dimnames = list(terms, NULL))
  method <- "Unavailable for this model"
  if (inherits(fit, "glm")) {
    ci <- stats::confint.default(fit, level = level)[terms, , drop = FALSE]
    method <- "Approximate link-scale Wald confidence interval"
  } else if (inherits(fit, "lm")) {
    ci <- stats::confint(fit, level = level)[terms, , drop = FALSE]
    method <- "Student t coefficient confidence interval"
  }
  data.frame(term = terms, estimate = unname(estimates), standard_error = unname(coefs[rows, 2]),
    statistic = unname(coefs[rows, 3]),
    p_value = if (ncol(coefs) >= 4L) unname(coefs[rows, 4]) else rep(NA_real_, length(terms)),
    conf_low = unname(ci[, 1]), conf_high = unname(ci[, 2]),
    interval_available = is.finite(ci[, 1]) & is.finite(ci[, 2]),
    interval_method = method, stringsAsFactors = FALSE)
}

lm_response_interval <- function(fit, newdata, level) {
  pred <- stats::predict(fit, newdata = newdata, interval = "confidence", level = level, na.action = stats::na.pass)
  list(available = TRUE, level = level, fit = unname(pred[, "fit"]),
    lower = unname(pred[, "lwr"]), upper = unname(pred[, "upr"]),
    interval_available = is.finite(pred[, "lwr"]) & is.finite(pred[, "upr"]),
    method = "Student t mean-response confidence interval")
}

glm_response_interval <- function(fit, newdata, level) {
  pred <- stats::predict(fit, newdata = newdata, type = "link", se.fit = TRUE, na.action = stats::na.pass)
  family <- stats::family(fit)
  z <- stats::qnorm((1 + level) / 2)
  eta_low <- pred$fit - z * pred$se.fit
  eta_high <- pred$fit + z * pred$se.fit
  low <- family$linkinv(eta_low)
  high <- family$linkinv(eta_high)
  valid <- is.finite(low) & is.finite(high)
  # Inverse and square-root means require the positive branch throughout.
  if (family$link %in% c("inverse", "sqrt")) valid <- valid & !is.na(eta_low) & eta_low > 0
  lower <- ifelse(valid, pmin(low, high), NA_real_)
  upper <- ifelse(valid, pmax(low, high), NA_real_)
  list(available = TRUE, level = level, fit = as.numeric(family$linkinv(pred$fit)),
    lower = as.numeric(lower), upper = as.numeric(upper), interval_available = unname(valid),
    method = "Wald mean-response confidence interval transformed from the link scale",
    reason = "Rows crossing an inverse-link domain boundary or with non-finite limits have unavailable intervals.")
}

glmm_response_interval <- function(fit, newdata, level) {
  list(available = FALSE, level = level, reason = "Response-scale intervals are unavailable for this GLMM.")
}

RESPONSE_INTERVAL_STRATEGIES <- list(lm = lm_response_interval, glm = glm_response_interval, glmm = glmm_response_interval)

predict_response_interval <- function(fit, newdata, model_type, level = .95) {
  validate_interval_level(level)
  strategy <- model_config(model_type)$fit_strategy
  RESPONSE_INTERVAL_STRATEGIES[[strategy]](fit, newdata, level)
}
