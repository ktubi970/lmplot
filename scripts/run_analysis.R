#!/usr/bin/env Rscript
user_lib <- file.path(Sys.getenv("HOME"), "R_library")
if (dir.exists(user_lib)) {
  .libPaths(c(user_lib, .libPaths()))
}
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(user_lib, .libPaths()))
  install.packages("jsonlite", lib = user_lib, repos = "https://cloud.r-project.org/", quietly = TRUE)
}
if (!requireNamespace("lme4", quietly = TRUE)) {
  dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(user_lib, .libPaths()))
  try(install.packages("lme4", lib = user_lib, repos = "https://cloud.r-project.org/", quietly = TRUE), silent = TRUE)
}
suppressPackageStartupMessages({
  library(jsonlite)
})

app_root <- if (file.exists("R/config.R")) "." else ".."
source(file.path(app_root, "R", "config.R"), local = TRUE)
source(file.path(app_root, "R", "mod_model.R"), local = TRUE)
source(file.path(app_root, "R", "mod_simulation.R"), local = TRUE)
source(file.path(app_root, "R", "mod_visualization.R"), local = TRUE)
source(file.path(app_root, "R", "mod_examples.R"), local = TRUE)
source(file.path(app_root, "R", "mod_pipeline.R"), local = TRUE)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) {
  stop("Usage: Rscript scripts/run_analysis.R <request.json> <output.json>", call. = FALSE)
}

request_path <- args[1]
output_path <- args[2]

if (!file.exists(request_path)) {
  stop("Request file does not exist: ", request_path, call. = FALSE)
}

req <- jsonlite::fromJSON(request_path)

model_type <- req$model_type
link <- req$link
data_source <- req$data_source %||% "simulation"

analysis <- run_analysis_usecase(
  data_source = data_source,
  model_type = model_type,
  link = link,
  sim_params = req,
  example_id = req$example_id,
  grid_length_out = req$grid_length_out %||% 30L,
  root = app_root
)

result <- list(
  model_type = analysis$model_type,
  link = analysis$link,
  data_source = data_source,
  data = analysis$data,
  fitted = fitted_response(analysis$fit),
  residuals = response_residuals(analysis$fit),
  coefficients = analysis$coefficients,
  prediction_grid = analysis$prediction_grid,
  labels = analysis$labels,
  linearity_diag = analysis$linearity_diag
)

jsonlite::write_json(result, output_path, auto_unbox = TRUE, digits = 8)
