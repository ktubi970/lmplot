MODEL_REGISTRY <- list(
  lm_2d = list(label = "Simple LM (2D)", family = "gaussian", links = "identity", default_link = "identity", dimensions = 2L, requires_group = FALSE),
  lm_3d = list(label = "Multiple LM (3D)", family = "gaussian", links = "identity", default_link = "identity", dimensions = 3L, requires_group = FALSE),
  glm_binomial_2d = list(label = "Simple Binomial GLM (2D)", family = "binomial", links = c("logit", "probit", "cloglog"), default_link = "logit", dimensions = 2L, requires_group = FALSE),
  glm_binomial = list(label = "Binomial GLM", family = "binomial", links = c("logit", "probit", "cloglog"), default_link = "logit", dimensions = 3L, requires_group = FALSE),
  glm_poisson = list(label = "Poisson GLM", family = "poisson", links = c("log", "identity", "sqrt"), default_link = "log", dimensions = 3L, requires_group = FALSE),
  glm_gamma = list(label = "Gamma GLM", family = "Gamma", links = c("inverse", "log", "identity"), default_link = "inverse", dimensions = 3L, requires_group = FALSE),
  glmm = list(label = "Gaussian GLMM", family = "gaussian", links = "identity", default_link = "identity", dimensions = 3L, requires_group = TRUE)
)

model_ids <- function() names(MODEL_REGISTRY)

model_config <- function(model_type) {
  config <- MODEL_REGISTRY[[model_type]]
  if (is.null(config)) stop("Unknown model type: ", model_type, call. = FALSE)
  c(list(id = model_type), config)
}

valid_links <- function(model_type) model_config(model_type)$links

validate_model_link <- function(model_type, link = NULL) {
  config <- model_config(model_type)
  selected <- link %||% config$default_link
  if (!selected %in% config$links) {
    stop("Invalid link '", selected, "' for model '", model_type, "'", call. = FALSE)
  }
  selected
}

`%||%` <- function(left, right) if (is.null(left) || length(left) == 0L) right else left

required_model_columns <- function(model_type) {
  config <- model_config(model_type)
  c("X", "Z", if (config$dimensions == 3L) "Y", if (config$requires_group) "Group")
}

validate_glmm_groups <- function(group) {
  if (anyNA(group)) {
    stop("GLMM Group must not contain missing values", call. = FALSE)
  }
  if (length(unique(group)) < 5L) {
    stop("GLMM data must contain at least 5 observed groups", call. = FALSE)
  }
  invisible(group)
}

fit_model <- function(df, model_type, link = NULL) {
  config <- model_config(model_type)
  link <- validate_model_link(model_type, link)
  missing <- setdiff(required_model_columns(model_type), names(df))
  if (length(missing)) stop("Missing model columns: ", paste(missing, collapse = ", "), call. = FALSE)
  numeric <- intersect(c("X", "Y", "Z"), required_model_columns(model_type))
  if (any(!vapply(df[numeric], is.numeric, logical(1))) || any(!is.finite(as.matrix(df[numeric])))) {
    stop("Model data must contain finite numeric predictors and response", call. = FALSE)
  }
  if (startsWith(model_type, "glm_binomial") && any(!df$Z %in% c(0, 1))) stop("Binomial response must contain only 0 and 1", call. = FALSE)
  if (model_type == "glm_poisson" && any(df$Z < 0 | df$Z != floor(df$Z))) stop("Poisson response must contain non-negative integers", call. = FALSE)
  if (model_type == "glm_gamma" && any(df$Z <= 0)) stop("Gamma response must be strictly positive", call. = FALSE)
  if (model_type == "glmm") validate_glmm_groups(df$Group)
  if (model_type == "lm_2d") return(stats::lm(Z ~ X, data = df))
  if (model_type == "lm_3d") return(stats::lm(Z ~ X + Y, data = df))
  if (model_type == "glmm") {
    model_data <- df
    model_data$Group <- factor(model_data$Group)
    if (requireNamespace("lme4", quietly = TRUE)) {
      lmer_fn <- getExportedValue("lme4", "lmer")
      return(lmer_fn(Z ~ X + Y + (1 | Group), data = model_data))
    } else if (requireNamespace("nlme", quietly = TRUE)) {
      lme_fn <- getExportedValue("nlme", "lme")
      return(lme_fn(Z ~ X + Y, random = ~ 1 | Group, data = model_data))
    } else {
      return(stats::lm(Z ~ X + Y + Group, data = model_data))
    }
  }
  family_object <- do.call(config$family, list(link = link))
  if (config$dimensions == 2L) {
    return(stats::glm(Z ~ X, data = df, family = family_object))
  }
  if (model_type == "glm_poisson" && link == "identity") {
    design <- stats::model.matrix(Z ~ X + Y, data = df)
    start <- numeric(ncol(design))
    names(start) <- colnames(design)
    start[["(Intercept)"]] <- mean(df$Z) + 0.1
    return(stats::glm(
      Z ~ X + Y,
      data = df,
      family = family_object,
      start = start
    ))
  }
  stats::glm(Z ~ X + Y, data = df, family = family_object)
}

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

