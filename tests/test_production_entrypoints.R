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

  rscript <- Sys.which("Rscript")
  if (!nzchar(rscript)) rscript <- file.path(
    R.home("bin"),
    if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  )
  expect_true(file.exists(rscript))

  stdout <- tempfile(); stderr <- tempfile()
  on.exit(unlink(c(request_path, output_path, stdout, stderr)), add = TRUE)
  status <- system2(
    rscript,
    shQuote(c(file.path("..", "scripts", "run_analysis.R"), request_path, output_path)),
    stdout = stdout,
    stderr = stderr
  )

  expect_identical(as.integer(status), 0L, info = paste(readLines(stderr, warn = FALSE), collapse = "\n"))
  expect_length(readLines(stdout, warn = FALSE), 0L)
  expect_true(file.exists(output_path))
  result <- jsonlite::read_json(output_path)
  expect_identical(result$schema_version, "lmplot-analysis-result/1.0")
  expect_identical(result$model$model_type, "lm_2d")
  expect_identical(result$source$data_source, "simulation")
  expect_length(result$data, 30L)
  expect_true(all(c("metrics", "diagnostics", "warnings") %in% names(result)))
})
