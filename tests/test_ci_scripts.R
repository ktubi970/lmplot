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
