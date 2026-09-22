source(file.path('..', 'app.R'), local = TRUE)
test_that('semantic shell and Brain chart alternatives resolve their descriptions', {
  html <- as.character(ui)
  expect_match(html, 'href="#main-content"')
  expect_match(html, '<main[^>]*id="main-content"')
  expect_match(html, '<header>')
  expect_match(html, '<nav aria-label=')
  expect_match(html, 'id="brain-observation_summary"[^>]*aria-live="polite"')
  expect_match(html, 'id="brain-index_error"[^>]*role="alert"')
  for (key in c('equation', 'contribution', 'link', 'coefficient', 'random')) {
    for (suffix in c('summary', 'table', 'download'))
      expect_match(html, paste0('id="brain-', key, '_', suffix, '"'))
  }
  expect_match(html, 'for="brain-observation_index"')
})

test_that('large chart alternatives explicitly preview rows and keep the table data separate', {
  data <- data.frame(value = seq_len(105))
  html <- as.character(accessible_data_table(data, 'Fixture values'))
  expect_match(html, 'Showing 100 of 105 rows')
  expect_match(html, 'Download the CSV for all rows')
  expect_equal(length(regmatches(html, gregexpr('<td', html))[[1]]), 100L)
})

test_that('local typography and selected scientific colors meet declared contrast targets', {
  css <- paste(readLines(file.path('..', 'www', 'style.css')), collapse = '\n')
  expect_false(grepl('fonts.googleapis.com|@import[^;]*url', css))
  contrast <- function(foreground, background) {
    luminance <- function(color) {
      rgb <- as.numeric(grDevices::col2rgb(color)) / 255
      sum(ifelse(rgb <= .04045, rgb / 12.92, ((rgb + .055) / 1.055)^2.4) * c(.2126, .7152, .0722))
    }
    values <- sort(c(luminance(foreground), luminance(background)))
    (values[2] + .05) / (values[1] + .05)
  }
  for (color in c('#1e293b', '#475569', '#1d4ed8', '#0f766e', '#92400e', '#991b1b'))
    expect_gte(contrast(color, '#ffffff'), 4.5)
  expect_gte(contrast('#2563eb', '#ffffff'), 3)
})
