source(if (file.exists("helper-browser.R")) "helper-browser.R" else file.path("tests", "helper-browser.R"), local = TRUE)

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
  app$wait_for_idle()
  app$wait_for_js("Array.isArray(document.querySelector('#overview-main_plot')?.data)")
  expect_match(app$get_html("#overview-metrics"), "80")
  traces <- "document.querySelector('#overview-main_plot').data.filter(x => x.type === 'surface').length"
  expect_equal(app$get_js(traces), 1)
  app$set_inputs(`overview-show_surface` = FALSE); app$wait_for_idle()
  expect_equal(app$get_js(traces), 0)
  app$set_inputs(main_nav_tabs = "diagnostics")
  app$click(selector = "#diagnostics-checks_details > summary")
  app$wait_for_js("document.querySelector('#diagnostics-checks table') !== null")
  expect_match(app$get_html("#diagnostics-heading"), "Binomial")
  app$set_inputs(main_nav_tabs = "data_provenance")
  app$wait_for_js("document.querySelector('#data_provenance-table table') !== null")
  enriched <- read.csv(app$get_download("data_provenance-download"), check.names = FALSE)
  expect_equal(nrow(enriched), 80)
  expect_true(all(c(".fitted", ".residual") %in% names(enriched)))
  app$set_inputs(`configuration-simulation-n` = 90)
  app$wait_for_idle()
  expect_equal(nrow(read.csv(app$get_download("data_provenance-download"), check.names = FALSE)), 90L)
  for (id in c("glm_binomial", "glmm")) {
    app$set_inputs(`configuration-data_source` = "real", `configuration-model_type` = id)
    app$wait_for_idle()
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
  app$wait_for_idle()
  app$wait_for_js("Array.isArray(document.querySelector('#overview-main_plot')?.data)")
  plot <- app$get_value(output = "overview-main_plot")
  app$set_inputs(main_nav_tabs = "data_provenance")
  app$wait_for_js("document.querySelector('#data_provenance-table table') !== null")
  csv <- read.csv(app$get_download("data_provenance-download"))
  app$set_inputs(main_nav_tabs = "overview", `configuration-simulation-n` = 90)
  app$wait_for_idle()
  expect_match(app$get_html("#analysis_status-error"), "Analysis failed. Review the settings and try again.", fixed = TRUE)
  expect_match(app$get_html("#analysis_status-status"), "Showing the last successful analysis.")
  expect_false(grepl("SECRET_BROWSER_FAILURE|/private/path", app$get_html("body")))
  expect_identical(app$get_value(output = "overview-main_plot"), plot)
  app$set_inputs(main_nav_tabs = "data_provenance")
  app$wait_for_idle()
  expect_identical(read.csv(app$get_download("data_provenance-download")), csv)
  app$set_inputs(`configuration-simulation-n` = 91)
  app$wait_for_idle()
  expect_equal(nrow(read.csv(app$get_download("data_provenance-download"))), 91)
  expect_false(grepl("Analysis failed", app$get_html("#analysis_status-error")))
  logs <- app$get_logs()
  expect_true(any(grepl("SECRET_BROWSER_FAILURE", logs$message, fixed = TRUE)))
})

