cat("UTC:", format(Sys.time(), tz = "UTC"), "\n")
cat("R:", R.version.string, "\n")
cat("Chrome path:", Sys.getenv("CHROMOTE_CHROME"), "\n")
cat("CI:", Sys.getenv("CI"), "GITHUB_ACTIONS:", Sys.getenv("GITHUB_ACTIONS"), "\n")
cat("chromote version:", as.character(packageVersion("chromote")), "\n")
cat("chromote.timeout (effective):", getOption("chromote.timeout", 10), "\n")
cat("chromote options:\n")
print(options()[grep("chromote", names(options()))])
cat("Default chrome args:\n")
print(chromote::get_chrome_args())
cat("Headless mode:\n")
print(chromote:::chrome_headless_mode())
options(chromote.launch.echo_cmd = TRUE)
started <- proc.time()[["elapsed"]]
workflow <- yaml::read_yaml(".github/workflows/ci.yml")
step <- Filter(function(x) identical(x$name, "Verify locked runtime, packages and browser"),
  workflow$jobs[["r-check"]]$steps)[[1]]
lines <- strsplit(step$run, "\n", fixed = TRUE)[[1]]
opening <- grep("@'\\r?$", lines)
closing <- grep("^'@\\r?$", lines)
code <- lines[seq.int(opening + 1L, closing - 1L)]
status <- tryCatch({
  eval(parse(text = code), envir = new.env(parent = globalenv()))
  cat("PREFLIGHT_SUCCESS\n")
  0L
}, error = function(e) {
  cat("PREFLIGHT_FAILURE:", conditionMessage(e), "\n")
  cat("ERROR_CLASSES:", paste(class(e), collapse = ", "), "\n")
  1L
})
cat("PREFLIGHT_ELAPSED_SECONDS:", proc.time()[["elapsed"]] - started, "\n")
for (path in list.files(tempdir(), pattern = "chrome-.*-(stdout|stderr)\\.log$", full.names = TRUE)) {
  cat("CHROME_LOG:", path, "\n")
  cat(readLines(path, warn = FALSE), sep = "\n")
}
quit(status = status)
