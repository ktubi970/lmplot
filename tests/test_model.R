model_path <- file.path("..", "R", "mod_model.R")
if (file.exists(model_path)) source(model_path)
source(file.path("..", "R", "mod_simulation.R"))

expected_matrix <- list(
  lm_2d = "identity",
  lm_3d = "identity",
  glm_binomial = c("logit", "probit", "cloglog"),
  glm_poisson = c("log", "identity", "sqrt"),
  glm_gamma = c("inverse", "log", "identity"),
  glmm = "identity"
)

test_that("registry exposes the beta acceptance matrix", {
  expect_true(exists("MODEL_REGISTRY", inherits = TRUE))
  expect_setequal(model_ids(), names(expected_matrix))
  expect_identical(unname(lapply(model_ids(), valid_links)), unname(expected_matrix))
  expect_equal(sum(lengths(lapply(model_ids(), valid_links))), 12L)
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
    expected_warnings <- if (model_type == "glm_binomial" && link == "cloglog") {
      "glm.fit: fitted probabilities numerically 0 or 1 occurred"
    } else {
      character()
    }
    expect_identical(warnings, expected_warnings)
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
