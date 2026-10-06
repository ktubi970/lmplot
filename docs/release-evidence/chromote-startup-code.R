for (package in c("chromote", "shinytest2")) {
  cat("PACKAGE", package, as.character(packageVersion(package)), "\n")
}
for (name in c("launch_chrome", "launch_chrome_impl", "default_chrome_args", "get_chrome_args",
    "get_chromote_timeout", "get_chromote_launch_timeout", "default_chromote_object")) {
  cat("\nCHROMOTE FUNCTION", name, "\n")
  if (exists(name, envir = asNamespace("chromote"), inherits = FALSE))
    print(get(name, envir = asNamespace("chromote")))
}
cat("\nCHROME INITIALIZE\n")
print(chromote::Chrome$public_methods$initialize)
cat("\nCHROMOTE INITIALIZE\n")
print(chromote::Chromote$public_methods$initialize)
cat("\nAPPDRIVER INITIALIZE\n")
print(shinytest2::AppDriver$public_methods$initialize)
cat("\nSHINYTEST2 CHROME FUNCTIONS\n")
ns <- asNamespace("shinytest2")
for (name in ls(ns, all.names = TRUE)) {
  object <- get(name, envir = ns)
  if (is.function(object) && any(grepl("Chromote|chromote|Chrome\\$|launch_timeout", deparse(body(object))))) {
    cat("\nFUNCTION", name, "\n")
    print(object)
  }
}
