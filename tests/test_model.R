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
