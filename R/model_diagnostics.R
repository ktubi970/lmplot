diagnostic_check <- function(value, explanation, available = all(is.finite(value))) {
  list(value = value, available = available, explanation = explanation)
}

diagnostic_result <- function(strategy, summary, checks, warnings = character()) {
  list(strategy = strategy, status = if (length(warnings)) "warning" else "information",
    summary = summary, checks = checks, warnings = unique(warnings))
}

diagnose_lm <- function(fit, data) {
  residual <- as.numeric(stats::residuals(fit))
  fitted <- as.numeric(stats::fitted(fit))
  frame <- stats::model.frame(fit)
  predictors <- c(list(fitted = fitted), Filter(is.numeric, frame[-1]))
  curvature <- vapply(predictors, function(x) {
    if (length(x) != length(residual) || length(x) < 10L || any(!is.finite(x)) || any(!is.finite(residual))) return(NA_real_)
    auxiliary <- summary(stats::lm(residual ~ x + I(x^2)))$coefficients
    if ("I(x^2)" %in% rownames(auxiliary)) unname(auxiliary["I(x^2)", 4]) else NA_real_
  }, numeric(1))
  spread <- if (length(residual) >= 10L && all(is.finite(c(residual, fitted)))) {
    suppressWarnings(stats::cor(abs(residual), fitted, method = "spearman"))
  } else NA_real_
  warnings <- model_fit_warnings(fit)
  if (any(curvature < .005, na.rm = TRUE)) warnings <- c(warnings, "Exploratory residual curvature detected; inspect functional form and influential observations.")
  if (is.finite(spread) && abs(spread) >= .22) warnings <- c(warnings, "Residual spread varies with fitted values; inspect variance assumptions.")
  diagnostic_result("lm", "Residual checks are exploratory and do not establish model validity.",
    list(curvature_p_values = diagnostic_check(curvature, "Unadjusted exploratory quadratic residual checks; small values suggest inspection."),
      residual_spread_correlation = diagnostic_check(spread, "Spearman correlation of absolute residuals with fitted values.")), warnings)
}

glm_diagnostic_checks <- function(fit) {
  list(pearson_dispersion = diagnostic_check(pearson_residual_dispersion(fit),
      "Sum of squared Pearson residuals divided by residual degrees of freedom; interpretation depends on family, leverage and sample size."),
    convergence_flag = diagnostic_check(fit$converged, "Raw fitting algorithm convergence flag; it is not evidence of model validity.", !is.null(fit$converged)))
}

glm_diagnostic_warnings <- function(fit) {
  warnings <- model_fit_warnings(fit)
  if (identical(fit$converged, FALSE)) warnings <- c(warnings, "GLM fitting algorithm did not converge.")
  warnings
}

diagnose_binomial <- function(fit, data) {
  checks <- glm_diagnostic_checks(fit)
  probabilities <- stats::fitted(fit)
  boundary <- any(probabilities < 1e-8 | probabilities > 1 - 1e-8, na.rm = TRUE)
  checks$boundary_probabilities <- diagnostic_check(boundary, "Extreme fitted probabilities may accompany sparse outcomes or separation.", TRUE)
  warnings <- glm_diagnostic_warnings(fit)
  if (boundary) warnings <- c(warnings, "Near-boundary probabilities; inspect sparse outcomes, separation and coefficient uncertainty.")
  diagnostic_result("binomial", "Inspect calibration and residual patterns; Bernoulli residuals need not be normal. Pearson dispersion is a limited residual diagnostic.", checks, warnings)
}

diagnose_count_gamma <- function(fit, data) {
  checks <- glm_diagnostic_checks(fit)
  checks$family <- list(value = stats::family(fit)$family, available = TRUE,
    explanation = "Poisson fixes model dispersion at one; Gamma estimates dispersion. No universal dispersion threshold establishes fit quality.")
  diagnostic_result("count_gamma", "Inspect response support, mean-variance patterns and Pearson residuals in the fitted family.", checks, glm_diagnostic_warnings(fit))
}

diagnose_glmm <- function(fit, data) {
  optinfo <- fit@optinfo
  codes <- optinfo$conv$opt
  messages <- as.character(optinfo$conv$lme4$messages %||% character())
  messages <- messages[!is.na(messages) & nzchar(messages)]
  singular <- lme4::isSingular(fit, tol = 1e-4)
  code_available <- is.numeric(codes) && length(codes) > 0L && all(is.finite(codes))
  warnings <- c(model_fit_warnings(fit), messages)
  if (code_available && any(codes != 0)) warnings <- c(warnings, paste("Nonzero optimizer code:", paste(codes, collapse = ", ")))
  if (singular) warnings <- c(warnings, "Singular fit: a random-effect variance is at or near its boundary (tolerance 1e-4).")
  diagnostic_result("glmm", "Inspect optimizer information, random-effect boundaries and residuals; absence of warnings does not establish model validity.",
    list(optimizer_code = diagnostic_check(codes, "Raw optimizer code; a missing code leaves convergence unknown.", code_available),
      optimizer_messages = diagnostic_check(messages, "Recorded lme4 convergence messages; absence is not positive convergence evidence.", length(messages) > 0L),
      singular_fit = diagnostic_check(singular, "Boundary check from lme4::isSingular at tolerance 1e-4.", TRUE)), warnings)
}

DIAGNOSTIC_STRATEGIES <- list(lm = diagnose_lm, binomial = diagnose_binomial,
  count_gamma = diagnose_count_gamma, glmm = diagnose_glmm)

diagnose_model <- function(fit, data = NULL, model_type) {
  config <- model_config(model_type)
  key <- if (config$fit_strategy == "glm") {
    if (config$family == "binomial") "binomial" else "count_gamma"
  } else config$fit_strategy
  DIAGNOSTIC_STRATEGIES[[key]](fit, data)
}
