config_path <- file.path("..", "R", "config.R")
if (file.exists(config_path)) source(config_path)

test_that("beta version is exact", {
  expect_true(exists("APP_VERSION", inherits = TRUE))
  expect_identical(APP_VERSION, "0.10.0-beta.1")
})
