cat("R:", R.version.string, "\n")
for (package in c("shinytest2", "chromote", "shiny", "callr", "processx")) {
  cat(package, as.character(packageVersion(package)), "\n")
}
cat("SHINYTEST2 INITIALIZE\n")
print(shinytest2:::app_initialize_)
cat("CHROMOTE SESSION INITIALIZE\n")
print(chromote::ChromoteSession$public_methods$initialize)
cat("CHROMOTE SESSION SEND COMMAND\n")
print(chromote::ChromoteSession$public_methods$send_command)
cat("CHROMOTE INITIALIZE\n")
print(chromote::Chromote$public_methods$initialize)
cat("SHINY RUN APP\n")
print(shiny::runApp)
