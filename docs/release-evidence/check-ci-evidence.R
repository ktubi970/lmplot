results <- testthat::test_dir("tests", filter = "^ci_scripts$", reporter = "summary", stop_on_failure = FALSE)
evidence <- as.data.frame(results)
print(evidence[c("file", "test", "failed", "error", "warning", "skipped", "passed")])
stopifnot(!any(evidence$failed > 0L | evidence$error | evidence$skipped))
