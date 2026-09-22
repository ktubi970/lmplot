model_path <- file.path("..", "R", "mod_model.R")
registry_path <- file.path("..", "R", "model_registry.R")
if (file.exists(registry_path)) source(registry_path)
if (file.exists(model_path)) source(model_path)
source(file.path("..", "R", "model_metrics.R"))
source(file.path("..", "R", "model_diagnostics.R"))
source(file.path("..", "R", "mod_simulation.R"))

expected_matrix <- list(
  lm_2d = "identity",
  lm_3d = "identity",
  glm_binomial_2d = c("logit", "probit", "cloglog"),
  glm_binomial = c("logit", "probit", "cloglog"),
  glm_poisson = c("log", "identity", "sqrt"),
  glm_gamma = c("inverse", "log", "identity"),
  glmm = "identity"
)

test_that("registry exposes the beta acceptance matrix", {
  expect_true(exists("MODEL_REGISTRY", inherits = TRUE))
  expect_setequal(model_ids(), names(expected_matrix))
  expect_identical(unname(lapply(model_ids(), valid_links)), unname(expected_matrix))
  expect_equal(sum(lengths(lapply(model_ids(), valid_links))), 15L)
})

test_that("invalid models and links fail explicitly", {
  expect_error(model_config("unknown"), "Unknown model type")
  expect_error(validate_model_link("glm_binomial", "identity"), "Invalid link")
})

test_that("every beta combination fits and returns response-scale values", {
  matrix <- do.call(rbind, lapply(model_ids(), function(id) {
    data.frame(model_type = id, link = valid_links(id), stringsAsFactors = FALSE)
  }))
  for (row in seq_len(nrow(matrix))) {
    model_type <- matrix$model_type[[row]]
    link <- matrix$link[[row]]
    df <- simulate_data(model_type, link, n = 120L, seed = row)
    warnings <- character()
    fit <- withCallingHandlers(
      fit_model(df, model_type, link),
      warning = function(warning) {
        warnings <<- c(warnings, conditionMessage(warning))
        invokeRestart("muffleWarning")
      }
    )
    if (length(warnings) > 0L) {
      expect_true(startsWith(model_type, "glm_binomial"))
      expect_true(all(warnings == "glm.fit: fitted probabilities numerically 0 or 1 occurred"))
    }
    expected_class <- if (model_type == "glmm") "lmerMod" else if (startsWith(model_type, "glm_")) "glm" else "lm"
    if (model_type == "glmm") expect_s4_class(fit, "lmerMod")
    else expect_s3_class(fit, expected_class)
    expect_length(fitted_response(fit), nrow(df))
    expect_length(response_residuals(fit), nrow(df))
    expect_true(all(is.finite(fitted_response(fit))))
    if (startsWith(model_type, "glm_")) {
      expected <- stats::predict(fit, type = "response")
      expect_equal(predict_response(fit), expected)
      expect_equal(fitted_response(fit), as.numeric(expected))
    }
    if (model_type == "glmm") {
      expected <- stats::predict(fit, newdata = df, re.form = NA, allow.new.levels = TRUE)
      expect_equal(predict_response(fit, newdata = df, population = TRUE), expected)
    }
  }
})

test_that("Poisson identity fits the documented acceptance simulation", {
  data <- simulate_data(
    "glm_poisson",
    "identity",
    n = 100L,
    seed = 107L
  )

  expect_silent(fit <- fit_model(data, "glm_poisson", "identity"))
  expect_s3_class(fit, "glm")
  expect_true(all(is.finite(fitted_response(fit))))
  expect_true(all(fitted_response(fit) > 0))
})

test_that("fit_model validates GLMM groups without relying on simulation", {
  valid <- data.frame(
    X = seq_len(20L),
    Y = seq_len(20L) / 2,
    Z = seq_len(20L) + rep(c(-1, 1), 10L),
    Group = rep(1:5, each = 4L)
  )

  for (representation in list(
    factor(valid$Group),
    as.character(valid$Group),
    valid$Group
  )) {
    candidate <- valid
    candidate$Group <- representation
    original <- candidate
    fit <- suppressMessages(suppressWarnings(
      fit_model(candidate, "glmm", "identity")
    ))
    expect_s4_class(fit, "lmerMod")
    expect_s3_class(stats::model.frame(fit)$Group, "factor")
    expect_identical(candidate, original)
  }

  missing_group <- valid
  missing_group$Group[[1L]] <- NA
  expect_error(
    fit_model(missing_group, "glmm", "identity"),
    "GLMM Group must not contain missing values",
    fixed = TRUE
  )

  too_few_groups <- valid
  too_few_groups$Group <- rep(1:4, length.out = nrow(too_few_groups))
  expect_error(
    fit_model(too_few_groups, "glmm", "identity"),
    "GLMM data must contain at least 5 observed groups",
    fixed = TRUE
  )
})

