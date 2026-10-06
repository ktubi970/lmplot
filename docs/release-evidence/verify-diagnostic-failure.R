# Fault injection for the diagnostic's failure path, not a reproduction of CI.
root <- normalizePath(getwd(), winslash = "/")
fixture <- tempfile("lmplot-slow-document-")
dir.create(fixture)
writeLines(c(
  "shiny::shinyApp(ui = function(request) {",
  "  Sys.sleep(12)",
  "  shiny::fluidPage('Intentional slow document diagnostic fixture')",
  "}, server = function(input, output, session) {})"
), file.path(fixture, "app.R"))
diagnostic <- file.path(root, "scripts", "ci_browser_diagnostic.R")
child <- callr::r_bg(function(script) source(script, chdir = FALSE),
  args = list(diagnostic), libpath = .libPaths(), wd = fixture,
  stdout = "|", stderr = "|", supervise = TRUE)
handles <- list()
output <- character()
capture <- function(lines) {
  output <<- c(output, lines)
  if (length(lines)) cat(lines, sep = "\n")
}
started <- Sys.time()
while (child$is_alive()) {
  descendants <- tryCatch(ps::ps_children(ps::ps_handle(child$get_pid()), recursive = TRUE),
    error = function(e) list())
  for (handle in descendants) {
    name <- tryCatch(ps::ps_name(handle), error = function(e) "")
    if (tolower(name) %in% c("r.exe", "rterm.exe", "rscript.exe", "chrome.exe")) {
      handles[[as.character(ps::ps_pid(handle))]] <- handle
    }
  }
  capture(child$read_output_lines())
  capture(child$read_error_lines())
  if (difftime(Sys.time(), started, units = "secs") > 120) {
    child$kill_tree()
    stop("Diagnostic fault-injection exceeded 120 seconds")
  }
  child$poll_io(200)
}
capture(child$read_output_lines())
capture(child$read_error_lines())
status <- child$get_exit_status()
cat("FAULT_INJECTION_EXIT", status, "\n")
stopifnot(identical(status, 1L))
stopifnot(any(grepl("Page.navigate", output, fixed = TRUE)))
stopifnot(any(grepl('"default_timeout":10', output, fixed = TRUE)))
stopifnot(any(grepl('"type":"Document"', output, fixed = TRUE)))
stopifnot(any(grepl("Listening on", output, fixed = TRUE)))
stopifnot(any(grepl("CHROME_LOG", output, fixed = TRUE)))
stopifnot(any(grepl('"kind":"diagnostic_complete","value":{"success":false}', output, fixed = TRUE)))
deadline <- Sys.time() + 10
repeat {
  alive <- Filter(function(handle) tryCatch(ps::ps_is_running(handle), error = function(e) FALSE), handles)
  if (!length(alive) || Sys.time() > deadline) break
  Sys.sleep(0.1)
}
cat("OWNED_R_CHROME_PROCESSES_OBSERVED", length(handles), "STILL_RUNNING", length(alive), "\n")
if (length(alive)) {
  for (handle in alive) try(ps::ps_kill(handle), silent = TRUE)
  stop("Diagnostic left owned R or Chrome processes running")
}
cat("FAULT_INJECTION_VERIFIED: error exit, navigation failure evidence, logs, cleanup\n")
