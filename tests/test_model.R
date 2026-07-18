model_path <- file.path("..", "R", "mod_model.R")
if (file.exists(model_path)) source(model_path)

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