test_that("extract_model_kpis and extract_coefficient_table return structured metrics", {
  df <- simulate_data("lm_2d", "identity", n = 100L, seed = 42L)
  fit <- fit_model(df, "lm_2d", "identity")

  kpis <- extract_model_kpis(fit, "lm_2d")
  expect_type(kpis, "list")
  expect_named(kpis, c(
    "r2_label", "r2_value", "r2_sub", "r2_status", "r2_badge_class",
    "aic_label", "aic_value", "aic_sub", "aic_status", "aic_badge_class",
    "err_label", "err_value", "err_sub", "err_status", "err_badge_class",
    "health_label", "health_value", "health_sub", "health_status", "health_badge_class"
  ))
  expect_match(kpis$r2_label, "R²")
  valid_classes <- c("text-secondary", "status-warning")
  expect_true(kpis$r2_badge_class %in% valid_classes)
  expect_true(kpis$aic_badge_class %in% valid_classes)
  expect_true(kpis$err_badge_class %in% valid_classes)
  expect_true(kpis$health_badge_class %in% valid_classes)

  coef_df <- extract_coefficient_table(fit)
  expect_s3_class(coef_df, "data.frame")
  expect_true(nrow(coef_df) >= 2L)
  expect_true(all(c("term", "estimate", "standard_error", "statistic", "p_value", "conf_low", "conf_high", "interval_available") %in% names(coef_df)))
  expect_false(any(grepl("optimal|parsim|healthy|converged", unlist(kpis), ignore.case = TRUE)))
})

test_that("model_latex_formula returns LaTeX formula for all 15 model/link combinations", {
  matrix <- do.call(rbind, lapply(model_ids(), function(id) {
    data.frame(model_type = id, link = valid_links(id), stringsAsFactors = FALSE)
  }))
  expect_equal(nrow(matrix), 15L)

  expected_formulas <- c(
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
    "glmm:identity" = "Z_{ij} = \\beta_0 + \\beta_1 X_{ij} + \\beta_2 Y_{ij} + u_{j} + \\epsilon_{ij}, \\quad u_j \\sim \\mathcal{N}(0, \\sigma_u^2)"
  )

  for (row in seq_len(nrow(matrix))) {
    m_type <- matrix$model_type[[row]]
    lnk <- matrix$link[[row]]
    key <- paste(m_type, lnk, sep = ":")
    formula <- model_latex_formula(m_type, lnk)
    expect_equal(formula, expected_formulas[[key]], info = key)
  }

  expect_equal(model_latex_formula("lm_2d"), "Z = \\beta_0 + \\beta_1 X + \\epsilon")
  expect_equal(model_latex_formula("glm_binomial"), "\\text{logit}(P(Z=1)) = \\beta_0 + \\beta_1 X + \\beta_2 Y")

  expect_error(model_latex_formula("unknown"), "Unknown model type")
  expect_error(model_latex_formula("lm_2d", "log"), "Invalid link")
})

test_that("format_pval and get_pval_sig_class return significance tiers", {
  expect_equal(get_pval_sig_class(0.0001), "sig-high")
  expect_equal(get_pval_sig_class(0.005), "sig-med")
  expect_equal(get_pval_sig_class(0.03), "sig-low")
  expect_equal(get_pval_sig_class(0.15), "sig-ns")
  expect_equal(get_pval_sig_class(NA), "sig-ns")
})

test_that("residual diagnostics flag curvature without claiming adequacy", {
  df_lin <- simulate_data("lm_2d", "identity", n = 150L, seed = 42L, pattern = "linear")
  fit_lin <- fit_model(df_lin, "lm_2d", "identity")
  diag_lin <- diagnose_model_linearity(fit_lin, df_lin, "lm_2d")

  expect_equal(diag_lin$status, "information")
  expect_length(diag_lin$warnings, 0L)

  df_quad <- simulate_data("lm_2d", "identity", n = 150L, seed = 42L, pattern = "quadratic")
  fit_quad <- fit_model(df_quad, "lm_2d", "identity")
  diag_quad <- diagnose_model_linearity(fit_quad, df_quad, "lm_2d")

  expect_equal(diag_quad$status, "warning")
  expect_true(any(grepl("curvature", diag_quad$warnings)))
})


