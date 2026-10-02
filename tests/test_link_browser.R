source(file.path("..", "app.R"), local = TRUE)

test_that("same-default model switch fits the link selected in the browser", {
  withr::local_envvar(c(NOT_CRAN = "true", LMPLOT_TRUSTED_LOCAL = NA))
  app <- shinytest2::AppDriver$new("..", name = "shared-link", seed = 123,
    load_timeout = 1e5, timeout = 1e5)
  on.exit(app$stop(), add = TRUE)

  app$set_inputs(`configuration-model_type` = "glm_binomial_2d")
  app$wait_for_idle()
  app$set_inputs(`configuration-model_type` = "glm_binomial")
  app$wait_for_idle()
  app$set_inputs(`configuration-link_sel` = "probit",
    `configuration-simulation-n` = 80L,
    `configuration-simulation-seed` = 12L)
  expect_identical(app$get_value(input = "configuration-link_sel"), "probit")
  app$wait_for_idle()
  app$click("overview-guided_interpretation-show")
  app$wait_for_js("document.querySelector('#overview-guided_interpretation-content .card-body') !== null")
  expect_match(app$get_html("#overview-guided_interpretation-content"),
    "uses a probit link", fixed = TRUE)
})
