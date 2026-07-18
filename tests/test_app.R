unexpected_app_logs <- function(logs) {
  level <- tolower(trimws(as.character(logs$level)))
  location <- tolower(trimws(as.character(logs$location)))
  message <- trimws(as.character(logs$message))
  level[is.na(level)] <- ""
  location[is.na(location)] <- ""
  message[is.na(message)] <- ""

  binary_warning <- location == "shiny" & level == "stderr" & grepl(
    "^Warning: package '[^']+' was built under R version 4\\.6\\.1$",
    message
  )
  plotly_header <- location == "shiny" & level == "stderr" & grepl(
    "^Warning in plotly_build\\.plotly\\((x|instance)\\) :$",
    message
  )
  plotly_message <- location == "shiny" & level == "stderr" &
    message == "shinytest can't currently render WebGL-based graphics."
  next_is_plotly_message <- c(plotly_message[-1L], FALSE)
  previous_is_plotly_header <- c(FALSE, plotly_header[-length(plotly_header)])
  known_plotly_pair <-
    (plotly_header & next_is_plotly_message) |
    (plotly_message & previous_is_plotly_header)
  known_warning <- binary_warning | known_plotly_pair

  warning_level <- level %in% c("warn", "warning")
  error_level <- level %in% c("error", "severe", "fatal")
  warning_message <- grepl("^Warning(?::| in |$)", message) | plotly_message
  error_message <- grepl(
    "(^|[[:space:]])(Error|Execution halted|TypeError|ReferenceError|Unhandled promise rejection)(:|[[:space:]]|$)",
    message,
    ignore.case = TRUE
  )

  logs[
    (warning_level | error_level | warning_message | error_message) &
      !known_warning,
    ,
    drop = FALSE
  ]
}

test_that("browser log classification rejects warning levels without a Warning prefix", {
  logs <- data.frame(
    location = "chromote",
    level = "warning",
    message = "Unhandled promise rejection",
    stringsAsFactors = FALSE
  )

  unexpected <- unexpected_app_logs(logs)

  expect_equal(nrow(unexpected), 1L)
  expect_identical(unexpected$message, "Unhandled promise rejection")
})

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
  surface_count_js <- paste0(
    "(() => {",
    "const plot = document.querySelector('#main_plot');",
    "const traces = Array.isArray(plot?.data) ? plot.data : [];",
    "return traces.filter(trace => trace.type === 'surface').length;",
    "})()"
  )
  app$wait_for_js(
    paste0(surface_count_js, " === 1"),
    timeout = 2e4
  )
  expect_equal(app$get_js(surface_count_js), 1)
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
  app$wait_for_js(
    paste0(
      "(() => {",
      "const plot = document.querySelector('#main_plot');",
      "return Array.isArray(plot?.data) && plot.data.length > 0 && ",
      "plot.data.every(trace => trace.type !== 'surface');",
      "})()"
    ),
    timeout = 2e4
  )
  expect_equal(app$get_js(surface_count_js), 0)

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