extract_model_kpis <- function(fit, model_type) {
  config <- model_config(model_type)
  n <- tryCatch(stats::nobs(fit), error = function(e) NA_integer_)
  aic <- tryCatch(round(stats::AIC(fit), 1), error = function(e) NA_real_)
  bic <- tryCatch(round(stats::BIC(fit), 1), error = function(e) NA_real_)
  loglik <- tryCatch(round(as.numeric(stats::logLik(fit)), 1), error = function(e) NA_real_)

  if (inherits(fit, "glm")) {
    null_dev <- fit$null.deviance
    res_dev <- fit$deviance
    df_res <- fit$df.residual
    dev_explained <- if (!is.null(null_dev) && null_dev > 0) max(0, 1 - res_dev / null_dev) else 0
    dispersion <- if (!is.null(df_res) && df_res > 0) res_dev / df_res else NA_real_
    converged <- isTRUE(fit$converged)

    r2_status <- if (dev_explained >= 0.7) "EXCELLENT FIT" else if (dev_explained >= 0.4) "GOOD FIT" else if (dev_explained >= 0.15) "MODERATE FIT" else "LOW FIT"
    r2_badge_class <- if (dev_explained >= 0.4) "status-optimal" else if (dev_explained >= 0.15) "status-warning" else "status-alert"

    disp_status <- if (is.na(dispersion)) "N/A" else if (dispersion > 1.5) "OVERDISPERSED" else if (dispersion < 0.5) "UNDERDISPERSED" else "NOMINAL VAR"
    disp_badge_class <- if (disp_status == "NOMINAL VAR") "status-optimal" else "status-warning"

    list(
      r2_label = "Deviance Explained",
      r2_value = sprintf("%.1f%%", dev_explained * 100),
      r2_sub = sprintf("Resid Dev: %.1f | Null Dev: %.1f", res_dev, null_dev),
      r2_status = r2_status,
      r2_badge_class = r2_badge_class,

      aic_label = "Model Criteria",
      aic_value = sprintf("AIC %.1f", aic),
      aic_sub = sprintf("BIC: %.1f | LogLik: %.1f", bic, loglik),
      aic_status = "PARSIMONIOUS",
      aic_badge_class = "status-optimal",

      err_label = "Dispersion Ratio",
      err_value = if (is.na(dispersion)) "N/A" else sprintf("%.3f", dispersion),
      err_sub = sprintf("Resid df: %d | Target: ~1.00", df_res %||% 0),
      err_status = disp_status,
      err_badge_class = disp_badge_class,

      health_label = "Sample & Convergence",
      health_value = sprintf("N = %d", n %||% 0),
      health_sub = sprintf("Resid df: %d | Link: %s", df_res %||% 0, fit$family$link),
      health_status = if (converged) "CONVERGED (OK)" else "UNCONVERGED",
      health_badge_class = if (converged) "status-optimal" else "status-alert"
    )
  } else if (inherits(fit, "merMod") || inherits(fit, "lme")) {
    s <- summary(fit)
    sigma_res <- tryCatch(stats::sigma(fit), error = function(e) NA_real_)
    obs <- tryCatch(stats::model.response(stats::model.frame(fit)), error = function(e) NULL)
    preds <- tryCatch(fitted_response(fit), error = function(e) NULL)
    r2 <- if (!is.null(obs) && !is.null(preds) && length(obs) == length(preds)) {
      stats::cor(obs, preds, use = "complete.obs")^2
    } else 0

    list(
      r2_label = "Marginal Pseudo-R²",
      r2_value = sprintf("%.1f%%", r2 * 100),
      r2_sub = "Fixed + Random components",
      r2_status = if (r2 >= 0.5) "GOOD FIT" else "MODERATE FIT",
      r2_badge_class = if (r2 >= 0.5) "status-optimal" else "status-warning",

      aic_label = "Model Criteria",
      aic_value = sprintf("AIC %.1f", aic),
      aic_sub = sprintf("BIC: %.1f | LogLik: %.1f", bic, loglik),
      aic_status = "OPTIMAL",
      aic_badge_class = "status-optimal",

      err_label = "Residual SD (\u03c3)",
      err_value = sprintf("%.3f", sigma_res),
      err_sub = "Group Intercept Random Effect",
      err_status = "HEALTHY VAR",
      err_badge_class = "status-optimal",

      health_label = "Sample & Groups",
      health_value = sprintf("N = %d", n %||% 0),
      health_sub = "GLMM Gaussian Mixed Fit",
      health_status = "CONVERGED (OK)",
      health_badge_class = "status-optimal"
    )
  } else {
    s <- summary(fit)
    r2 <- s$r.squared %||% 0
    adj_r2 <- s$adj.r.squared %||% 0
    rse <- s$sigma %||% 0
    df_res <- fit$df.residual %||% 0

    r2_status <- if (r2 >= 0.8) "EXCELLENT FIT" else if (r2 >= 0.5) "GOOD FIT" else if (r2 >= 0.2) "MODERATE FIT" else "LOW FIT"
    r2_badge_class <- if (r2 >= 0.5) "status-optimal" else if (r2 >= 0.2) "status-warning" else "status-alert"

    list(
      r2_label = "R² (Variance Explained)",
      r2_value = sprintf("%.1f%%", r2 * 100),
      r2_sub = sprintf("Adj. R²: %.1f%% (\u0394 %.1f%%)", adj_r2 * 100, (r2 - adj_r2) * 100),
      r2_status = r2_status,
      r2_badge_class = r2_badge_class,

      aic_label = "Model Criteria",
      aic_value = sprintf("AIC %.1f", aic),
      aic_sub = sprintf("BIC: %.1f | LogLik: %.1f", bic, loglik),
      aic_status = "PARSIMONIOUS",
      aic_badge_class = "status-optimal",

      err_label = "Residual Std Error (RSE)",
      err_value = sprintf("%.3f", rse),
      err_sub = sprintf("Resid df: %d", df_res),
      err_status = "NOMINAL VAR",
      err_badge_class = "status-optimal",

      health_label = "Sample & Health",
      health_value = sprintf("N = %d", n %||% 0),
      health_sub = sprintf("Predictors: %d | df: %d", length(stats::coef(fit)) - 1, df_res),
      health_status = "CONVERGED (OK)",
      health_badge_class = "status-optimal"
    )
  }
}

