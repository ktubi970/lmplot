test_that("both CI R steps execute later lines and propagate their failure on Windows", {
  workflow <- yaml::read_yaml(file.path("..", ".github", "workflows", "ci.yml"))
  steps <- Filter(function(step) !is.null(step$run) &&
    grepl("(?m)^\\$(checks|tests)\\s*=\\s*@'\\r?$", step$run, perl = TRUE),
    workflow$jobs[["r-check"]]$steps)
  expect_length(steps, 2L)
  scripts <- lapply(steps, function(step) {
    expect_identical(step$shell, "pwsh", info = step$name)
    lines <- strsplit(step$run, "\n", fixed = TRUE)[[1]]
    opening <- grep("@'\\r?$", lines)
    closing <- grep("^'@\\r?$", lines)
    expect_length(opening, 1L)
    expect_length(closing, 1L)
    if (length(opening) != 1L || length(closing) != 1L) return(NULL)
    expect_true(closing > opening, info = step$name)
    if (closing <= opening) return(NULL)
    # Replace only the R payload; retain the workflow's real invocation and exit guard.
    c(head(lines, opening), "cat('CI_FIRST_LINE\\n')",
      "stop('CI_LATER_LINE_FAILURE')", tail(lines, -(closing - 1L)))
  })
  if (.Platform$OS.type != "windows") return(invisible(NULL))

  shell <- unname(Sys.which("pwsh"))
  if (!nzchar(shell)) shell <- file.path(Sys.getenv("SystemRoot"),
    "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
  expect_true(file.exists(shell))
  if (!file.exists(shell)) return(invisible(NULL))
  directory <- withr::local_tempdir(pattern = "ci scripts ")
  withr::local_dir(directory)
  # Use the top-level Windows dispatcher whose multiline -e handling lost assertions.
  withr::local_envvar(c(RUNNER_TEMP = directory,
    PATH = paste(file.path(R.home(), "bin"), Sys.getenv("PATH"), sep = .Platform$path.sep)))

  for (i in seq_along(scripts)) {
    if (is.null(scripts[[i]])) next
    path <- file.path(directory, paste0("ci-step-", i, ".ps1"))
    writeLines(scripts[[i]], path, useBytes = TRUE)
    output <- suppressWarnings(system2(shell,
      c("-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", shQuote(path)),
      stdout = TRUE, stderr = TRUE))
    details <- paste(steps[[i]]$name, paste(output, collapse = "\n"), sep = "\n")
    expect_true(any(grepl("CI_FIRST_LINE", output, fixed = TRUE)), info = details)
    expect_true(any(grepl("CI_LATER_LINE_FAILURE", output, fixed = TRUE)), info = details)
    expect_identical(as.integer(attr(output, "status")), 1L, info = details)
  }
})

test_that("CI saves complete test evidence before failing for errors or skipped tests", {
  workflow <- yaml::read_yaml(file.path("..", ".github", "workflows", "ci.yml"))
  steps <- Filter(function(step) !is.null(step$run) &&
    grepl("(?m)^\\$tests\\s*=\\s*@'\\r?$", step$run, perl = TRUE),
    workflow$jobs[["r-check"]]$steps)
  expect_length(steps, 1L)
  lines <- strsplit(steps[[1L]]$run, "\n", fixed = TRUE)[[1L]]
  payload <- lines[seq.int(grep("@'\\r?$", lines) + 1L, grep("^'@\\r?$", lines) - 1L)]
  script <- file.path(withr::local_tempdir(), "ci-evidence.R")
  libraries <- paste(capture.output(dput(.libPaths())), collapse = "\n")
  writeLines(c(paste0(".libPaths(", libraries, ")"), payload), script)

  for (case in c("passed", "failed", "error", "skipped")) {
    directory <- withr::local_tempdir(pattern = paste0("ci-evidence-", case))
    dir.create(file.path(directory, "tests"))
    expression <- switch(case,
      passed = "expect_true(TRUE)", failed = "expect_true(FALSE)",
      error = "stop('intentional fixture error')", skipped = "skip('intentional fixture skip')")
    writeLines(c("test_that('passing control', { expect_equal(2 + 2, 4) })",
      paste0("test_that('", case, " fixture', { ", expression, " })")),
      file.path(directory, "tests", "test_fixture.R"))
    output <- withr::with_dir(directory, withr::with_envvar(c(RUNNER_TEMP = directory),
      suppressWarnings(system2(file.path(R.home("bin"),
        if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"),
        c("--vanilla", shQuote(script)), stdout = TRUE, stderr = TRUE))))
    status <- attr(output, "status")
    if (is.null(status)) status <- 0L
    expect_identical(as.integer(status), if (case == "passed") 0L else 1L,
      info = paste(case, paste(output, collapse = "\n")))
    path <- file.path(directory, "lmplot-test-evidence", "results.csv")
    expect_true(file.exists(path), info = case)
    if (!file.exists(path)) next
    evidence <- read.csv(path)
    expect_identical(evidence$test, c("passing control", paste(case, "fixture")))
    expect_identical(evidence$failed > 0L, c(FALSE, case == "failed"))
    expect_identical(evidence$error, c(FALSE, case == "error"))
    expect_identical(evidence$skipped, c(FALSE, case == "skipped"))
  }
})
