bundle_script <- file.path("..", "scripts", "shinylive_bundle.R")
if (file.exists(bundle_script)) source(bundle_script)

test_that("Shinylive build tooling stays outside the native runtime dependency lock", {
  packages <- renv::dependencies("..", quiet = TRUE)$Package
  expect_false("shinylive" %in% packages)
})

test_that("the browser bundle contains a working public app and prepared examples", {
  stage <- tempfile("shinylive-app-")
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  expect_identical(stage_shinylive_app("..", stage), normalizePath(stage, winslash = "/"))
  env <- new.env(parent = globalenv())
  for (name in c("model_registry.R", "mod_model.R", "mod_simulation.R", "mod_examples.R")) {
    sys.source(file.path(stage, "R", name), env)
  }
  expect_equal(length(env$example_ids(stage)), 7L)
  for (id in env$example_ids(stage)) {
    example <- env$load_real_example(id, stage)
    expect_equal(nrow(example$analysis), example$metadata$expected_rows)
    expect_true(file.exists(file.path(stage, "data", "real", id, "README.md")))
  }
  expect_identical(readBin(file.path(stage, "app.R"), "raw", 1000000),
                   readBin(file.path("..", "app.R"), "raw", 1000000))
  expect_true(file.exists(file.path(stage, "www", "style.css")))
  expect_true(file.exists(file.path(stage, "data", "real", "NOTICE.md")))
  expect_false(any(file.exists(file.path(stage, c(".Rprofile", ".git", "renv", "docs", "scripts", "data/real/sources")))))
})

test_that("staging preserves existing destinations instead of overwriting files", {
  stage <- tempfile("shinylive-existing-")
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  writeLines("keep", file.path(stage, "sentinel.txt"))
  expect_error(stage_shinylive_app("..", stage), "empty|exists")
  expect_identical(readLines(file.path(stage, "sentinel.txt")), "keep")
})

test_that("manifest paths are validated before any bundle files are written", {
  root <- tempfile("shinylive-source-")
  stage <- tempfile("shinylive-output-")
  dir.create(file.path(root, "data", "real"), recursive = TRUE)
  on.exit(unlink(c(root, stage), recursive = TRUE), add = TRUE)
  manifest <- read.csv(file.path("..", "data", "real", "manifest.csv"))
  for (id in c("../secret", "C:/secret", "a/b", "a\\b", ".", "")) {
    manifest$example_id[1] <- id
    write.csv(manifest, file.path(root, "data", "real", "manifest.csv"), row.names = FALSE)
    expect_error(stage_shinylive_app(root, stage), "example.*ID|example.*id")
    expect_false(dir.exists(stage))
  }
})

test_that("a missing required runtime file aborts before creating the bundle", {
  root <- tempfile("shinylive-incomplete-")
  stage <- tempfile("shinylive-output-")
  dir.create(file.path(root, "data", "real"), recursive = TRUE)
  on.exit(unlink(c(root, stage), recursive = TRUE), add = TRUE)
  file.copy(file.path("..", "data", "real", "manifest.csv"), file.path(root, "data", "real", "manifest.csv"))
  expect_error(stage_shinylive_app(root, stage), "Missing.*runtime")
  expect_false(dir.exists(stage))
})
