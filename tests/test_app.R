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

test_that("the public modular app completes its browser smoke workflow", {
  withr::local_envvar(c(NOT_CRAN = "true", LMPLOT_TRUSTED_LOCAL = NA))
  app <- shinytest2::AppDriver$new("..", name = "public-smoke", seed = 123,
    load_timeout = 1e5, timeout = 1e5)
  on.exit(app$stop(), add = TRUE)
  app$set_inputs(`configuration-model_type` = "glm_binomial")
  app$wait_for_idle()
  app$set_inputs(`configuration-link_sel` = "probit", `configuration-simulation-n` = 80,
    `configuration-simulation-seed` = 12)
  app$click("configuration-generate"); app$wait_for_idle()
  app$wait_for_js("Array.isArray(document.querySelector('#overview-main_plot')?.data)")
  expect_match(app$get_html("#overview-metrics"), "80")
  traces <- "document.querySelector('#overview-main_plot').data.filter(x => x.type === 'surface').length"
  expect_equal(app$get_js(traces), 1)
  app$set_inputs(`overview-show_surface` = FALSE); app$wait_for_idle()
  expect_equal(app$get_js(traces), 0)
  app$set_inputs(main_nav_tabs = "diagnostics")
  app$wait_for_js("document.querySelector('#diagnostics-checks table') !== null")
  expect_match(app$get_html("#diagnostics-heading"), "Binomial")
  app$set_inputs(main_nav_tabs = "data_provenance")
  app$wait_for_js("document.querySelector('#data_provenance-table table') !== null")
  enriched <- read.csv(app$get_download("data_provenance-download"), check.names = FALSE)
  expect_equal(nrow(enriched), 80)
  expect_true(all(c(".fitted", ".residual") %in% names(enriched)))
  app$set_inputs(`configuration-simulation-n` = 90)
  expect_identical(read.csv(app$get_download("data_provenance-download"), check.names = FALSE), enriched)
  for (id in c("glm_binomial", "glmm")) {
    app$set_inputs(`configuration-data_source` = "real", `configuration-model_type` = id)
    app$wait_for_idle()
    app$click("configuration-generate"); app$wait_for_idle()
    app$wait_for_js("document.querySelector('#data_provenance-provenance .example-provenance') !== null")
    html <- app$get_html("#data_provenance-provenance")
    expect_match(html, "License")
    expect_match(html, "Source SHA-256 checksum")
    expect_match(html, if (id == "glmm") "Inner London" else "penguin sex")
    data <- read.csv(app$get_download("data_provenance-download"))
    expect_equal(nrow(data), if (id == "glmm") 4059 else 146)
    app$set_inputs(main_nav_tabs = "overview"); app$wait_for_idle()
    expect_false(is.null(app$get_value(output = "overview-main_plot")))
    app$set_inputs(main_nav_tabs = "data_provenance")
  }
  unexpected_logs <- unexpected_app_logs(app$get_logs())
  expect_equal(nrow(unexpected_logs), 0L,
    info = paste(capture.output(print(unexpected_logs, row.names = FALSE)), collapse = "\n"))
})

test_that("browser service failure retains plot and download then recovers", {
  withr::local_envvar(c(NOT_CRAN = "true", LMPLOT_TRUSTED_LOCAL = NA))
  fixture <- tempfile("lmplot-recovery-"); dir.create(fixture)
  on.exit(unlink(fixture, recursive = TRUE), add = TRUE)
  root <- normalizePath("..", winslash = "/")
  file.copy(file.path(root, c("R", "data", "www")), fixture, recursive = TRUE)
  writeLines(c(readLines(file.path(root, "app.R")),
    "original_fit <- fit_model; fit_calls <- 0L",
    "services <- create_analysis_services(fit = function(...) {",
    "  fit_calls <<- fit_calls + 1L",
    "  if (fit_calls == 2L) stop('SECRET_BROWSER_FAILURE /private/path')",
    "  original_fit(...)",
    "})",
    "shiny::shinyApp(ui, server)"), file.path(fixture, "app.R"))
  app <- shinytest2::AppDriver$new(fixture, name = "recovery", load_timeout = 1e5, timeout = 1e5)
  on.exit(app$stop(), add = TRUE)
  app$click("configuration-generate"); app$wait_for_idle()
  app$wait_for_js("Array.isArray(document.querySelector('#overview-main_plot')?.data)")
  plot <- app$get_value(output = "overview-main_plot")
  app$set_inputs(main_nav_tabs = "data_provenance")
  app$wait_for_js("document.querySelector('#data_provenance-table table') !== null")
  csv <- read.csv(app$get_download("data_provenance-download"))
  app$set_inputs(main_nav_tabs = "overview", `configuration-simulation-n` = 90)
  app$click("configuration-generate"); app$wait_for_idle()
  expect_match(app$get_html("#analysis_status-error"), "Analysis failed. Review the settings and try again.", fixed = TRUE)
  expect_match(app$get_html("#analysis_status-status"), "Showing the last successful analysis.")
  expect_false(grepl("SECRET_BROWSER_FAILURE|/private/path", app$get_html("body")))
  expect_identical(app$get_value(output = "overview-main_plot"), plot)
  app$set_inputs(main_nav_tabs = "data_provenance")
  app$wait_for_idle()
  expect_identical(read.csv(app$get_download("data_provenance-download")), csv)
  app$click("configuration-generate"); app$wait_for_idle()
  expect_equal(nrow(read.csv(app$get_download("data_provenance-download"))), 90)
  expect_false(grepl("Analysis failed", app$get_html("#analysis_status-error")))
  logs <- app$get_logs()
  expect_true(any(grepl("SECRET_BROWSER_FAILURE", logs$message, fixed = TRUE)))
})
