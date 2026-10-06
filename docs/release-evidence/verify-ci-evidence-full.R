stopifnot(getRversion() == "4.6.0", isTRUE(renv::status()$synchronized))
cat(R.version.string, "\n")
print(l10n_info())
packages <- installed.packages()
required <- c("renv", "shiny", "plotly", "bslib", "DT", "ggplot2", "ggfortify",
  "lme4", "jsonlite", "shinyWidgets", "shinyAce", "testthat", "shinytest2", "chromote", "yaml")
print(packages[intersect(required, rownames(packages)), c("Package", "Version", "Built"), drop = FALSE])
Sys.setenv(CI = "true", GITHUB_ACTIONS = "true", NOT_CRAN = "true", RUNNER_OS = "Windows",
  RUNNER_TEMP = file.path(normalizePath("docs/release-evidence", winslash = "/"), "ci-evidence-full"))
Sys.unsetenv("LMPLOT_TRUSTED_LOCAL")
workflow <- yaml::read_yaml(".github/workflows/ci.yml")
steps <- Filter(function(step) !is.null(step$run) &&
  grepl("(?m)^\\$tests\\s*=\\s*@'\\r?$", step$run, perl = TRUE), workflow$jobs[["r-check"]]$steps)
stopifnot(length(steps) == 1L)
lines <- strsplit(steps[[1L]]$run, "\n", fixed = TRUE)[[1L]]
payload <- lines[seq.int(grep("@'\\r?$", lines) + 1L, grep("^'@\\r?$", lines) - 1L)]
eval(parse(text = payload))
cat("TOTAL files", length(unique(evidence$file)), "tests", nrow(evidence),
  "passed", sum(evidence$passed), "failed", sum(evidence$failed),
  "errors", sum(evidence$error), "skips", sum(evidence$skipped),
  "warnings", sum(evidence$warning), "\n")
