# Runs only after a Windows CI failure. This is a separate diagnostic process,
# not a retry of the failed test and not proof that the original failure is fixed.
# Keep the ordinary CDP/AppDriver deadlines and observe a fresh Sass cache.
main <- function() {
  Sys.setenv(CI = "true", GITHUB_ACTIONS = "true", NOT_CRAN = "true")
  Sys.unsetenv("LMPLOT_TRUSTED_LOCAL")
  options(chromote.launch.echo_cmd = TRUE)
  started <- proc.time()[["elapsed"]]
  log_event <- function(kind, value = list()) {
    cat(jsonlite::toJSON(list(elapsed = proc.time()[["elapsed"]] - started,
      kind = kind, value = value), auto_unbox = TRUE, null = "null"), "\n")
    flush.console()
  }
  assign("lmplot_navigation_log", log_event, envir = .GlobalEnv)
  trace("app_init_browser_log", where = asNamespace("shinytest2"), print = FALSE,
    exit = quote({
      session <- self$get_chromote_session()
      .GlobalEnv$lmplot_diagnostic_chromote_parent <- session$parent
      .GlobalEnv$lmplot_navigation_log("session", list(default_timeout = session$default_timeout))
      session$Network$enable()
      session$Network$requestWillBeSent(function(event) {
        .GlobalEnv$lmplot_navigation_log("request", list(id = event$requestId,
          type = event$type, url = event$request$url, timestamp = event$timestamp))
      }, timeout_ = NULL, wait_ = FALSE)
      session$Network$responseReceived(function(event) {
        .GlobalEnv$lmplot_navigation_log("response", list(id = event$requestId,
          type = event$type, url = event$response$url, status = event$response$status,
          timestamp = event$timestamp, timing = event$response$timing))
      }, timeout_ = NULL, wait_ = FALSE)
      session$Network$loadingFailed(function(event) {
        .GlobalEnv$lmplot_navigation_log("network_failure", event)
      }, timeout_ = NULL, wait_ = FALSE)
      session$Page$loadEventFired(function(event) {
        .GlobalEnv$lmplot_navigation_log("page_loaded", event)
      }, timeout_ = NULL, wait_ = FALSE)
    }))
  on.exit(untrace("app_init_browser_log", where = asNamespace("shinytest2")), add = TRUE)
  cache <- tempfile("lmplot-diagnostic-sass-")
  log_event("runtime", list(R = R.version.string,
    commit = Sys.getenv("GITHUB_SHA"),
    chromote = as.character(packageVersion("chromote")),
    shinytest2 = as.character(packageVersion("shinytest2")),
    chrome_path = Sys.getenv("CHROMOTE_CHROME"),
    startup_timeout = getOption("chromote.timeout", 10), sass_cache = cache))
  driver <- NULL
  result <- tryCatch({
    driver <- shinytest2::AppDriver$new(".", name = "navigation-diagnostic",
      seed = 123, load_timeout = 1e5, timeout = 1e5, clean_logs = FALSE,
      options = list(sass.cache = cache, shiny.trace = TRUE))
    log_event("app_ready", driver$get_chromote_session()$Browser$getVersion())
    print(driver$get_logs())
    TRUE
  }, error = function(error) {
    log_event("error", list(message = conditionMessage(error)))
    if (!is.null(error$app)) {
      driver <<- error$app
      try(print(driver$get_logs()), silent = FALSE)
    }
    FALSE
  })
  for (path in list.files(tempdir(), pattern = "^chrome-.*-(stdout|stderr)\\.log$", full.names = TRUE)) {
    cat("CHROME_LOG", basename(path), "\n")
    cat(readLines(path, warn = FALSE), sep = "\n")
  }
  log_event("cleanup_start")
  if (!is.null(driver)) try(driver$stop(), silent = FALSE)
  if (exists("lmplot_diagnostic_chromote_parent", envir = .GlobalEnv, inherits = FALSE)) {
    try(.GlobalEnv$lmplot_diagnostic_chromote_parent$close(), silent = FALSE)
  }
  log_event("diagnostic_complete", list(success = result))
  if (!result) quit(status = 1L)
}
main()
