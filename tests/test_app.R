test_that("the real beta app completes its browser smoke workflow", {
  withr::local_envvar(NOT_CRAN = "true")
  chromote_browser <- chromote::default_chromote_object()
  previous_chromote_timeout <- chromote_browser$default_timeout
  chromote_browser$default_timeout <- 100
  withr::defer(chromote_browser$default_timeout <- previous_chromote_timeout)
  expect_true(
    requireNamespace("shinytest2", quietly = TRUE),
    info = "Restore the locked shinytest2 dependency before running beta acceptance tests."
  )

  app <- shinytest2::AppDriver$new(
    "..",
    name = "beta-smoke",
    seed = 123,
    load_timeout = 1e5,
    timeout = 1e5
  )
  on.exit(app$stop(), add = TRUE)

  app$set_inputs(model_type = "glm_binomial")
  app$wait_for_idle()
  app$wait_for_js(
    "document.querySelector('#link_sel') !== null",
    timeout = 2e4
  )
  app$set_inputs(link_sel = "probit")
  app$wait_for_idle()
  app$wait_for_js(
    "document.querySelector('#simulation-n') !== null && document.querySelector('#simulation-seed') !== null",
    timeout = 2e4
  )
  app$set_inputs(`simulation-n` = 80, `simulation-seed` = 12)
  app$wait_for_idle()
  expect_equal(app$get_value(input = "link_sel"), "probit")
  expect_equal(app$get_value(input = "simulation-n"), 80)
  expect_equal(app$get_value(input = "simulation-seed"), 12)
  app$click("generate")
  app$wait_for_idle()

  app$wait_for_js(
    "document.querySelector('#main_plot .plot-container') !== null",
    timeout = 2e4
  )
  expect_false(is.null(app$get_value(output = "model_summary")))
  app$run_js(
    "document.querySelector('a[data-value=\"Data\"]')?.click()"
  )
  app$wait_for_js(
    "document.querySelector('#data_table table') !== null",
    timeout = 2e4
  )
  expect_match(app$get_html("#data_table"), "<table", fixed = TRUE)

  app$set_inputs(show_surface = FALSE)
  app$wait_for_idle()
  expect_false(app$get_value(input = "show_surface"))

  downloaded <- app$get_download("download_data")
  expect_true(file.exists(downloaded))
  enriched <- utils::read.csv(downloaded, check.names = FALSE)
  expect_equal(nrow(enriched), 80L)
  expect_true(all(c(".fitted", ".residual") %in% names(enriched)))

  logs <- app$get_logs()
  known_binary_warning <- grepl(
    "^Warning: package '[^']+' was built under R version 4\\.6\\.1$",
    logs$message
  )
  plotly_test_warning_header <- grepl(
    "^Warning in plotly_build\\.plotly\\((x|instance)\\) :",
    trimws(logs$message)
  )
  next_message <- c(trimws(logs$message[-1L]), "")
  known_plotly_test_warning <- plotly_test_warning_header &
    next_message == "shinytest can't currently render WebGL-based graphics."
  warning_log <- grepl("^Warning", trimws(logs$message))
  error_log <- logs$level %in% c("error", "severe") |
    grepl(
      "(^|[[:space:]])(Error|Execution halted|TypeError|ReferenceError)(:|[[:space:]]|$)",
      logs$message
    )
  unexpected_logs <- logs[
    (warning_log & !known_binary_warning & !known_plotly_test_warning) | error_log,
    c("location", "level", "message"),
    drop = FALSE
  ]
  expect_equal(
    nrow(unexpected_logs),
    0L,
    info = paste(
      "Unexpected browser or Shiny warning/error logs:",
      paste(capture.output(print(unexpected_logs, row.names = FALSE)), collapse = "\n"),
      sep = "\n"
    )
  )
})
