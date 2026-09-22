cli_root <- normalizePath("..", winslash = "/", mustWork = TRUE)

cli_rscript <- function() {
  path <- Sys.which("Rscript")
  if (!nzchar(path)) path <- file.path(R.home("bin"),
    if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  path
}

cli_payload <- function() list(schema_version = "lmplot-analysis-request/1.0",
  model_type = "lm_2d", data_source = "simulation", simulation = list(n = 30L, seed = 11L))

# Each fixture runs the real adapter with separate streams, also from outside the repo.
cli_process <- function(payload = cli_payload(), raw = NULL, injection = NULL,
                        invalid_output = FALSE, args_count = 2L, before_source = NULL,
                        missing_request = FALSE) {
  directory <- tempfile("cli paths with spaces ")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  request <- file.path(directory, "request.json")
  output <- file.path(directory, if (invalid_output) "missing/result.json" else "result.json")
  if (is.null(raw)) jsonlite::write_json(payload, request, auto_unbox = TRUE, null = "null") else writeLines(raw, request)
  script <- file.path(cli_root, "scripts", "run_analysis.R")
  if (missing_request) unlink(request)
  if (!is.null(injection) || !is.null(before_source)) {
    driver <- file.path(directory, "driver.R")
    writeLines(c("adapter <- new.env(parent = globalenv())",
      before_source,
      sprintf("sys.source(%s, envir = adapter)", deparse(script)),
      "dependencies <- adapter$default_cli_dependencies()", injection,
      "quit(status = adapter$run_analysis_cli(commandArgs(TRUE), dependencies))"), driver)
    script <- driver
  }
  args <- c(request, output, "extra")[seq_len(args_count)]
  stdout <- file.path(directory, "stdout.txt"); stderr <- file.path(directory, "stderr.txt")
  # Use the already activated locked library without asking the adapter to mutate it.
  status <- withr::with_envvar(c(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep),
    LMPLOT_TRUSTED_LOCAL = "true", LC_ALL = "C"), withr::with_dir(directory,
      suppressWarnings(system2(cli_rscript(), shQuote(c(script, args)), stdout = stdout, stderr = stderr))))
  text <- if (file.exists(output)) paste(readLines(output, warn = FALSE), collapse = "\n") else NULL
  list(status = as.integer(status), stdout = readLines(stdout, warn = FALSE),
    stderr = paste(readLines(stderr, warn = FALSE), collapse = "\n"), text = text,
    json = if (!is.null(text)) jsonlite::fromJSON(text, simplifyVector = FALSE) else NULL,
    output_parent_created = dir.exists(dirname(output)))
}

expect_cli_error <- function(result, status, code, message) {
  expect_identical(result$status, as.integer(status), info = result$stderr)
  expect_length(result$stdout, 0L)
  expect_identical(result$json, list(schema_version = "lmplot-error/1.0",
    error = list(code = code, message = message)))
  expect_false(grepl("SECRET|request.json|driver.R|lexical error", result$text %||% ""))
  expect_true(nzchar(result$stderr))
}

test_that("CLI returns the versioned complete result from any working directory", {
  result <- cli_process()
  expect_identical(result$status, 0L, info = result$stderr)
  expect_length(result$stdout, 0L)
  expect_identical(names(result$json), c("schema_version", "model", "source", "labels",
    "data", "fitted_values", "response_residuals", "metrics", "coefficients",
    "diagnostics", "warnings", "prediction_grid", "model_brain"))
  expect_identical(result$json$schema_version, "lmplot-analysis-result/1.0")
  expect_identical(result$json$model, list(model_type = "lm_2d", link = "identity"))
  expect_identical(result$json$source, list(data_source = "simulation", example_id = NULL))
  expect_length(result$json$data, 30L)
  expect_length(result$json$fitted_values, 30L)
  expect_length(result$json$response_residuals, 30L)
  expect_true(is.list(result$json$data[[1]]))
  expect_match(result$json$metrics$comparison_description, "same response", fixed = TRUE)
  expect_identical(result$json$model_brain$schema_version, "model-brain/1.0")
  expect_identical(result$json$model_brain$prediction_modes, list("conditional"))
  expect_true(is.list(result$json$warnings))
  expect_true(is.list(result$json$diagnostics$warnings))
  expect_false(grepl(':(NaN|-?Inf)([,}])', result$text))
})

