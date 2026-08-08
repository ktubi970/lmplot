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
suppressPackageStartupMessages({
  library(jsonlite)
})

app_root <- if (file.exists("R/config.R")) "." else ".."
source(file.path(app_root, "R", "config.R"), local = TRUE)
source(file.path(app_root, "R", "mod_model.R"), local = TRUE)
source(file.path(app_root, "R", "mod_simulation.R"), local = TRUE)
source(file.path(app_root, "R", "mod_visualization.R"), local = TRUE)
source(file.path(app_root, "R", "mod_examples.R"), local = TRUE)

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

if (data_source == "real") {
  example_id <- req$example_id %||% example_for_model(model_type, root = app_root)
  example <- load_real_example(example_id, root = app_root)
  df <- example$analysis
  labels <- list(
    x = example$metadata$predictor_x_label %||% "X",
    y = example$metadata$predictor_y_label %||% "Y",
    z = example$metadata$response_label %||% "Z"
  )
} else {
  n <- as.integer(req$n %||% 100L)
  seed <- as.integer(req$seed %||% 42L)
  beta0 <- as.numeric(req$beta0 %||% 2)
  beta1 <- as.numeric(req$beta1 %||% 0.5)
  beta2 <- as.numeric(req$beta2 %||% -0.25)
  sigma <- as.numeric(req$sigma %||% 1)
  shape <- as.numeric(req$shape %||% 2)
  group_sd <- as.numeric(req$group_sd %||% 1)
  groups <- as.integer(req$groups %||% 5L)

  df <- simulate_data(
    model_type = model_type,
    link = link,
    n = n,
    seed = seed,
    beta0 = beta0,
    beta1 = beta1,
    beta2 = beta2,
    sigma = sigma,
    shape = shape,
    group_sd = group_sd,
    groups = groups
  )
  labels <- list(x = "X", y = "Y", z = "Z")
}

fit <- fit_model(df, model_type, link)
grid <- prediction_grid(df, fit, model_type, length_out = 30L)
fitted <- fitted_response(fit)
residuals <- response_residuals(fit)

coef_matrix <- summary(fit)$coefficients
coef_df <- as.data.frame(coef_matrix)
coef_df$term <- rownames(coef_matrix)

result <- list(
  model_type = model_type,
  link = validate_model_link(model_type, link),
  data_source = data_source,
  data = df,
  fitted = fitted,
  residuals = residuals,
  coefficients = coef_df,
  prediction_grid = grid,
  labels = labels
)

jsonlite::write_json(result, output_path, auto_unbox = TRUE, digits = 8)
