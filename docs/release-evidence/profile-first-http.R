main <- function() {
  root <- normalizePath(".", winslash = "/")
  evidence <- normalizePath("docs/release-evidence", winslash = "/")
  port <- httpuv::randomPort()
  process <- callr::r_bg(function(root, evidence, port) {
    setwd(root)
    Sys.unsetenv("LMPLOT_TRUSTED_LOCAL")
    options(sass.cache = tempfile("lmplot-sass-cold-"))
    cat("COLD_SASS_CACHE", getOption("sass.cache"), "\n")
    .GlobalEnv$http_profile_index <- 0L
    .GlobalEnv$http_profile_dir <- evidence
    trace("renderPage", where = asNamespace("shiny"), print = FALSE,
      tracer = quote({
        .GlobalEnv$http_profile_index <- .GlobalEnv$http_profile_index + 1L
        .GlobalEnv$http_profile_started <- proc.time()[["elapsed"]]
        cat("RENDER_START", .GlobalEnv$http_profile_index,
          format(Sys.time(), "%H:%M:%OS3"), "\n")
        Rprof(file.path(.GlobalEnv$http_profile_dir,
          paste0("first-http-", .GlobalEnv$http_profile_index, ".Rprof")), interval = .01)
      }), exit = quote({
        Rprof(NULL)
        cat("RENDER_END", .GlobalEnv$http_profile_index,
          proc.time()[["elapsed"]] - .GlobalEnv$http_profile_started, "\n")
      }))
    trace("sass_compile_theme", where = asNamespace("bslib"), print = FALSE,
      tracer = quote(cat("SASS_THEME_START", format(Sys.time(), "%H:%M:%OS3"), "\n")),
      exit = quote(cat("SASS_THEME_END", format(Sys.time(), "%H:%M:%OS3"), "\n")))
    shiny::runApp(root, host = "127.0.0.1", port = port, launch.browser = FALSE)
  }, args = list(root, evidence, port), stdout = "|", stderr = "|")
  on.exit(if (process$is_alive()) process$kill(), add = TRUE)
  ready <- FALSE
  deadline <- Sys.time() + 60
  while (process$is_alive() && Sys.time() < deadline) {
    lines <- process$read_error_lines()
    if (length(lines)) cat(paste(lines, collapse = "\n"), "\n")
    if (any(grepl("Listening on http", lines, fixed = TRUE))) {
      ready <- TRUE
      break
    }
    Sys.sleep(.1)
  }
  if (!ready) stop("Shiny did not reach Listening")
  for (attempt in 1:2) {
    handle <- curl::new_handle(timeout = 60)
    before <- proc.time()[["elapsed"]]
    response <- curl::curl_fetch_memory(paste0("http://127.0.0.1:", port, "/"), handle)
    cat("HTTP", attempt, "status", response$status_code,
      "seconds", proc.time()[["elapsed"]] - before,
      "bytes", length(response$content), "\n")
    stopifnot(response$status_code == 200L,
      grepl("LM Plot Explorer", rawToChar(response$content), fixed = TRUE),
      grepl("0.10.0-beta.1", rawToChar(response$content), fixed = TRUE))
    cat(process$read_output(), process$read_error(), sep = "\n")
    profile <- file.path(evidence, paste0("first-http-", attempt, ".Rprof"))
    if (file.exists(profile)) {
      info <- summaryRprof(profile)
      cat("PROFILE", attempt, "sampled_seconds", info$sampling.time, "\n")
      print(head(info$by.total, 22L))
      print(head(info$by.self, 12L))
    }
  }
}
main()
