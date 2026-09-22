#!/usr/bin/env Rscript
if (identical(environment(), globalenv()) && length(commandArgs(trailingOnly = TRUE)) != 2L) {
  cat("The analysis request is invalid.\n", file = stderr())
  quit(status = 2L)
}

# Resolve the adapter itself, including sys.source() drivers outside the project.
cli_script_path <- function() {
  for (frame in rev(sys.frames())) {
    for (key in c("ofile", "file")) {
      path <- frame[[key]]
      if (is.character(path) && length(path) == 1L &&
          identical(basename(path), "run_analysis.R") && file.exists(path)) {
        return(normalizePath(path, winslash = "/", mustWork = TRUE))
      }
    }
  }
  arg <- grep("^--file=", commandArgs(), value = TRUE)
  if (length(arg) != 1L) stop("Cannot locate the analysis adapter.")
  normalizePath(sub("^--file=", "", arg), winslash = "/", mustWork = TRUE)
}

app_root <- dirname(dirname(cli_script_path()))
cli_bootstrap_error <- NULL
for (module in c("config", "model_registry", "mod_model", "model_metrics",
    "model_diagnostics", "mod_simulation", "mod_visualization", "mod_examples",
    "mod_model_brain", "mod_pipeline", "json_contract")) {
  tryCatch(sys.source(file.path(app_root, "R", paste0(module, ".R")), envir = environment()),
    error = function(e) {
      if (is.null(cli_bootstrap_error)) cli_bootstrap_error <<- e
    })
}

decode_cli_request <- function(path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    abort_analysis_dependency("The jsonlite package is unavailable.")
  }
  content <- tryCatch(readLines(path, warn = FALSE, encoding = "UTF-8"),
    error = function(e) abort_cli("cli_request_io_error", e))
  tryCatch(jsonlite::fromJSON(paste(content, collapse = "\n"), simplifyVector = FALSE),
    error = function(e) abort_cli("cli_json_parse_error", e))
}

default_cli_dependencies <- function() {
  list(decode_json = decode_cli_request,
    new_request = function(payload, trusted_local) {
      if (!is.null(cli_bootstrap_error)) {
        if (inherits(cli_bootstrap_error, "packageNotFoundError")) {
          abort_cli("analysis_dependency_error", cli_bootstrap_error)
        }
        stop(cli_bootstrap_error)
      }
      new_analysis_request(payload, trusted_local = trusted_local)
    }, create_services = function() create_analysis_services(),
    run_usecase = function(...) run_analysis_usecase(...),
    result_to_contract = analysis_result_to_contract, encode_json = encode_json_contract,
    write_contract = write_contract_atomically)
}

cli_diagnostic <- function(error, code) {
  call <- conditionCall(error)
  cat(code, " [", paste(class(error), collapse = ", "), "]: ",
    conditionMessage(error), if (!is.null(call)) paste0("\nCall: ", paste(deparse(call), collapse = " ")),
    "\n", sep = "", file = stderr())
  if (inherits(error$cause, "condition")) cli_diagnostic(error$cause, code)
}

classify_cli_error <- function(error) {
  if (inherits(error, "analysis_security_error")) return(list(status = 2L, code = "expert_not_trusted"))
  if (inherits(error, c("cli_usage_error", "cli_request_io_error", "cli_json_parse_error", "analysis_request_error"))) {
    return(list(status = 2L, code = "invalid_request"))
  }
  if (inherits(error, c("analysis_dependency_error", "analysis_service_error"))) {
    return(list(status = 3L, code = "dependency_unavailable"))
  }
  if (inherits(error, "cli_serialization_error")) return(list(status = 4L, code = "serialization_failed"))
  if (inherits(error, "cli_output_error")) return(list(status = 4L, code = "output_write_failed"))
  list(status = 3L, code = "analysis_failed")
}

run_analysis_cli <- function(args, dependencies = default_cli_dependencies()) {
  if (length(args) != 2L) {
    cat(CLI_ERROR_MESSAGES[["invalid_request"]], "\n", sep = "", file = stderr())
    return(2L)
  }
  tryCatch({
    payload <- dependencies$decode_json(args[[1]])
    request <- dependencies$new_request(payload, trusted_local = FALSE)
    services <- dependencies$create_services()
    result <- dependencies$run_usecase(request, services, root = app_root)
    contract <- tryCatch(dependencies$result_to_contract(result),
      error = function(e) abort_cli("cli_serialization_error", e))
    dependencies$write_contract(contract, args[[2]], encode_json = dependencies$encode_json)
    0L
  }, error = function(error) {
    classified <- classify_cli_error(error)
    cli_diagnostic(error, classified$code)
    contract <- error_contract(classified$code, CLI_ERROR_MESSAGES[[classified$code]])
    # Fixed envelopes remain writable if jsonlite or an injected encoder is unavailable.
    error_encoder <- function(value) tryCatch(dependencies$encode_json(value),
      error = function(e) {
        cli_diagnostic(e, "serialization_failed")
        encode_error_contract(value)
      })
    tryCatch({
      dependencies$write_contract(contract, args[[2]], encode_json = error_encoder)
      classified$status
    }, error = function(output_error) {
      cli_diagnostic(output_error, "output_write_failed")
      4L
    })
  })
}

if (identical(environment(), globalenv())) {
  quit(status = run_analysis_cli(commandArgs(trailingOnly = TRUE)))
}
