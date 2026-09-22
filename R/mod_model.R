predict_response <- function(fit, newdata = NULL, population = FALSE) {
  if (inherits(fit, "glm")) return(stats::predict(fit, newdata = newdata, type = "response"))
  if (inherits(fit, "merMod")) return(stats::predict(fit, newdata = newdata, re.form = if (population) NA else NULL, allow.new.levels = TRUE))
  if (inherits(fit, "lme")) return(as.numeric(stats::predict(fit, newdata = newdata, level = if (population) 0 else 1)))
  stats::predict(fit, newdata = newdata)
}

fitted_response <- function(fit) as.numeric(predict_response(fit))

response_residuals <- function(fit) {
  observed <- stats::model.response(stats::model.frame(fit))
  as.numeric(observed - fitted_response(fit))
}

format_pval <- function(p) {
  if (is.na(p)) return("N/A")
  if (p < 0.001) return("< 0.001 ***")
  if (p < 0.01) return(sprintf("%.4f **", p))
  if (p < 0.05) return(sprintf("%.4f *", p))
  if (p < 0.10) return(sprintf("%.4f .", p))
  sprintf("%.4f", p)
}

get_pval_sig_class <- function(p) {
  if (is.na(p)) return("sig-ns")
  if (p < 0.001) return("sig-high")
  if (p < 0.01) return("sig-med")
  if (p < 0.05) return("sig-low")
  "sig-ns"
}

model_latex_formula <- function(model_type, link = NULL) {
  link <- validate_model_link(model_type, link)
  key <- paste(model_type, link, sep = ":")
  switch(
    key,
    "lm_2d:identity" = "Z = \\beta_0 + \\beta_1 X + \\epsilon",
    "lm_3d:identity" = "Z = \\beta_0 + \\beta_1 X + \\beta_2 Y + \\epsilon",
    "glm_binomial_2d:logit" = "\\text{logit}(P(Z=1)) = \\beta_0 + \\beta_1 X",
    "glm_binomial_2d:probit" = "\\Phi^{-1}(P(Z=1)) = \\beta_0 + \\beta_1 X",
    "glm_binomial_2d:cloglog" = "\\ln(-\\ln(1 - P(Z=1))) = \\beta_0 + \\beta_1 X",
    "glm_binomial:logit" = "\\text{logit}(P(Z=1)) = \\beta_0 + \\beta_1 X + \\beta_2 Y",
    "glm_binomial:probit" = "\\Phi^{-1}(P(Z=1)) = \\beta_0 + \\beta_1 X + \\beta_2 Y",
    "glm_binomial:cloglog" = "\\ln(-\\ln(1 - P(Z=1))) = \\beta_0 + \\beta_1 X + \\beta_2 Y",
    "glm_poisson:log" = "\\ln(\\lambda) = \\beta_0 + \\beta_1 X + \\beta_2 Y",
    "glm_poisson:identity" = "\\lambda = \\beta_0 + \\beta_1 X + \\beta_2 Y",
    "glm_poisson:sqrt" = "\\sqrt{\\lambda} = \\beta_0 + \\beta_1 X + \\beta_2 Y",
    "glm_gamma:inverse" = "\\frac{1}{\\mu} = \\beta_0 + \\beta_1 X + \\beta_2 Y",
    "glm_gamma:log" = "\\ln(\\mu) = \\beta_0 + \\beta_1 X + \\beta_2 Y",
    "glm_gamma:identity" = "\\mu = \\beta_0 + \\beta_1 X + \\beta_2 Y",
    "glmm:identity" = "Z_{ij} = \\beta_0 + \\beta_1 X_{ij} + \\beta_2 Y_{ij} + u_{j} + \\epsilon_{ij}, \\quad u_j \\sim \\mathcal{N}(0, \\sigma_u^2)",
    stop("Unknown model_type and link combination: ", key, call. = FALSE)
  )
}

# Compatibility presentation adapter for the existing KPI cards.
extract_model_kpis <- function(fit, model_type, metrics = extract_model_metrics(fit, model_type),
                               diagnostics = diagnose_model(fit, model_type = model_type)) {
  config <- model_config(model_type)
  percent <- function(value) if (is.finite(value)) sprintf("%.1f%%", 100 * value) else "N/A"
  number <- function(value) if (is.finite(value)) sprintf("%.3f", value) else "N/A"
  summaries <- list(
    lm = function() list(label = "R²", value = percent(metrics$r_squared),
      sub = paste("Adjusted R²:", percent(metrics$adjusted_r_squared)),
      err_label = "Residual standard error", err = number(stats::sigma(fit)),
      err_sub = "In response units"),
    glm = function() list(label = "Deviance explained", value = percent(metrics$deviance_explained),
      sub = "Reduction relative to null deviance",
      err_label = "Pearson residual dispersion", err = number(metrics$pearson_dispersion),
      err_sub = "Family-dependent residual diagnostic"),
    glmm = function() list(label = "Population prediction correlation²",
      value = percent(metrics$population_prediction_correlation_squared),
      sub = "Observed vs fixed-effect predictions, in sample",
      err_label = "Conditional prediction correlation²",
      err = percent(metrics$conditional_prediction_correlation_squared),
      err_sub = "Observed vs predictions including random effects, in sample")
  )
  fields <- summaries[[config$fit_strategy]]()
  list(
    r2_label = fields$label, r2_value = fields$value, r2_sub = fields$sub,
    r2_status = "DESCRIPTIVE", r2_badge_class = "text-secondary",
    aic_label = "Comparison criteria", aic_value = sprintf("AIC %.1f", metrics$aic),
    aic_sub = sprintf("BIC: %.1f. %s", metrics$bic, COMPARISON_CRITERIA_DESCRIPTION),
    aic_status = "COMPARISON ONLY", aic_badge_class = "text-secondary",
    err_label = fields$err_label, err_value = fields$err, err_sub = fields$err_sub,
    err_status = "DESCRIPTIVE", err_badge_class = "text-secondary",
    health_label = "Sample and diagnostics", health_value = sprintf("N = %d", metrics$sample_size),
    health_sub = diagnostics$summary, health_status = toupper(diagnostics$status),
    health_badge_class = if (diagnostics$status == "warning") "status-warning" else "text-secondary"
  )
}

format_coefficient_table <- function(table) {
  data.frame(Term = table$term, Estimate = sprintf("%.4f", table$estimate),
    StdError = sprintf("%.4f", table$standard_error),
    Statistic = ifelse(is.na(table$statistic), "N/A", sprintf("%.3f", table$statistic)),
    PValue = vapply(table$p_value, format_pval, character(1)),
    CI95 = ifelse(table$interval_available, sprintf("[%.4f, %.4f]", table$conf_low, table$conf_high), "Unavailable"),
    PValueClass = vapply(table$p_value, get_pval_sig_class, character(1)),
    IntervalMethod = table$interval_method, stringsAsFactors = FALSE)
}

# Legacy entry point retained for consumers outside the public Shiny workflow.
diagnose_model_linearity <- function(fit, df = NULL, model_type = "lm_2d") {
  diagnose_model(fit, data = df, model_type = model_type)
}

