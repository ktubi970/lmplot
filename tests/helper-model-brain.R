.model_brain_find_root <- function() {
  source_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  starts <- unique(c(
    if (!is.null(source_file)) dirname(normalizePath(source_file, mustWork = FALSE)),
    getwd()
  ))

  for (start in starts) {
    candidate <- normalizePath(start, winslash = "/", mustWork = FALSE)
    repeat {
      if (file.exists(file.path(candidate, "R", "config.R")) &&
          file.exists(file.path(candidate, "R", "mod_model.R")) &&
          file.exists(file.path(candidate, "R", "mod_simulation.R"))) {
        return(candidate)
      }
      parent <- dirname(candidate)
      if (identical(parent, candidate)) break
      candidate <- parent
    }
  }

  stop("Could not locate the lmplot repository root", call. = FALSE)
}

.model_brain_root <- .model_brain_find_root()
.model_brain_source <- function(path) {
  source(file.path(.model_brain_root, "R", path), local = parent.frame())
}

if (!exists("MODEL_REGISTRY", inherits = TRUE)) .model_brain_source("config.R")
if (!exists("MODEL_REGISTRY", inherits = TRUE)) .model_brain_source("mod_model.R")
if (!exists("simulate_data", inherits = TRUE)) .model_brain_source("mod_simulation.R")

.model_brain_registry_matrix <- do.call(rbind, lapply(names(MODEL_REGISTRY), function(id) {
  data.frame(
    model_type = id,
    link = MODEL_REGISTRY[[id]]$links,
    stringsAsFactors = FALSE
  )
}))

model_brain_cases <- function() {
  .model_brain_registry_matrix
}

fit_model_brain_case <- function(case, n = 80L, seed = 42L) {
  if (!is.data.frame(case) || nrow(case) < 1L ||
      !all(c("model_type", "link") %in% names(case))) {
    stop("case must contain model_type and link columns", call. = FALSE)
  }

  model_type <- as.character(case$model_type[[1L]])
  link <- as.character(case$link[[1L]])
  data <- simulate_data(
    model_type = model_type,
    link = link,
    n = n,
    seed = seed,
    groups = 5L
  )
  fit <- fit_model(data, model_type = model_type, link = link)

  list(
    model_type = model_type,
    link = link,
    data = data,
    fit = fit
  )
}