test_that("CLI classifies malformed and forbidden public requests", {
  cases <- list('{SECRET invalid json', '{"data_source":"simulation","model_type":"lm_2d"}',
    '{"schema_version":"wrong","data_source":"simulation","model_type":"lm_2d"}',
    '{"schema_version":"lmplot-analysis-request/1.0","data_source":"simulation","model_type":"lm_2d","SECRET":1}',
    '{"schema_version":"lmplot-analysis-request/1.0","data_source":"real","model_type":"lm_2d","simulation":null}',
    '{"schema_version":"lmplot-analysis-request/1.0","data_source":"simulation","model_type":"lm_2d","example_id":null}')
  for (raw in cases) expect_cli_error(cli_process(raw = raw), 2, "invalid_request", "The analysis request is invalid.")
  payload <- cli_payload(); payload$expert <- list(enabled = TRUE, code = "stop('SECRET')")
  expect_cli_error(cli_process(payload), 2, "expert_not_trusted", "Expert mode requires a trusted local environment.")
})

test_that("CLI requires exactly two arguments and keeps stdout empty", {
  for (n in c(0L, 1L)) {
    result <- cli_process(args_count = n)
    expect_identical(result$status, 2L, info = result$stderr)
    expect_length(result$stdout, 0L)
    expect_null(result$text)
    expect_identical(result$stderr, "The analysis request is invalid.")
  }
})

test_that("extra CLI arguments write an error to the identifiable second path", {
  expect_cli_error(cli_process(args_count = 3L), 2,
    "invalid_request", "The analysis request is invalid.")
  expect_cli_error(cli_process(args_count = 3L, injection =
    'dependencies$decode_json <- function(...) stop("Request must not be read for invalid usage")'),
    2, "invalid_request", "The analysis request is invalid.")
  result <- cli_process(args_count = 3L, invalid_output = TRUE)
  expect_identical(result$status, 4L, info = result$stderr)
  expect_null(result$text)
  expect_length(result$stdout, 0L)
})

test_that("sourced CLI classifies dependency and analysis failures without leaking details", {
  cases <- list(
    list("analysis_dependency_error", "dependency_unavailable", "A required analysis dependency is unavailable."),
    list("analysis_service_error", "dependency_unavailable", "A required analysis dependency is unavailable."),
    list("simpleError", "analysis_failed", "The analysis could not be completed."))
  for (case in cases) {
    injection <- sprintf('dependencies$run_usecase <- function(...) stop(structure(list(message = "SECRET /private/path", call = quote(private_call())), class = c("%s", "error", "condition")))', case[[1]])
    result <- cli_process(injection = injection)
    expect_cli_error(result, 3, case[[2]], case[[3]])
    expect_match(result$stderr, "SECRET /private/path", fixed = TRUE)
    expect_match(result$stderr, "private_call()", fixed = TRUE)
    expect_match(result$stderr, case[[1]], fixed = TRUE)
  }
})

test_that("CLI handles unavailable jsonlite and lme4 without runtime installation", {
  for (package in c("jsonlite", "lme4")) {
    payload <- cli_payload()
    if (package == "lme4") payload$model_type <- "glmm"
    injection <- sprintf('adapter$requireNamespace <- function(package, ...) if (package == "%s") FALSE else base::requireNamespace(package, ...)', package)
    expect_cli_error(cli_process(payload, injection = injection), 3,
      "dependency_unavailable", "A required analysis dependency is unavailable.")
  }
})

test_that("serialization and mapping failures produce a fixed exit-4 envelope", {
  injections <- c(
    'dependencies$encode_json <- function(value) { if (value$schema_version == "lmplot-analysis-result/1.0") stop("SECRET encode"); adapter$encode_json_contract(value) }',
    'dependencies$result_to_contract <- function(...) stop("SECRET mapping")')
  for (injection in injections) expect_cli_error(cli_process(injection = injection), 4,
    "serialization_failed", "The analysis result could not be serialized.")
})

test_that("CLI leaves absent output parents absent and reports exit 4", {
  result <- cli_process(invalid_output = TRUE)
  expect_identical(result$status, 4L, info = result$stderr)
  expect_length(result$stdout, 0L)
  expect_null(result$text)
  expect_false(result$output_parent_created)
  expect_match(result$stderr, "output_write_failed", fixed = TRUE)
})

