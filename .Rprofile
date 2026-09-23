local({
  # The generated renv activator downloads renv when the project library is
  # absent. Only an explicit bootstrap/build process may take that path.
  if (identical(Sys.getenv("LMPLOT_EXPLICIT_BOOTSTRAP"), "1")) {
    source("renv/activate.R")
    return(invisible())
  }

  project <- getwd()
  library_root <- Sys.getenv("RENV_PATHS_LIBRARY",
    unset = file.path(project, "renv", "library"))
  platform_dirs <- if (dir.exists(library_root)) {
    list.dirs(library_root, recursive = FALSE, full.names = TRUE)
  } else character()
  r_minor <- paste(R.version$major,
    strsplit(R.version$minor, ".", fixed = TRUE)[[1L]][[1L]], sep = ".")
  candidates <- file.path(platform_dirs, paste0("R-", r_minor), R.version$platform)
  candidates <- candidates[file.exists(file.path(candidates, "renv", "DESCRIPTION"))]

  loaded <- FALSE
  for (library in candidates) {
    if (!requireNamespace("renv", lib.loc = library, quietly = TRUE)) next
    expected <- tryCatch(renv::paths$library(project = project),
      error = function(e) "")
    if (!identical(normalizePath(library, winslash = "/", mustWork = FALSE),
                   normalizePath(expected, winslash = "/", mustWork = FALSE))) next
    loaded <- tryCatch({
      renv::load(project = project)
      TRUE
    }, error = function(e) {
      message(conditionMessage(e))
      FALSE
    })
    if (loaded) break
  }

  options(lmplot.renv_unavailable = !loaded)
  if (!loaded) {
    message("Restore dependencies explicitly with Rscript --vanilla scripts/bootstrap.R.")
  }
})
