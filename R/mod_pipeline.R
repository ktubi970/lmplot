abort_analysis_request <- function(message, code = "invalid_request", class = "analysis_request_error") {
  stop(structure(list(message = message, code = code),
    class = c(class, "analysis_request_error", "error", "condition")))
}

analysis_character_scalar <- function(x) {
  is.character(x) && is.null(attributes(x)) && length(x) == 1L && !is.na(x) && nzchar(x)
}

analysis_object <- function(x, allowed, required = character()) {
  keys <- names(x)
  if (!is.list(x) || is.pairlist(x) || is.data.frame(x) || is.null(keys) || anyNA(keys) ||
      any(!nzchar(keys)) || anyDuplicated(keys) ||
      any(!keys %in% allowed) || any(!required %in% keys)) {
    abort_analysis_request("Analysis object has invalid fields.")
  }
  invisible(x)
}

analysis_number <- function(x, minimum, maximum, whole = FALSE) {
  if (!is.numeric(x) || !is.null(attributes(x)) || length(x) != 1L ||
      is.na(x) || !is.finite(x) || x < minimum || x > maximum ||
      (whole && x != floor(x))) {
    abort_analysis_request("Analysis numeric parameter is invalid.")
  }
  if (whole) as.integer(x) else x
}

analysis_request_fields <- function() {
  c("schema_version", "data_source", "model_type", "link", "grid_length_out",
    "example_id", "simulation", "expert")
}

new_analysis_request <- function(payload, trusted_local = FALSE) {
  analysis_object(payload, analysis_request_fields(), c("schema_version", "data_source", "model_type"))
  for (key in c("schema_version", "data_source", "model_type")) {
    if (!analysis_character_scalar(payload[[key]])) abort_analysis_request("Analysis scalar field is invalid.")
  }
  if (payload$schema_version != "lmplot-analysis-request/1.0") abort_analysis_request("Unsupported analysis schema version.")
  if (!payload$data_source %in% c("simulation", "real")) abort_analysis_request("Unsupported analysis data source.")
  if (!payload$model_type %in% model_ids()) abort_analysis_request("Unsupported analysis model type.")
  link <- payload[["link"]]
  if (!is.null(link) && !analysis_character_scalar(link)) abort_analysis_request("Analysis link is invalid.")
  link <- tryCatch(validate_model_link(payload$model_type, link),
    error = function(e) abort_analysis_request("Analysis model and link are incompatible."))
  grid <- payload[["grid_length_out"]]
  if (is.null(grid)) grid <- 30L
  grid <- analysis_number(grid, 2, 200, TRUE)
  simulation <- expert <- example_id <- NULL
  if (payload$data_source == "real") {
    if (any(c("simulation", "expert") %in% names(payload))) abort_analysis_request("Real analysis cannot contain simulation or Expert fields.")
    example_id <- payload[["example_id"]]
    if (!is.null(example_id) && !analysis_character_scalar(example_id)) abort_analysis_request("Analysis example identifier is invalid.")
  } else {
    if ("example_id" %in% names(payload)) abort_analysis_request("Simulation analysis cannot contain an example identifier.")
    defaults <- list(n = 200L, seed = 123L, beta0 = 2, beta1 = .5, beta2 = -.25,
      sigma = 1, shape = 2, group_sd = 1, groups = 5L, pattern = "linear")
    simulation <- payload[["simulation"]]
    if (is.null(simulation)) simulation <- defaults
    analysis_object(simulation, names(defaults))
    for (key in setdiff(names(defaults), names(simulation))) simulation[key] <- defaults[key]
    simulation <- simulation[names(defaults)]
    bounds <- list(n = c(10, 2000), seed = c(0, .Machine$integer.max),
      beta0 = c(-3, 5), beta1 = c(-2, 2), beta2 = c(-2, 2), sigma = c(.1, 5),
      shape = c(.5, 10), group_sd = c(0, 4), groups = c(5, 20))
    for (key in names(bounds)) {
      simulation[[key]] <- analysis_number(simulation[[key]], bounds[[key]][1],
        bounds[[key]][2], key %in% c("n", "seed", "groups"))
    }
    if (simulation$groups > simulation$n) abort_analysis_request("Simulation groups must not exceed sample size.")
    if (!analysis_character_scalar(simulation$pattern) ||
        !simulation$pattern %in% c("linear", "quadratic", "cosine", "heteroscedastic")) {
      abort_analysis_request("Analysis simulation pattern is invalid.")
    }
    expert <- payload[["expert"]]
    if (is.null(expert)) expert <- list(enabled = FALSE, code = NULL)
    analysis_object(expert, c("enabled", "code"), c("enabled", "code"))
    if (!is.logical(expert$enabled) || !is.null(attributes(expert$enabled)) ||
        length(expert$enabled) != 1L || is.na(expert$enabled)) abort_analysis_request("Expert enabled must be a logical scalar.")
    if (expert$enabled) {
      if (!analysis_character_scalar(expert$code) || !nzchar(trimws(expert$code))) abort_analysis_request("Expert code must be non-empty.")
      if (!identical(trusted_local, TRUE)) abort_analysis_request(
        "Expert mode requires a trusted local environment.", "expert_not_trusted", "analysis_security_error")
    } else if (!is.null(expert$code)) abort_analysis_request("Disabled Expert mode cannot contain code.")
    expert <- expert[c("enabled", "code")]
  }
  structure(list(schema_version = "lmplot-analysis-request/1.0", data_source = payload$data_source,
    model_type = payload$model_type, link = link, grid_length_out = grid,
    example_id = example_id, simulation = simulation, expert = expert),
    class = c("analysis_request", "list"), trusted_local = isTRUE(trusted_local))
}

