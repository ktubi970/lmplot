# Chromium Issue 468227: a download attribute bypasses Shinylive's service
# worker. Response Content-Disposition still supplies the filename.
# https://shiny.posit.co/r/components/inputs/download-button/
adapt_browser_downloads <- function(ui,
    browser_runtime = grepl("^wasm32-", R.version$platform)) {
  if (!browser_runtime) return(ui)
  # Keep the request in the app's frame; the response triggers the file download.
  htmltools::tagQuery(ui)$find("a.shiny-download-link")$removeAttrs(c("download", "target"))$allTags()
}
