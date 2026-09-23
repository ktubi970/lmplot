# Public JSON boundary. Scientific validation belongs to the analysis use case.
CLI_ERROR_MESSAGES <- c(
  invalid_request = "The analysis request is invalid.",
  expert_not_trusted = "Expert mode requires a trusted local environment.",
  dependency_unavailable = "A required analysis dependency is unavailable.",
  analysis_failed = "The analysis could not be completed.",
  serialization_failed = "The analysis result could not be serialized.",
  output_write_failed = "The analysis result could not be written."
)

abort_cli <- function(class, cause) {
  if (inherits(cause, "condition")) {
    message <- conditionMessage(cause); call <- conditionCall(cause)
  } else {
    message <- as.character(cause); call <- NULL
  }
  stop(structure(list(message = message, call = call,
    cause = if (inherits(cause, "condition")) cause else NULL), class = c(class, "error", "condition")))
}

error_contract <- function(code, message) {
  list(schema_version = "lmplot-error/1.0", error = list(code = code, message = message))
}

# Only the fixed ASCII envelope is supported here, never arbitrary analysis data.
encode_error_contract <- function(contract) {
  code <- contract$error$code
  if (!identical(names(contract), c("schema_version", "error")) ||
      !identical(contract$schema_version, "lmplot-error/1.0") ||
      !identical(names(contract$error), c("code", "message")) ||
      !is.character(code) || length(code) != 1L || is.na(code) ||
      !code %in% names(CLI_ERROR_MESSAGES) ||
      !identical(contract$error$message, unname(CLI_ERROR_MESSAGES[[code]]))) {
    abort_cli("cli_serialization_error", "Unsupported fixed error envelope.")
  }
  escape <- function(x) {
    x <- gsub("\\", "\\\\", x, fixed = TRUE)
    gsub('"', '\\"', x, fixed = TRUE)
  }
  paste0('{"schema_version":"lmplot-error/1.0","error":{"code":"', escape(code),
    '","message":"', escape(contract$error$message), '"}}')
}

json_row_records <- function(value) {
  lapply(seq_len(nrow(value)), function(i) {
    stats::setNames(lapply(value, function(column) sanitize_json_values(column[[i]])), names(value))
  })
}

sanitize_json_values <- function(value) {
  if (is.null(value)) return(NULL)
  if (is.factor(value)) value <- as.character(value)
  if (is.data.frame(value)) return(json_row_records(value))
  if (is.matrix(value)) {
    return(lapply(seq_len(nrow(value)), function(i)
      lapply(seq_len(ncol(value)), function(j) sanitize_json_values(value[i, j]))))
  }
  if (is.object(value) || isS4(value) || !is.null(dim(value))) {
    abort_cli("cli_serialization_error", "Unsupported R object in JSON contract.")
  }
  if (is.list(value)) return(lapply(value, sanitize_json_values))
  if (!typeof(value) %in% c("integer", "double", "character", "logical", "raw")) {
    abort_cli("cli_serialization_error", "Unsupported R value in JSON contract.")
  }
  if (is.raw(value)) value <- as.integer(value)
  if (length(value) != 1L || !is.null(names(value))) {
    return(lapply(as.list(value), sanitize_json_values))
  }
  if (is.na(value) || (is.numeric(value) && !is.finite(value))) return(NULL)
  value
}

analysis_result_to_contract <- function(result) {
  fields <- c("data", "display", "example", "fit", "model_type", "link", "code", "labels",
    "metrics", "coefficients", "diagnostics", "prediction_grid", "warnings", "model_brain")
  if (!inherits(result, "analysis_result") || !all(fields %in% names(result)) ||
      is.null(result$model_brain) || !is.data.frame(result$data) || !is.data.frame(result$prediction_grid)) {
    abort_cli("cli_serialization_error", "A complete canonical analysis result is required.")
  }
  metrics <- result$metrics
  metrics$comparison_description <- attr(metrics, "comparison_description", exact = TRUE)
  # Arrays with one member must remain arrays under auto_unbox = TRUE.
  brain <- result$model_brain
  brain$prediction_modes <- unname(as.list(brain$prediction_modes))
  diagnostics <- result$diagnostics
  diagnostics$warnings <- unname(as.list(diagnostics$warnings))
  if (identical(diagnostics$strategy, "glmm")) {
    diagnostics$checks$optimizer_messages$value <- unname(as.list(diagnostics$checks$optimizer_messages$value))
    if (!is.null(diagnostics$checks$optimizer_code$value)) {
      diagnostics$checks$optimizer_code$value <- unname(as.list(diagnostics$checks$optimizer_code$value))
    }
  }
  list(schema_version = "lmplot-analysis-result/1.0",
    model = list(model_type = result$model_type, link = result$link),
    source = list(data_source = if (is.null(result$example)) "simulation" else "real",
      example_id = if (is.null(result$example)) NULL else result$example$id),
    labels = result$labels, data = json_row_records(result$data),
    fitted_values = as.list(as.numeric(fitted_response(result$fit))),
    response_residuals = as.list(as.numeric(response_residuals(result$fit))),
    metrics = metrics, coefficients = result$coefficients, diagnostics = diagnostics,
    warnings = unname(as.list(as.character(result$warnings))),
    prediction_grid = json_row_records(result$prediction_grid), model_brain = brain)
}

encode_json_contract <- function(value) {
  tryCatch({
    if (!requireNamespace("jsonlite", quietly = TRUE)) {
      abort_cli("cli_serialization_error", "The jsonlite package is unavailable.")
    }
    as.character(jsonlite::toJSON(sanitize_json_values(value), auto_unbox = TRUE,
      null = "null", na = "null", digits = NA))
  }, error = function(e) abort_cli("cli_serialization_error", e))
}

write_contract_atomically <- function(contract, output_path, encode_json = encode_json_contract) {
  # Serialize before opening any file, including the sibling temporary file.
  json <- tryCatch(encode_json(contract), error = function(e) abort_cli("cli_serialization_error", e))
  if (!is.character(json) || length(json) != 1L || is.na(json)) {
    abort_cli("cli_serialization_error", "JSON encoder must return one string.")
  }
  if (!is.character(output_path) || length(output_path) != 1L || is.na(output_path) ||
      !nzchar(output_path) || !dir.exists(dirname(output_path)) || dir.exists(output_path)) {
    abort_cli("cli_output_error", "Output must name a file in an existing directory.")
  }
  temporary <- tempfile(".lmplot-", tmpdir = dirname(output_path), fileext = ".tmp")
  on.exit(if (file.exists(temporary)) unlink(temporary), add = TRUE)
  tryCatch({
    connection <- file(temporary, open = "wb")
    tryCatch({
      writeBin(charToRaw(enc2utf8(json)), connection)
      flush(connection)
    }, finally = close(connection))
    # R uses MoveFileExW(REPLACE_EXISTING) on Windows and rename() on POSIX.
    # Siblings stay on the same filesystem. Never move the old name out of the way.
    if (!file.rename(temporary, output_path)) {
      abort_cli("cli_output_error", "Output replacement failed; prior result was not moved.")
    }
    invisible(output_path)
  }, error = function(e) abort_cli("cli_output_error", e))
}