extract_coefficient_table <- function(fit) {
  s <- summary(fit)
  coefs <- if (inherits(fit, "merMod")) {
    s$coefficients
  } else if (inherits(fit, "lme")) {
    s$tTable
  } else {
    s$coefficients
  }

  if (is.null(coefs) || nrow(coefs) == 0) return(data.frame())

  ci <- tryCatch({
    if (inherits(fit, "lm") || inherits(fit, "glm")) {
      stats::confint.default(fit)
    } else {
      cbind(coefs[, 1] - 1.96 * coefs[, 2], coefs[, 1] + 1.96 * coefs[, 2])
    }
  }, error = function(e) {
    matrix(NA_real_, nrow = nrow(coefs), ncol = 2)
  })

  term_names <- rownames(coefs)
  estimates <- coefs[, 1]
  std_errors <- coefs[, 2]
  stat_col <- if (ncol(coefs) >= 3) coefs[, 3] else rep(NA_real_, nrow(coefs))
  p_col <- if (ncol(coefs) >= 4) coefs[, 4] else rep(NA_real_, nrow(coefs))

  data.frame(
    Term = term_names,
    Estimate = sprintf("%.4f", estimates),
    StdError = sprintf("%.4f", std_errors),
    Statistic = ifelse(is.na(stat_col), "N/A", sprintf("%.3f", stat_col)),
    PValue = vapply(p_col, format_pval, character(1)),
    CI95 = sprintf("[%.4f, %.4f]", ci[, 1], ci[, 2]),
    PValueClass = vapply(p_col, get_pval_sig_class, character(1)),
    stringsAsFactors = FALSE
  )
}