test_that('keyboard workflow and observed Plotly clicks share the Brain selection', {
  withr::local_envvar(c(NOT_CRAN = 'true', LMPLOT_TRUSTED_LOCAL = NA))
  app <- shinytest2::AppDriver$new('..', name = 'brain-keyboard', width = 1440, height = 1000, load_timeout = 1e5, timeout = 1e5)
  on.exit(app$stop(), add = TRUE)
  browser <- app$get_chromote_session()
  key <- function(name, code = name, vk = NULL, modifiers = 0L) {
    args <- list(type = 'keyDown', key = name, code = code, modifiers = modifiers)
    if (!is.null(vk)) args$windowsVirtualKeyCode <- vk
    if (name %in% c('Enter', ' ')) { args$text <- if (name == 'Enter') '\r' else ' '; args$unmodifiedText <- args$text }
    do.call(browser$Input$dispatchKeyEvent, args)
    args$type <- 'keyUp'; args$text <- NULL; args$unmodifiedText <- NULL
    do.call(browser$Input$dispatchKeyEvent, args)
  }
  tab_to <- function(id, selector = paste0('#', id)) {
    visited <- character()
    for (i in seq_len(60)) {
      if (isTRUE(app$get_js(paste0('document.activeElement === document.querySelector(', jsonlite::toJSON(selector, auto_unbox = TRUE), ')')))) return(invisible(TRUE))
      visited <- c(visited, app$get_js('document.activeElement.id'))
      key('Tab', vk = 9L)
    }
    stop(paste('Keyboard could not reach', id, '; visited', paste(unique(visited), collapse = ', ')))
  }
  key('Tab', vk = 9L)
  expect_equal(app$get_js('document.activeElement.textContent.trim()'), 'Skip to main content')
  key('Enter', vk = 13L)
  expect_equal(app$get_js('document.activeElement.id'), 'main-content')
  expect_equal(app$get_js('document.querySelectorAll("main").length'), 1)
  expect_equal(app$get_js('document.documentElement.lang'), 'en')
  tab_to('configuration-model_type-selectized')
  key('Escape', vk = 27L)
  app$wait_for_idle()
  app$wait_for_js('document.querySelector("#overview-main_plot")?.data?.length > 0')
  expect_match(app$get_html('#overview-chart_summary'), 'N =')
  expect_equal(app$get_value(input = 'configuration-model_type'), 'lm_2d')
  expect_equal(app$get_value(input = 'brain-observation_index'), 186L)
  # Real Plotly pointer hit on an observed SVG marker (not a synthetic input).
  app$run_js("document.querySelector('#overview-main_plot').scrollIntoView({block:'center'})")
  point <- app$get_js("(() => { const p = document.querySelector('#overview-main_plot .scatterlayer .trace .point'); const r = p.getBoundingClientRect(); return {x:r.x+r.width/2,y:r.y+r.height/2}; })()")
  browser$Input$dispatchMouseEvent(type = 'mousePressed', x = point$x, y = point$y, button = 'left', clickCount = 1L)
  browser$Input$dispatchMouseEvent(type = 'mouseReleased', x = point$x, y = point$y, button = 'left', clickCount = 1L)
  app$wait_for_js("Shiny.shinyapp.$inputValues['overview-observation_selection']?.observation_id === '1'")
  tab_to('Overview tab', 'a[data-value=overview]')
  key('ArrowRight', vk = 39L); key('ArrowRight', vk = 39L)
  expect_equal(app$get_js('document.activeElement.dataset.value'), 'brain')
  expect_equal(app$get_js('document.activeElement.getAttribute("aria-selected")'), 'true')
  app$wait_for_js('document.querySelector("#brain-observation_summary").textContent.includes("Observation 1 of")')
  tab_to('brain-next')
  expect_gte(app$get_js('parseFloat(getComputedStyle(document.activeElement).outlineWidth)'), 2)
  expect_equal(app$get_js('getComputedStyle(document.activeElement).outlineStyle'), 'solid')
  expect_gte(app$get_js('document.activeElement.getBoundingClientRect().height'), 24)
  expect_true(app$get_js('(() => {const r=document.activeElement.getBoundingClientRect(); return r.top>=0 && r.bottom<=innerHeight && r.left>=0 && r.right<=innerWidth})()'))
  key('Enter', vk = 13L)
  app$wait_for_js('document.querySelector("#brain-observation_summary").textContent.includes("Observation 2 of")')
  expect_equal(app$get_js('document.activeElement.id'), 'brain-next')
  key('Tab', vk = 9L, modifiers = 8L)
  expect_equal(app$get_js('document.activeElement.id'), 'brain-previous')
  key(' ', code = 'Space', vk = 32L)
  app$wait_for_js('document.querySelector("#brain-observation_summary").textContent.includes("Observation 1 of")')
  csv <- read.csv(app$get_download('brain-equation_download'))
  expect_true(all(csv$source_index == 1)); expect_true(all(csv$prediction_mode == 'conditional'))
  expect_equal(app$get_js('getComputedStyle(document.body).color'), 'rgb(30, 41, 59)')
  expect_equal(app$get_js('getComputedStyle(document.body).backgroundColor'), 'rgb(248, 250, 252)')
  expect_true(app$get_js('Array.from(document.querySelectorAll("#brain-controls input:not([type=hidden]), #brain-controls select")).filter(e => e.getClientRects().length).every(e => e.getAttribute("aria-label") || document.querySelector("label[for=" + CSS.escape(e.id) + "]"))'))
  expect_equal(app$get_js('Array.from(document.querySelectorAll(".chart-section [aria-describedby]")).every(e => document.getElementById(e.getAttribute("aria-describedby")))'), TRUE)
  expect_equal(app$get_js('document.querySelector("#brain-observation_summary").getAttribute("aria-live")'), 'polite')
  expect_equal(app$get_js('Array.from(document.querySelectorAll("link[href],script[src]")).filter(e => /^https?:/.test(e.href || e.src) && !/^https?:\\/\\/(127.0.0.1|localhost)/.test(e.href || e.src)).length'), 0)
  unexpected <- unexpected_app_logs(app$get_logs())
  expect_equal(nrow(unexpected), 0L, info = paste(capture.output(print(unexpected)), collapse = '\n'))
})