abort_analysis_service <- function(name) {
  stop(structure(list(message = paste0("Analysis service '", name, "' must be callable."),
    code = "invalid_service"), class = c("analysis_service_error", "error", "condition")))
}

create_analysis_services <- function(load_example = load_real_example, simulate = simulate_data,
    evaluate_expert = evaluate_expert_simulation, fit = fit_model, metrics = extract_model_metrics,
    coefficients = extract_coefficient_table, diagnostics = diagnose_model,
    prediction_grid = prediction_grid, build_model_brain = build_model_brain,
    resolve_example = example_for_model) {
  # Resolve same-name defaults in the factory's enclosing environment, not its promise frame.
  if (missing(prediction_grid)) prediction_grid <- tryCatch(
    get("prediction_grid", envir = environment(create_analysis_services)), error = function(e) NULL)
  if (missing(build_model_brain)) build_model_brain <- tryCatch(
    get("build_model_brain", envir = environment(create_analysis_services)), error = function(e) NULL)
  keys <- c("load_example", "simulate", "evaluate_expert", "fit", "metrics", "coefficients",
    "diagnostics", "prediction_grid", "build_model_brain", "resolve_example")
  frame <- environment()
  services <- lapply(keys, function(key) {
    dependency <- tryCatch(get(key, envir = frame), error = function(e) NULL)
    if (!is.function(dependency)) abort_analysis_service(key)
    dependency
  })
  structure(stats::setNames(services, keys), class = c("analysis_services", "list"))
}

validate_analysis_boundary <- function(request, services, root) {
  if (!inherits(request, "analysis_request") || !identical(names(request), analysis_request_fields())) {
    abort_analysis_request("A canonical analysis request is required.")
  }
  payload <- unclass(request)
  attributes(payload) <- list(names = names(request))
  if (identical(payload$data_source, "real")) {
    if (!is.null(payload$simulation) || !is.null(payload$expert)) abort_analysis_request("Real analysis cannot contain simulation or Expert fields.")
    payload[c("simulation", "expert")] <- NULL
  } else {
    if (!is.null(payload$example_id)) abort_analysis_request("Simulation analysis cannot contain an example identifier.")
    payload["example_id"] <- NULL
  }
  canonical <- new_analysis_request(payload, attr(request, "trusted_local", exact = TRUE))
  if (!identical(request, canonical)) abort_analysis_request("Analysis request was changed after validation.")
  expected <- names(formals(create_analysis_services))
  if (!inherits(services, "analysis_services") || !identical(names(services), expected)) abort_analysis_service("services")
  for (key in expected) if (!is.function(services[[key]])) abort_analysis_service(key)
  if (!analysis_character_scalar(root)) abort_analysis_request("Analysis root must be a non-empty path.")
  invisible(request)
}

run_analysis_usecase <- function(request, services, root = ".") {
  validate_analysis_boundary(request, services, root)
  warnings <- character()
  collect <- function(values) {
    warnings <<- unique(c(warnings, values))
  }
  withCallingHandlers({
    model_type <- request$model_type
    link <- request$link
    example <- NULL
    labels <- list(x = "X", y = "Y", z = "Z")
    if (request$data_source == "real") {
      id <- request$example_id %||% services$resolve_example(model_type, root)
      example <- services$load_example(id, root)
      if (!is.list(example) || !is.data.frame(example$analysis) || !is.data.frame(example$display) ||
          !is.list(example$metadata) || !identical(example$metadata$model_type, model_type) ||
          !analysis_character_scalar(example$id)) abort_analysis_request("Analysis example is invalid or belongs to another model.")
      data <- example$analysis
      display <- example$display
      labels <- list(x = example$metadata$predictor_x_label %||% "X",
        y = example$metadata$predictor_y_label %||% "Y", z = example$metadata$response_label %||% "Z")
      code <- paste0("example <- load_real_example(", encodeString(example$id, quote = '"'),
        ")\nfit <- fit_model(example$analysis, ", encodeString(model_type, quote = '"'),
        ", ", encodeString(link, quote = '"'), ")")
    } else {
      if (request$expert$enabled) {
        if (!isTRUE(attr(request, "trusted_local", exact = TRUE))) abort_analysis_request(
          "Expert mode requires a trusted local environment.", "expert_not_trusted", "analysis_security_error")
        data <- services$evaluate_expert(request$expert$code, request$simulation, model_type, link)
        code <- request$expert$code
      } else {
        data <- do.call(services$simulate, c(list(model_type = model_type, link = link), request$simulation))
        code <- simulation_code(model_type, link, request$simulation)
      }
      display <- data
    }
    fit <- services$fit(data, model_type, link)
    collect(attr(fit, "model_fit_warnings", exact = TRUE) %||% character())
    metrics <- services$metrics(fit, model_type, data)
    coefficients <- services$coefficients(fit, model_type, link)
    diagnostics <- services$diagnostics(fit, data, model_type)
    collect(diagnostics$warnings %||% character())
    grid <- services$prediction_grid(data, fit, model_type, length_out = request$grid_length_out)
    structure(list(data = data, display = display, example = example, fit = fit,
      model_type = model_type, link = link, code = code, labels = labels,
      metrics = metrics, coefficients = coefficients, diagnostics = diagnostics,
      prediction_grid = grid, warnings = warnings), class = "analysis_result")
  }, warning = function(warning) {
    collect(conditionMessage(warning))
    if (!is.null(findRestart("muffleWarning"))) invokeRestart("muffleWarning")
  })
}

print.analysis_result <- function(x, ...) {
  source_label <- if (!is.null(x$example)) paste0("real:", x$example$id) else "simulation"
  cat("<AnalysisResult: ", x$model_type, " (link = ", x$link, ", source = ",
    source_label, ") - N = ", nrow(x$data), " obs>\n", sep = "")
  invisible(x)
}
