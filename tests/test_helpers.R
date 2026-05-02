library(testthat)

source('../app.R') # expose helper functions

test_that("generate_data respects bounds", {
  df <- generate_data(1000)
  expect_true(all(df$X >= 0 & df$X <= 10))
  expect_true(all(df$Y >= 0 & df$Y <= 10))
})

test_that("fit_model recovers coefficients on noise‑free data", {
  set.seed(123)
  df <- data.frame(
    X = runif(100, 0, 10),
    Y = runif(100, 0, 10)
  )
  df$Z <- 2 + 1.5 * df$X - 0.8 * df$Y
  mod <- fit_model(df)
  coeffs <- coef(mod)
  expect_equal(round(coeffs[1], 2), 2)
  expect_equal(round(coeffs[2], 2), 1.5)
  expect_equal(round(coeffs[3], 2), -0.8)
})