test_that("CLI handles dependency errors during module loading", {
  before <- 'adapter$sys.source <- function(file, envir, ...) { if (basename(file) == "mod_simulation.R") stop(structure(list(message = "SECRET package missing", call = quote(library(privatePackage))), class = c("packageNotFoundError", "error", "condition"))); base::sys.source(file, envir, ...) }'
  expect_cli_error(cli_process(before_source = before), 3,
    "dependency_unavailable", "A required analysis dependency is unavailable.")
  broken_source <- 'adapter$sys.source <- function(file, envir, ...) { if (basename(file) == "mod_pipeline.R") stop("SECRET source failure"); base::sys.source(file, envir, ...) }'
  expect_cli_error(cli_process(before_source = broken_source), 3,
    "analysis_failed", "The analysis could not be completed.")
})

test_that("headless CLI works with Shiny present and optional UI addons unavailable", {
  before <- c(
    'stopifnot(base::requireNamespace("shiny", quietly = TRUE))',
    'adapter$requireNamespace <- function(package, ...) if (package %in% c("shinyWidgets", "shinyAce")) FALSE else base::requireNamespace(package, ...)',
    'adapter$library <- function(package, ...) { name <- as.character(substitute(package)); if (name %in% c("shinyWidgets", "shinyAce")) stop(structure(list(message = paste("Missing optional UI package", name)), class = c("packageNotFoundError", "error", "condition"))); base::library(name, character.only = TRUE, ...) }')
  result <- cli_process(before_source = before)
  expect_identical(result$status, 0L, info = result$stderr)
  expect_identical(result$json$schema_version, "lmplot-analysis-result/1.0")
  expect_length(result$json$data, 30L)
  expect_length(result$stdout, 0L)
})

test_that("CLI handles request I/O and keeps original serialization diagnostics", {
  expect_cli_error(cli_process(missing_request = TRUE), 2,
    "invalid_request", "The analysis request is invalid.")
  result <- cli_process(injection = 'dependencies$result_to_contract <- function(...) stop(structure(list(message = "SECRET original", call = quote(original_call())), class = c("original_mapping_error", "error", "condition")))')
  expect_cli_error(result, 4, "serialization_failed", "The analysis result could not be serialized.")
  expect_match(result$stderr, "original_mapping_error", fixed = TRUE)
  expect_match(result$stderr, "original_call()", fixed = TRUE)
})

test_that("CLI exports real-data identity and GLMM unavailable intervals", {
  real <- cli_process(list(schema_version = "lmplot-analysis-request/1.0",
    data_source = "real", model_type = "lm_2d", example_id = "adelie_flipper_mass"))
  expect_identical(real$status, 0L, info = real$stderr)
  expect_identical(real$json$source, list(data_source = "real", example_id = "adelie_flipper_mass"))
  expect_length(real$json$data, 151L)
  payload <- cli_payload(); payload$model_type <- "glmm"; payload$simulation$n <- 60L
  mixed <- cli_process(payload)
  expect_identical(mixed$status, 0L, info = mixed$stderr)
  expect_identical(mixed$json$model_brain$prediction_modes, list("conditional", "population"))
  expect_null(mixed$json$coefficients[[1]]$conf_low)
  expect_null(mixed$json$coefficients[[1]]$conf_high)
  expect_null(mixed$json$coefficients[[1]]$p_value)
  expect_false(mixed$json$coefficients[[1]]$interval_available)
  expect_true(is.character(mixed$json$data[[1]]$Group))
  expect_true(is.character(mixed$json$prediction_grid[[1]]$Group))
  predicted <- unlist(mixed$json$fitted_values)
  observed <- vapply(mixed$json$data, `[[`, numeric(1), "Z")
  expect_equal(unlist(mixed$json$response_residuals), observed - predicted, tolerance = 1e-7)
})

test_that("CLI validates the Brain once and retains one-item arrays and factor text", {
  injection <- c(
    'original <- dependencies$create_services; validation_count <- 0L',
    'dependencies$create_services <- function() { s <- original(); validator <- s$validate_model_brain; s$validate_model_brain <- function(brain) { validation_count <<- validation_count + 1L; if (validation_count != 1L) stop("duplicate validation"); validator(brain) }; s }',
    'adapter$validate_model_brain <- function(...) stop("second Brain validation")',
    'original_run <- dependencies$run_usecase',
    'dependencies$run_usecase <- function(...) { r <- original_run(...); stopifnot(validation_count == 1L); r$data$Group <- factor(rep("alpha", nrow(r$data))); r$warnings <- "One warning"; r }',
    'for (key in c("new_request", "create_services", "run_usecase")) dependencies[[key]] <- local({ f <- dependencies[[key]]; calls <- 0L; function(...) { calls <<- calls + 1L; stopifnot(calls == 1L); f(...) } })')
  # Capture validator before replacing the global binding.
  injection[[2]] <- sub('validator <- s$validate_model_brain', 'validator <- original_validator', injection[[2]], fixed = TRUE)
  injection <- append(injection, 'original_validator <- adapter$validate_model_brain', after = 1L)
  result <- cli_process(injection = injection)
  expect_identical(result$status, 0L, info = result$stderr)
  expect_identical(result$json$warnings, list("One warning"))
  expect_identical(result$json$data[[1]]$Group, "alpha")
})

