release_root <- normalizePath("..", winslash = "/", mustWork = TRUE)

read_release_file <- function(path) {
  paste(
    readLines(file.path(release_root, path), warn = FALSE, encoding = "UTF-8"),
    collapse = "\n"
  )
}

test_that("release retains the locked Shiny runtime and launch contract", {
  expect_true(file.exists(file.path(release_root, "renv.lock")))
  expect_true(file.exists(file.path(release_root, ".Rprofile")))
  expect_true(file.exists(file.path(release_root, "renv", "activate.R")))
  expect_match(
    read_release_file("run.bat"),
    "shiny::runApp('.', launch.browser=TRUE)",
    fixed = TRUE
  )
})

test_that("a fresh R process activates the project library", {
  rscript <- Sys.which("Rscript")
  if (!nzchar(rscript)) rscript <- file.path(R.home("bin"),
    if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  expression <- paste(
    "cat(normalizePath(.libPaths(), winslash = '/', mustWork = FALSE),",
    "sep = '\n')"
  )
  output <- withr::with_dir(
    release_root,
    system2(rscript, c("-e", shQuote(expression)), stdout = TRUE, stderr = TRUE)
  )
  normalized_root <- normalizePath(release_root, winslash = "/", mustWork = TRUE)
  expected_library <- paste0(normalized_root, "/renv/library/")

  expect_true(any(startsWith(output, expected_library)), info = paste(output, collapse = "\n"))
})

test_that("README documents the exact beta matrix and trusted expert boundary", {
  readme <- read_release_file("README.md")
  expected_rows <- c(
    "| `lm_2d` | Simple LM (2D) | `lm` | `X` | `identity` |",
    "| `lm_3d` | Multiple LM (3D) | `lm` | `X + Y` | `identity` |",
    "| `glm_binomial_2d` | Simple Binomial GLM (2D) | `glm(binomial)` | `X` | `logit` |",
    "| `glm_binomial_2d` | Simple Binomial GLM (2D) | `glm(binomial)` | `X` | `probit` |",
    "| `glm_binomial_2d` | Simple Binomial GLM (2D) | `glm(binomial)` | `X` | `cloglog` |",
    "| `glm_binomial` | Binomial GLM | `glm(binomial)` | `X + Y` | `logit` |",
    "| `glm_binomial` | Binomial GLM | `glm(binomial)` | `X + Y` | `probit` |",
    "| `glm_binomial` | Binomial GLM | `glm(binomial)` | `X + Y` | `cloglog` |",
    "| `glm_poisson` | Poisson GLM | `glm(poisson)` | `X + Y` | `log` |",
    "| `glm_poisson` | Poisson GLM | `glm(poisson)` | `X + Y` | `identity` |",
    "| `glm_poisson` | Poisson GLM | `glm(poisson)` | `X + Y` | `sqrt` |",
    "| `glm_gamma` | Gamma GLM | `glm(Gamma)` | `X + Y` | `inverse` |",
    "| `glm_gamma` | Gamma GLM | `glm(Gamma)` | `X + Y` | `log` |",
    "| `glm_gamma` | Gamma GLM | `glm(Gamma)` | `X + Y` | `identity` |",
    "| `glmm` | Gaussian GLMM | `lmer` | `X + Y + (1 \\| Group)` | `identity` |"
  )

  for (row in expected_rows) expect_match(readme, row, fixed = TRUE)
  expect_match(readme, "15 model/link combinations", fixed = TRUE)
  expect_match(readme, "Requires R 4.6.0", fixed = TRUE)
  expect_match(readme, "renv::restore(prompt = FALSE)", fixed = TRUE)
  expect_match(readme, "testthat::test_dir('tests', reporter='summary')", fixed = TRUE)
  expect_match(readme, "trusted local use", fixed = TRUE)
})

test_that("launcher validates an explicitly restored library before running Shiny", {
  launcher <- read_release_file("run.bat")

  expect_match(launcher, "setlocal", fixed = TRUE)
  expect_match(launcher, "pushd \"%~dp0\"", fixed = TRUE)
  expect_match(launcher, "C:\\Program Files\\R\\R-4.6.0\\bin\\x64\\Rscript.exe", fixed = TRUE)
  expect_match(launcher, "--vanilla", fixed = TRUE)
  expect_match(launcher, "renv::status(", fixed = TRUE)
  expect_no_match(launcher, "install.packages", fixed = TRUE)
  expect_no_match(launcher, "renv::restore(", fixed = TRUE)
  expect_match(launcher, "shiny::runApp('.', launch.browser=TRUE)", fixed = TRUE)
  expect_match(launcher, "popd", fixed = TRUE)
})

test_that("Windows launcher fails without bootstrapping an absent project library", {
  launcher <- read_release_file("run.bat")
  expect_match(launcher, "--vanilla", fixed = TRUE)
  # Never execute an old installer during the regression test.
  if (.Platform$OS.type != "windows" || !grepl("--vanilla", launcher, fixed = TRUE))
    return(invisible(NULL))
  directory <- tempfile("launcher with spaces ")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  file.copy(file.path(release_root, "run.bat"), directory)
  # --vanilla must prevent this project startup profile from executing.
  writeLines("stop('UNEXPECTED_PROFILE_EXECUTION')", file.path(directory, ".Rprofile"))
  output <- suppressWarnings(system2(Sys.getenv("COMSPEC", "cmd.exe"),
    c("/d", "/c", shQuote(file.path(directory, "run.bat"))),
    stdout = TRUE, stderr = TRUE))
  expect_identical(as.integer(attr(output, "status")), 1L)
  expect_match(paste(output, collapse = "\n"), "Restore dependencies explicitly", fixed = TRUE)
  expect_no_match(paste(output, collapse = "\n"), "UNEXPECTED_PROFILE_EXECUTION", fixed = TRUE)
  expect_false(dir.exists(file.path(directory, "renv")))
})

test_that("renv lockfile covers runtime and test dependencies", {
  lock <- jsonlite::fromJSON(file.path(release_root, "renv.lock"), simplifyVector = FALSE)
  expected_packages <- c(
    "renv", "shiny", "plotly", "bslib", "DT", "ggplot2", "ggfortify",
    "lme4", "jsonlite", "shinyWidgets", "shinyAce", "testthat", "shinytest2"
  )

  expect_identical(lock$R$Version, "4.6.0")
  expect_true(all(expected_packages %in% names(lock$Packages)))
})

test_that("ignore rules exclude transient state without hiding release evidence", {
  ignore <- strsplit(read_release_file(".gitignore"), "\n", fixed = TRUE)[[1]]

  expect_true(all(c(
    ".Rproj.user/", ".Rhistory", ".RData", ".Ruserdata", ".env",
    ".worktrees/", ".superpowers/", "renv/library/", "renv/staging/",
    "tests/testthat/_snaps/_new/", "tests/shinytest2/_screenshots/", "*.tmp.png"
  ) %in% ignore))
  expect_false(any(c("renv.lock", "tests/", "tests/shinytest2/") %in% ignore))
})

test_that("TODO records completed automated beta verification", {
  todo <- read_release_file("TODO.md")

  expect_match(
    todo,
    "- [x] Reproducible runtime and automated beta verification",
    fixed = TRUE
  )
  expect_no_match(todo, "- [ ] Browser-based beta verification", fixed = TRUE)
})

test_that("release identity agrees across runtime, image, docs and license", {
  config <- new.env(parent = baseenv())
  sys.source(file.path(release_root, "R/config.R"), config)
  expect_identical(config$APP_VERSION, "0.10.0-beta.1")
  compose <- yaml::read_yaml(file.path(release_root, "docker-compose.yml"))
  expect_identical(compose$services$lmplot$image, paste0("lmplot:", config$APP_VERSION))
  for (path in c("README.md", "CHANGELOG.md", "TODO.md")) {
    expect_true(file.exists(file.path(release_root, path)), info = path)
    if (file.exists(file.path(release_root, path))) {
      expect_match(read_release_file(path), config$APP_VERSION, fixed = TRUE)
      expect_no_match(read_release_file(path), "0.9.0-beta.1", fixed = TRUE)
    }
  }
  expect_true(file.exists(file.path(release_root, "LICENSE")))
  if (file.exists(file.path(release_root, "LICENSE"))) {
    expect_match(read_release_file("LICENSE"), "MIT License", fixed = TRUE)
    expect_match(read_release_file("LICENSE"), "Copyright (c) 2026 lmplot contributors", fixed = TRUE)
  }
})

test_that("public release guidance documents CLI and the isolated deployment boundary", {
  readme <- read_release_file("README.md")
  for (value in c("3838", "LMPLOT_TRUSTED_LOCAL=1", "lmplot-analysis-request/1.0",
      "lmplot-analysis-result/1.0", "lmplot-error/1.0", "external ingress",
      "does not publish", "WebSocket", "Exit code")) expect_match(readme, value, fixed = TRUE)
  expect_no_match(readme, "streamlit run|pip install|8501|install\\.packages\\s*\\(", ignore.case = TRUE)
  expect_no_match(readme, "PATTERN-DESIGN-START", fixed = TRUE)
})

test_that("CI requires both locked R platforms and isolated Docker health", {
  path <- file.path(release_root, ".github/workflows/ci.yml")
  expect_true(file.exists(path))
  if (!file.exists(path)) return(invisible(NULL))
  workflow <- yaml::read_yaml(path)
  r <- workflow$jobs[["r-check"]]
  expect_setequal(r$strategy$matrix$os, c("windows-latest", "ubuntu-latest"))
  setup <- Filter(function(x) identical(x$uses, "r-lib/actions/setup-r@v2"), r$steps)
  expect_length(setup, 1L)
  expect_identical(setup[[1]]$with[["r-version"]], "4.6.0")
  expect_true(any(vapply(r$steps, function(x) identical(x$uses, "r-lib/actions/setup-renv@v2"), logical(1))))
  commands <- paste(vapply(r$steps, function(x) if (is.null(x$run)) "" else x$run, character(1)), collapse = "\n")
  expect_match(commands, "isTRUE(renv::status()$synchronized)", fixed = TRUE)
  expect_match(commands, "CHROMOTE_CHROME", fixed = TRUE)
  expect_match(commands, "$LASTEXITCODE", fixed = TRUE)
  expect_match(commands, "testthat::test_dir('tests', reporter='summary')", fixed = TRUE)
  docker <- workflow$jobs[["docker-health"]]
  expect_identical(docker$needs, "r-check")
  expect_identical(docker[["runs-on"]], "ubuntu-latest")
  build <- Filter(function(x) identical(x$uses, "docker/build-push-action@v6"), docker$steps)
  expect_identical(build[[1]]$with$tags, "lmplot:0.10.0-beta.1")
  smoke <- paste(vapply(docker$steps, function(x) if (is.null(x$run)) "" else x$run, character(1)), collapse = "\n")
  for (value in c("--network none", "--read-only", "--cap-drop ALL", "--cpus 2",
      "--memory 1g", "--pids-limit 256", "no-new-privileges:true",
      "LM Plot Explorer", "--format json", 'has("LMPLOT_TRUSTED_LOCAL")')) {
    expect_match(smoke, value, fixed = TRUE)
  }
  for (path in c("/tmp", "/var/log/shiny-server", "/var/lib/shiny-server",
      "/var/run/shiny-server", "/var/shiny-server/sockets")) {
    expect_match(smoke, paste0("--tmpfs ", path, ":"), fixed = TRUE)
  }
})

test_that("runtime R sources never install dependencies", {
  files <- c("app.R", "scripts/run_analysis.R", file.path("R", list.files(file.path(release_root, "R"),
    pattern = "\\.R$", recursive = TRUE, full.names = FALSE)))
  for (path in files) expect_no_match(read_release_file(path), "install\\.packages\\s*\\(")
  expect_no_match(read_release_file("scripts/run_analysis.R"), "\\.libPaths\\s*\\(")
})
