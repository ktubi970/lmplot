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

test_that("browser log classification uses strict levels and warning pairs", {
  log_frame <- function(location, level, message) {
    data.frame(
      location = location,
      level = level,
      message = message,
      stringsAsFactors = FALSE
    )
  }
  plotly_header <- "Warning in plotly_build.plotly(x) :"
  plotly_message <- "shinytest can't currently render WebGL-based graphics."
  binary_warning <- "Warning: package 'shiny' was built under R version 4.6.1"
  level_logs <- log_frame(
    rep("chromote", 5L),
    c("warning", "warn", "error", "severe", "fatal"),
    c(
      "Unhandled promise rejection",
      "Promise settled late",
      "Request failed",
      "Console entry",
      "Browser stopped"
    )
  )
  cases <- list(
    diagnostic_levels = list(logs = level_logs, expected = 5L),
    exact_plotly_pair = list(
      logs = log_frame(
        rep("shiny", 2L),
        rep("stderr", 2L),
        c(plotly_header, plotly_message)
      ),
      expected = 0L
    ),
    orphan_plotly_header = list(
      logs = log_frame("shiny", "stderr", plotly_header),
      expected = 1L
    ),
    orphan_plotly_message = list(
      logs = log_frame("shiny", "stderr", plotly_message),
      expected = 1L
    ),
    exact_binary_warning = list(
      logs = log_frame("shiny", "stderr", binary_warning),
      expected = 0L
    ),
    binary_warning_wrong_location = list(
      logs = log_frame("chromote", "stderr", binary_warning),
      expected = 1L
    ),
    binary_warning_wrong_level = list(
      logs = log_frame("shiny", "warning", binary_warning),
      expected = 1L
    )
  )

  for (name in names(cases)) {
    case <- cases[[name]]
    expect_equal(
      nrow(unexpected_app_logs(case$logs)),
      case$expected,
      info = name
    )
  }
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

  real_plot_titles <- c(
    lm_2d = "Ad\u00e9lie penguin body mass",
    lm_3d = "28-day concrete compressive strength",
    glm_binomial = "Ad\u00e9lie penguin sex from morphology",
    glm_poisson = "Abalone shell-ring count",
    glm_gamma = "Positive forest-fire burned area",
    glmm = "Inner London examination achievement"
  )
  for (model_type in names(real_plot_titles)) {
    app$set_inputs(data_source = "real", model_type = model_type)
    app$wait_for_idle()
    app$wait_for_js(
      "document.querySelector('#example_info .example-provenance') !== null",
      timeout = 2e4
    )
    app$click("generate")
    app$wait_for_idle()
    app$wait_for_js(
      paste0(
        "document.querySelector('#main_plot .gtitle') !== null && ",
        "document.querySelector('#model_summary')?.textContent.trim().length > 0 && ",
        "document.querySelector('#data_table table') !== null"
      ),
      timeout = 2e4
    )
    rendered_plot_title <- app$get_js(
      "document.querySelector('#main_plot .gtitle')?.textContent ?? ''"
    )
    expect_match(
      rendered_plot_title, real_plot_titles[[model_type]], fixed = TRUE,
      info = model_type
    )
    expect_false(
      is.null(app$get_value(output = "main_plot")),
      info = model_type
    )
    expect_false(
      is.null(app$get_value(output = "model_summary")),
      info = model_type
    )
    expect_false(
      is.null(app$get_value(output = "data_table")),
      info = model_type
    )
  }

  unexpected_logs <- unexpected_app_logs(app$get_logs())
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
