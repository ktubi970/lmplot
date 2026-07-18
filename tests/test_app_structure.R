test_that("the real browser workflow delegates log classification to its helper", {
  source <- paste(readLines("test_app.R", warn = FALSE), collapse = "\n")

  expect_match(
    source,
    "unexpected_logs <- unexpected_app_logs(app$get_logs())",
    fixed = TRUE
  )
  expect_no_match(source, "known_binary_warning <- grepl", fixed = TRUE)
})
