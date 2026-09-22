# Module Pipeline - Factory / Dependency Injection & Service Layer / Use Case

`%||%` <- function(left, right) if (is.null(left) || length(left) == 0L) right else left

#' Create an Analysis Pipeline (Factory / Dependency Injection)
#'
#' Encapsulates model fitting, prediction, KPI extraction, diagnostics, and grid generation.
#' Any step can be substituted via dependency injection (e.g. for testing with mocks).
#'
#' @param fit_fn Function(df, model_type, link) -> model fit
#' @param predict_fn Function(fit, newdata, population) -> numeric vector
#' @param kpis_fn Function(fit, model_type) -> list of KPIs
#' @param coef_fn Function(fit) -> data.frame of coefficients
#' @param diag_fn Function(fit, df, model_type) -> list with linearity diagnostics
#' @param grid_fn Function(df, fit, model_type) -> data.frame prediction grid
#' @return A list with the injected pipeline closures
create_analysis_pipeline <- function(
  fit_fn = fit_model,
  predict_fn = predict_response,
  kpis_fn = extract_model_kpis,
  coef_fn = extract_coefficient_table,
  diag_fn = diagnose_model_linearity,
  grid_fn = prediction_grid
) {
  list(
    fit = fit_fn,
    predict = predict_fn,
    kpis = kpis_fn,
    coefficients = coef_fn,
    diagnostics = diag_fn,
    grid = grid_fn
  )
}

#' Default production analysis pipeline
#'
#' @return Default analysis pipeline using project functions
default_analysis_pipeline <- function() {
  create_analysis_pipeline()
}

#' Execute Model Analysis Use Case (Service Layer)
#'
#' Orchestrates data preparation (simulation or real dataset), model fitting via pipeline,
#' and extraction of diagnostics, metrics, grid and reproducible R code.
#'
#' @param data_source "simulation" or "real"
#' @param model_type Supported model identifier (e.g. "lm_2d", "glm_binomial", etc.)
#' @param link Model link function (optional, defaults to model default)
#' @param sim_params List of parameters for simulation (when data_source == "simulation")
#' @param sim_result Optional pre-computed simulation result from sim_server (Shiny)
#' @param example_id Optional example ID (when data_source == "real")
#' @param grid_length_out Optional resolution for prediction grid
#' @param root Project root directory path
#' @param pipeline Pipeline instance created by create_analysis_pipeline()
#' @return Structured "analysis_result" list
run_analysis_usecase <- function(
  data_source = c("simulation", "real"),
  model_type,
  link = NULL,
  sim_params = list(),
  sim_result = NULL,
  example_id = NULL,
  grid_length_out = NULL,
  root = ".",
  pipeline = default_analysis_pipeline()
) {
  data_source <- match.arg(data_source)
  config <- model_config(model_type)
  link <- validate_model_link(model_type, link)

  if (identical(data_source, "real")) {
    resolved_id <- example_id %||% example_for_model(model_type, root = root)
    example <- load_real_example(resolved_id, root = root)
    data <- example$analysis
    display <- example$display
    labels <- list(
      x = example$metadata$predictor_x_label %||% "X",
      y = example$metadata$predictor_y_label %||% "Y",
      z = example$metadata$response_label %||% "Z"
    )
    code <- paste0(
      "example <- load_real_example(\"",
      example$id,
      "\")\n",
      "fit <- fit_model(example$analysis, \"",
      model_type,
      "\", \"",
      link,
      "\")"
    )
  } else {
    example <- NULL
    labels <- list(x = "X", y = "Y", z = "Z")

    if (!is.null(sim_result) && is.list(sim_result) && "data" %in% names(sim_result)) {
      data <- sim_result$data
      display <- if (!is.null(sim_result$display)) sim_result$display else data
      code <- sim_result$code %||% ""
    } else {
      is_expert <- isTRUE(sim_params$expert_mode)

      if (is_expert) {
        expert_code <- sim_params$expert_code %||% ""
        data <- evaluate_expert_simulation(
          expert_code,
          model_type,
          sim_params$seed %||% 123L
        )
        code <- expert_code
      } else {
        data <- simulate_data(
          model_type = model_type,
          link = link,
          n = sim_params$n %||% 200L,
          seed = sim_params$seed %||% 123L,
          beta0 = sim_params$beta0 %||% 2,
          beta1 = sim_params$beta1 %||% 0.5,
          beta2 = sim_params$beta2 %||% -0.25,
          sigma = sim_params$sigma %||% 1,
          shape = sim_params$shape %||% 2,
          group_sd = sim_params$group_sd %||% 1,
          groups = sim_params$groups %||% 5L,
          pattern = sim_params$pattern %||% "linear"
        )
        code <- simulation_code(model_type, link, sim_params)
      }
      display <- data
    }
  }

  fit <- pipeline$fit(data, model_type, link)
  kpis <- pipeline$kpis(fit, model_type)
  coef_df <- pipeline$coefficients(fit)
  diag <- pipeline$diagnostics(fit, df = data, model_type = model_type)
  grid <- if (!is.null(grid_length_out)) {
    pipeline$grid(data, fit, model_type, length_out = grid_length_out)
  } else {
    pipeline$grid(data, fit, model_type)
  }

  structure(
    list(
      data = data,
      display = display,
      example = example,
      fit = fit,
      model_type = model_type,
      link = link,
      code = code,
      labels = labels,
      kpis = kpis,
      coefficients = coef_df,
      linearity_diag = diag,
      prediction_grid = grid
    ),
    class = "analysis_result"
  )
}

#' S3 Print Method for analysis_result
#'
#' @param x An object of class analysis_result
#' @param ... Additional arguments (unused)
#' @return The object invisibly
#' @export
print.analysis_result <- function(x, ...) {
  source_label <- if (!is.null(x$example)) paste0("real:", x$example$id) else "simulation"
  cat(
    "<AnalysisResult: ", x$model_type,
    " (link = ", x$link,
    ", source = ", source_label,
    ") - N = ", nrow(x$data), " obs>\n",
    sep = ""
  )
  invisible(x)
}

