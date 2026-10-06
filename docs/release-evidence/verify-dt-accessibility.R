stopifnot(getRversion() == "4.6.0", isTRUE(renv::status()$synchronized))
cat(R.version.string, "\n")
print(l10n_info())
Sys.setenv(NOT_CRAN = "true", CI = "true", GITHUB_ACTIONS = "true")
Sys.unsetenv("LMPLOT_TRUSTED_LOCAL")
stage <- commandArgs(trailingOnly = TRUE)[[1L]]
testthat::set_max_fails(Inf)
Sys.setenv(LMPLOT_DT_SCREENSHOT = file.path(normalizePath("docs/release-evidence", winslash = "/"),
  paste0("dt-accessibility-", stage, ".png")))
results <- testthat::test_dir("tests", filter = "^data_provenance_browser$",
  reporter = "summary", stop_on_failure = FALSE)
evidence <- as.data.frame(results)
write.csv(evidence[c("file", "test", "failed", "error", "warning", "skipped", "passed")],
  file.path("docs/release-evidence", paste0("dt-accessibility-", stage, ".csv")), row.names = FALSE)
print(evidence[c("file", "test", "failed", "error", "warning", "skipped", "passed")])
stopifnot(!any(evidence$failed > 0L | evidence$error | evidence$skipped))
