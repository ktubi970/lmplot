Sys.setenv(NOT_CRAN = "true")
source("tests/helper-browser.R")

cat("Starting app for screenshot capture...\n")
app <- shinytest2::AppDriver$new(
  ".",
  name = "screenshot-capture",
  seed = 123,
  width = 1440,
  height = 1200,
  load_timeout = 1e5,
  timeout = 1e5
)
on.exit(app$stop(), add = TRUE)

app$wait_for_idle()

cat("Fitting model...\n")
app$click("configuration-generate")
app$wait_for_idle()

app$wait_for_js("Array.isArray(document.querySelector('#overview-main_plot')?.data)")
app$wait_for_idle()

cat("Capturing lmplot.png...\n")
if (file.exists("lmplot.png")) unlink("lmplot.png")
app$get_screenshot("lmplot.png")
cat("SUCCESS: lmplot.png updated\n")
