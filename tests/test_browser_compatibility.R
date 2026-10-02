compatibility_file <- file.path("..", "R", "browser_compatibility.R")
if (file.exists(compatibility_file)) source(compatibility_file)

test_that("browser downloads remove Chromium's service worker bypass attribute", {
  ui <- shiny::tags$div(
    shiny::downloadButton("data-download", "Download CSV"),
    shiny::tags$div(shiny::downloadLink("chart-download", "Download chart")),
    shiny::tags$a(href = "example.csv", download = "example.csv", "Ordinary file")
  )
  adapted <- adapt_browser_downloads(ui, browser_runtime = TRUE)
  html <- htmltools::renderTags(adapted)$html
  links <- htmltools::tagQuery(adapted)$find("a.shiny-download-link")$selectedTags()
  expect_length(links, 2L)
  expect_false(any(vapply(links, function(tag) "download" %in% names(tag$attribs), logical(1))))
  expect_false(any(vapply(links, function(tag) "target" %in% names(tag$attribs), logical(1))))
  expect_true(grepl('download="example.csv"', html, fixed = TRUE))
  expect_true(grepl('id="data-download"', html, fixed = TRUE))
  expect_true(grepl('id="chart-download"', html, fixed = TRUE))
  expect_true(grepl('class="[^"]*shiny-download-link[^"]*"', html))
})

test_that("native Shiny retains its original download behavior", {
  ui <- shiny::downloadButton("download", "CSV")
  expect_identical(adapt_browser_downloads(ui, browser_runtime = FALSE), ui)
  if (!grepl("^wasm32-", R.version$platform)) {
    expect_identical(adapt_browser_downloads(ui), ui)
  }
})
