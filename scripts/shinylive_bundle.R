# Build boundary: only these reviewed runtime files may enter the public site.
shinylive_paths_in_root <- function(paths, root,
    case_insensitive = .Platform$OS.type == "windows") {
  prefix <- paste0(root, "/")
  if (case_insensitive) {
    paths <- tolower(paths)
    prefix <- tolower(prefix)
  }
  startsWith(paths, prefix)
}

stage_shinylive_app <- function(root, stage) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  if (file.exists(stage) && (!dir.exists(stage) ||
      length(list.files(stage, all.files = TRUE, no.. = TRUE)))) {
    stop("Staging destination must be empty or not exist.", call. = FALSE)
  }
  manifest <- utils::read.csv(file.path(root, "data", "real", "manifest.csv"),
                             stringsAsFactors = FALSE)
  ids <- manifest$example_id
  if (!length(ids) || anyNA(ids) || anyDuplicated(ids) ||
      any(!grepl("^[a-z][a-z0-9_]*$", ids))) {
    stop("Invalid example IDs in public bundle manifest.", call. = FALSE)
  }
  runtime <- c(
    "config.R", "model_registry.R", "mod_model.R", "model_metrics.R",
    "model_diagnostics.R", "mod_simulation.R", "mod_examples.R",
    "mod_visualization.R", "mod_model_brain.R", "model_brain_plots.R",
    "mod_model_brain_ui.R", "mod_pipeline.R", "mod_eli5.R",
    "app_coordinator.R", "mod_configuration.R", "mod_overview.R",
    "mod_diagnostics.R", "mod_data_provenance.R", "browser_compatibility.R"
  )
  files <- c("app.R", file.path("R", runtime), "www/style.css",
             "data/real/manifest.csv", "data/real/NOTICE.md",
             file.path("data", "real", ids, "model-data.csv"),
             file.path("data", "real", ids, "README.md"))
  source_paths <- file.path(root, files)
  missing <- files[!file.exists(source_paths) | dir.exists(source_paths)]
  if (length(missing)) {
    stop("Missing required runtime files: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  # Resolve symlinks/junctions before copying: an allowed name is not enough.
  real_paths <- as.character(fs::path_real(source_paths))
  real_root <- as.character(fs::path_real(root))
  if (any(!shinylive_paths_in_root(real_paths, real_root))) {
    stop("Runtime files must resolve inside the application root.", call. = FALSE)
  }
  dir.create(stage, recursive = TRUE, showWarnings = FALSE)
  for (i in seq_along(files)) {
    target <- file.path(stage, files[i])
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(source_paths[i], target, overwrite = FALSE)) {
      stop("Failed to stage runtime file: ", files[i], call. = FALSE)
    }
  }
  normalizePath(stage, winslash = "/", mustWork = TRUE)
}