test_that("JSON sanitizer preserves row and array positions with explicit nulls", {
  env <- new.env(parent = globalenv())
  expect_true(file.exists(file.path(cli_root, "R", "json_contract.R")))
  if (!file.exists(file.path(cli_root, "R", "json_contract.R"))) return(invisible(NULL))
  sys.source(file.path(cli_root, "R", "json_contract.R"), env)
  value <- list(a = NaN, b = Inf, c = -Inf, d = 1.5, nums = c(2, NA, Inf, 4),
    matrix = matrix(c(1, NA, Inf, 4), nrow = 2, byrow = TRUE),
    rows = data.frame(x = c(NA, 2), group = factor(c("alpha", "beta"))),
    nested = list(text = NA_character_, flag = NA, raw = as.raw(c(1, 255))))
  result <- jsonlite::fromJSON(env$encode_json_contract(value), simplifyVector = FALSE)
  expect_identical(result[1:4], list(a = NULL, b = NULL, c = NULL, d = 1.5))
  expect_identical(result$nums, list(2L, NULL, NULL, 4L))
  expect_identical(result$matrix, list(list(1L, NULL), list(NULL, 4L)))
  expect_identical(result$rows, list(list(x = NULL, group = "alpha"), list(x = 2L, group = "beta")))
  expect_null(result$nested$text); expect_null(result$nested$flag)
  for (unsupported in list(new.env(), function() NULL, quote(x+y), as.complex(1))) {
    expect_error(env$sanitize_json_values(unsupported), class = "cli_serialization_error")
  }
})

test_that("atomic writer uses one replacement and never moves the old output aside", {
  env <- new.env(parent = globalenv())
  if (!file.exists(file.path(cli_root, "R", "json_contract.R"))) {
    fail("JSON writer does not exist"); return(invisible(NULL))
  }
  sys.source(file.path(cli_root, "R", "json_contract.R"), env)
  directory <- tempfile("atomic "); dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  path <- file.path(directory, "result.json")
  writeLines('{"previous":true}', path)
  expect_error(env$write_contract_atomically(list(value = new.env()), path), class = "cli_serialization_error")
  expect_identical(jsonlite::read_json(path), list(previous = TRUE))
  successful_attempts <- list()
  env$file.rename <- function(from, to) {
    successful_attempts[[length(successful_attempts) + 1L]] <<- list(
      existing = file.exists(to), same_directory = identical(dirname(from), dirname(to)))
    base::file.rename(from, to)
  }
  env$write_contract_atomically(list(next_value = 2), path)
  expect_identical(successful_attempts, list(list(existing = TRUE, same_directory = TRUE)))
  expect_identical(jsonlite::read_json(path), list(next_value = 2L))
  expect_identical(list.files(directory, all.files = TRUE, no.. = TRUE), "result.json")
  attempts <- list()
  env$file.rename <- function(from, to) {
    attempts[[length(attempts) + 1L]] <<- c(from, to)
    if (length(attempts) == 1L) return(FALSE)
    base::file.rename(from, to)
  }
  expect_error(env$write_contract_atomically(list(next_value = 3), path), class = "cli_output_error")
  expect_length(attempts, 1L)
  expect_identical(jsonlite::read_json(path), list(next_value = 2L))
  expect_identical(list.files(directory, all.files = TRUE, no.. = TRUE), "result.json")
  env$file.rename <- function(from, to) stop("Rename I/O error")
  expect_error(env$write_contract_atomically(list(next_value = 4), path),
    "Rename I/O error", class = "cli_output_error")
  expect_true(file.exists(path))
  if (file.exists(path)) expect_identical(jsonlite::read_json(path), list(next_value = 2L))
})
