test_that("run_analysis production entry point fits an lm_2d request", {
  skip_if_not_installed("jsonlite")

  request_path <- tempfile(fileext = ".json")
  output_path <- tempfile(fileext = ".json")
  jsonlite::write_json(
    list(
      schema_version = "lmplot-analysis-request/1.0",
      model_type = "lm_2d",
      link = "identity",
      data_source = "simulation",
      simulation = list(n = 30L, seed = 11L)
    ),
    request_path,
    auto_unbox = TRUE
  )

  rscript <- file.path(
    R.home("bin"),
    if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  )
  expect_true(file.exists(rscript))

  output <- system2(
    rscript,
    c(file.path("..", "scripts", "run_analysis.R"), shQuote(request_path), shQuote(output_path)),
    stdout = TRUE,
    stderr = TRUE
  )

  expect_null(attr(output, "status"), info = paste(output, collapse = "\n"))
  expect_true(file.exists(output_path))
  result <- jsonlite::read_json(output_path)
  expect_identical(result$model_type, "lm_2d")
  expect_length(result$data, 30L)
  expect_true(all(c("metrics", "diagnostics", "warnings") %in% names(result)))
})
