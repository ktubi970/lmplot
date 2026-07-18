release_root <- normalizePath("..", winslash = "/", mustWork = TRUE)

read_release_file <- function(path) {
  paste(
    readLines(file.path(release_root, path), warn = FALSE, encoding = "UTF-8"),
    collapse = "\n"
  )
}

test_that("release artifacts agree on the beta version", {
  expect_match(read_release_file("README.md"), "0.9.0-beta.1", fixed = TRUE)
  expect_match(read_release_file("TODO.md"), "0.9.0-beta.1", fixed = TRUE)
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
  rscript <- file.path(R.home("bin"), "Rscript.exe")
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
    "| `glm_binomial` | Binomial GLM | `glm(binomial)` | `X + Y` | `logit` |",
    "| `glm_binomial` | Binomial GLM | `glm(binomial)` | `X + Y` | `probit` |",
    "| `glm_binomial` | Binomial GLM | `glm(binomial)` | `X + Y` | `cloglog` |",
    "| `glm_poisson` | Poisson GLM | `glm(poisson)` | `X + Y` | `log` |",
    "| `glm_poisson` | Poisson GLM | `glm(poisson)` | `X + Y` | `identity` |",
    "| `glm_poisson` | Poisson GLM | `glm(poisson)` | `X + Y` | `sqrt` |",
    "| `glm_gamma` | Gamma GLM | `glm(Gamma)` | `X + Y` | `inverse` |",
    "| `glm_gamma` | Gamma GLM | `glm(Gamma)` | `X + Y` | `log` |",
    "| `glm_gamma` | Gamma GLM | `glm(Gamma)` | `X + Y` | `identity` |",
    "| `glmm` | Gaussian GLMM | `lmer` | `X + Y + (1 | Group)` | `identity` |"
  )

  for (row in expected_rows) expect_match(readme, row, fixed = TRUE)
  expect_match(readme, "12 model/link combinations", fixed = TRUE)
  expect_match(readme, "Requires R 4.6.x", fixed = TRUE)
  expect_match(readme, "renv::restore()", fixed = TRUE)
  expect_match(readme, "testthat::test_dir(\"tests\", reporter = \"summary\")", fixed = TRUE)
  expect_match(readme, "trusted local use", fixed = TRUE)
})

test_that("launcher restores and runs from its own project directory", {
  launcher <- read_release_file("run.bat")

  expect_match(launcher, "setlocal", fixed = TRUE)
  expect_match(launcher, "pushd \"%~dp0\"", fixed = TRUE)
  expect_match(launcher, "C:\\Program Files\\R\\R-4.6.0\\bin\\x64\\Rscript.exe", fixed = TRUE)
  expect_match(launcher, "renv::restore(prompt=FALSE)", fixed = TRUE)
  expect_match(launcher, "shiny::runApp('.', launch.browser=TRUE)", fixed = TRUE)
  expect_match(launcher, "popd", fixed = TRUE)
})

test_that("renv lockfile covers runtime and test dependencies", {
  lock <- jsonlite::fromJSON(file.path(release_root, "renv.lock"), simplifyVector = FALSE)
  expected_packages <- c(
    "renv", "shiny", "plotly", "bslib", "DT", "ggplot2", "ggfortify",
    "lme4", "shinyWidgets", "shinyAce", "testthat", "shinytest2"
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

test_that("TODO distinguishes delivered runtime from pending browser verification", {
  todo <- read_release_file("TODO.md")

  expect_match(todo, "- [x] Reproducible runtime", fixed = TRUE)
  expect_match(todo, "- [ ] Browser-based beta verification", fixed = TRUE)
  expect_no_match(todo, "- [x] Reproducible runtime and automated beta verification", fixed = TRUE)
})
