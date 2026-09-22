test_that("run_analysis production entry point fits an lm_2d request", {
  skip_if_not_installed("jsonlite")

  request_path <- tempfile(fileext = ".json")
  output_path <- tempfile(fileext = ".json")
  jsonlite::write_json(
    list(
      model_type = "lm_2d",
      link = "identity",
      data_source = "simulation",
      n = 30L,
      seed = 11L
    ),
    request_path,
    auto_unbox = TRUE
  )

  output <- system2(
    file.path(R.home("bin"), "Rscript.exe"),
    c(file.path("..", "scripts", "run_analysis.R"), shQuote(request_path), shQuote(output_path)),
    stdout = TRUE,
    stderr = TRUE
  )

  expect_null(attr(output, "status"), info = paste(output, collapse = "\n"))
  expect_true(file.exists(output_path))
  expect_identical(jsonlite::read_json(output_path)$model_type, "lm_2d")
})
