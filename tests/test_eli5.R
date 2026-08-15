library(testthat)

app_root <- if (file.exists(file.path("R", "config.R"))) "." else ".."
source(file.path(app_root, "R", "config.R"), local = TRUE)
source(file.path(app_root, "R", "mod_model.R"), local = TRUE)
source(file.path(app_root, "R", "mod_eli5.R"), local = TRUE)

test_that("generate_eli5_explanation returns structured explanation list for lm_2d", {
  set.seed(42)
  df <- data.frame(X = 1:50, Z = 2 * (1:50) + rnorm(50))
  fit <- fit_model(df, "lm_2d", "identity")
  
  eli5 <- generate_eli5_explanation(fit, "lm_2d", "identity")
  expect_type(eli5, "list")
  expect_named(eli5, c("concept", "effects", "r2_eval", "r2_val", "conclusion"))
  expect_true(nzchar(eli5$concept))
  expect_gt(length(eli5$effects), 0)
  expect_true(nzchar(eli5$r2_eval))
  expect_true(nzchar(eli5$conclusion))
})

test_that("generate_eli5_explanation handles all 15 model/link combinations without error", {
  set.seed(123)
  df_2d <- data.frame(X = runif(60, 1, 10), Z = runif(60, 1, 20))
  df_3d <- data.frame(X = runif(60, 1, 10), Y = runif(60, 1, 10), Z = runif(60, 1, 20))
  df_bin <- data.frame(X = runif(60, -2, 2), Y = runif(60, -2, 2), Z = sample(c(0, 1), 60, replace = TRUE))
  df_pois <- data.frame(X = runif(60, 0.5, 3), Y = runif(60, 0.5, 3), Z = rpois(60, 5))
  df_gamma <- data.frame(X = runif(60, 1, 5), Y = runif(60, 1, 5), Z = rgamma(60, shape = 2, rate = 0.5))
  df_glmm <- data.frame(X = runif(60, 1, 10), Y = runif(60, 1, 10), Z = runif(60, 1, 20), Group = factor(rep(1:6, each = 10)))

  models_to_test <- list(
    list(id = "lm_2d", link = "identity", df = df_2d),
    list(id = "lm_3d", link = "identity", df = df_3d),
    list(id = "glm_binomial_2d", link = "logit", df = data.frame(X = runif(50, -2, 2), Z = sample(c(0, 1), 50, replace = TRUE))),
    list(id = "glm_binomial", link = "logit", df = df_bin),
    list(id = "glm_poisson", link = "log", df = df_pois),
    list(id = "glm_gamma", link = "log", df = df_gamma),
    list(id = "glmm", link = "identity", df = df_glmm)
  )

  for (item in models_to_test) {
    fit <- suppressWarnings(fit_model(item$df, item$id, item$link))
    eli5 <- generate_eli5_explanation(fit, item$id, item$link)
    expect_type(eli5, "list")
    expect_true(nzchar(eli5$concept))
  }
})
