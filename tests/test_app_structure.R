test_that("public shell exposes four workflows, semantic landmarks and namespaced controls", {
  withr::local_envvar(LMPLOT_TRUSTED_LOCAL = NA)
  app <- new.env(); source(file.path("..", "app.R"), local = app)
  html <- as.character(app$ui)
  for (id in c("overview", "diagnostics", "brain", "data_provenance")) {
    expect_match(html, paste0('data-value="', id, '"'), fixed = TRUE)
  }
  expect_match(html, app$APP_VERSION, fixed = TRUE)
  expect_match(html, 'id="configuration-model_type"', fixed = TRUE)
  expect_match(html, 'id="overview-main_plot"', fixed = TRUE)
  expect_match(html, 'role="alert"', fixed = TRUE)
  expect_match(html, 'role="status"', fixed = TRUE)
  expect_match(html, "Skip to main content", fixed = TRUE)
  expect_match(html, "<main", fixed = TRUE)
  expect_false(grepl("expert_mode|MathJax|fonts.googleapis", html))
})
