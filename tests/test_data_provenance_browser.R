test_that("Data filters remain operable without focusing or exposing sizing copies", {
  withr::local_envvar(c(NOT_CRAN = "true", LMPLOT_TRUSTED_LOCAL = NA))
  app <- shinytest2::AppDriver$new("..", name = "data-filter-keyboard",
    seed = 123, width = 517, height = 672, load_timeout = 1e5, timeout = 1e5)
  on.exit(app$stop(), add = TRUE)
  browser <- app$get_chromote_session()
  key <- function(name, modifiers = 0L) {
    browser$Input$dispatchKeyEvent(type = "keyDown", key = name,
      code = if (name == "a") "KeyA" else name, modifiers = modifiers,
      windowsVirtualKeyCode = switch(name, Tab = 9L, Backspace = 8L, a = 65L))
    browser$Input$dispatchKeyEvent(type = "keyUp", key = name,
      code = if (name == "a") "KeyA" else name, modifiers = modifiers)
  }
  root <- "#data_provenance-table"
  filter <- function(i) paste0(root,
    " .dataTables_scrollHead thead tr:last-child td:nth-child(", i, ") input[type=search]")
  table <- paste0("jQuery('", root, " .dataTables_scrollBody table').DataTable()")
  ax_node <- function(selector) {
    document <- browser$DOM$getDocument()$root$nodeId
    node <- browser$DOM$querySelector(nodeId = document, selector = selector)$nodeId
    browser$Accessibility$getPartialAXTree(nodeId = node, fetchRelatives = FALSE)$nodes[[1L]]
  }
  check_focus_visible <- function(stage) {
    bounds <- app$get_js("(() => {
      const input = document.activeElement;
      if (!input.matches('#data_provenance-table .dataTables_scrollHead input')) return null;
      const rect = input.getBoundingClientRect();
      let left = Math.max(0, rect.left), right = Math.min(innerWidth, rect.right);
      let top = Math.max(0, rect.top), bottom = Math.min(innerHeight, rect.bottom);
      for (let parent = input.parentElement; parent; parent = parent.parentElement) {
        const style = getComputedStyle(parent), box = parent.getBoundingClientRect();
        if (/hidden|clip|auto|scroll/.test(style.overflowX)) {
          left = Math.max(left, box.left + parent.clientLeft);
          right = Math.min(right, box.left + parent.clientLeft + parent.clientWidth);
        }
        if (/hidden|clip|auto|scroll/.test(style.overflowY)) {
          top = Math.max(top, box.top + parent.clientTop);
          bottom = Math.min(bottom, box.top + parent.clientTop + parent.clientHeight);
        }
      }
      return {column: input.closest('td').cellIndex, x: rect.x, y: rect.y,
        width: rect.width, height: rect.height, viewport: [innerWidth, innerHeight],
        visibleWidth: Math.max(0, right - left), visibleHeight: Math.max(0, bottom - top)};
    })()")
    if (!is.null(bounds)) expect_true(bounds$visibleWidth > 0 && bounds$visibleHeight > 0,
      info = paste(stage, jsonlite::toJSON(bounds, auto_unbox = TRUE)))
  }
  check_filters <- function(stage, active_count = 4L) {
    for (i in seq_len(active_count)) {
      node <- ax_node(filter(i))
      expect_false(node$ignored, info = stage)
    }
    # The body retains its semantic column headers; only duplicate controls are hidden.
    header <- ax_node(paste0(root, " .dataTables_scrollBody thead tr:first-child th"))
    expect_false(header$ignored, info = stage)
    expect_match(header$name$value, "X", fixed = TRUE, info = stage)
    copies <- app$get_js(paste0("document.querySelectorAll('", root,
      " .dataTables_scrollBody thead input').length"))
    if (copies > 0) {
      ignored <- vapply(seq_len(copies), function(i) {
        app$run_js(paste0("document.querySelectorAll('", root,
          " .dataTables_scrollBody thead input')[", i - 1L,
          "].setAttribute('data-test-copy', 'current')"))
        node <- ax_node(paste0(root, " [data-test-copy=current]"))
        app$run_js(paste0("document.querySelector('", root,
          " [data-test-copy=current]').removeAttribute('data-test-copy')"))
        isTRUE(node$ignored)
      }, logical(1))
      expect_true(all(ignored), info = paste(stage, "sizing copies exposed in AX"))
    }
    app$run_js(paste0("document.querySelector('", root, " .dataTables_filter input').focus()"))
    reached_x <- FALSE
    for (i in seq_len(20L)) {
      key("Tab")
      reached_x <- app$get_js(paste0("document.activeElement === document.querySelector('",
        filter(1L), "')"))
      if (isTRUE(reached_x)) break
    }
    expect_true(reached_x, info = paste(stage, "Tab from Search did not reach X"))
    check_focus_visible(paste(stage, "X"))
    visited_copies <- logical(14L)
    active_columns <- integer(active_count - 1L)
    for (i in seq_along(visited_copies)) {
      key("Tab")
      check_focus_visible(paste(stage, "Tab", i))
      visited_copies[[i]] <- app$get_js(paste0("!!document.activeElement.closest('",
        root, " .dataTables_scrollBody thead')"))
      if (i <= length(active_columns)) active_columns[[i]] <- app$get_js(paste0(
        "document.activeElement.closest('", root, " .dataTables_scrollHead') ? ",
        "document.activeElement.closest('td').cellIndex : -1"))
    }
    expect_equal(active_columns, seq_len(active_count - 1L), info = stage)
    expect_false(any(visited_copies), info = paste(stage, "Tab reached a sizing copy"))
    app$run_js(paste0("document.querySelector('", root,
      " .dataTables_paginate .paginate_button:not(.disabled)').focus()"))
    reverse_copies <- logical()
    reached_x <- FALSE
    for (i in seq_len(30L)) {
      key("Tab", modifiers = 8L)
      check_focus_visible(paste(stage, "Shift+Tab", i))
      reverse_copies[[i]] <- app$get_js(paste0("!!document.activeElement.closest('",
        root, " .dataTables_scrollBody thead')"))
      reached_x <- app$get_js(paste0("document.activeElement === document.querySelector('",
        filter(1L), "')"))
      if (isTRUE(reached_x)) break
    }
    expect_false(any(reverse_copies), info = paste(stage, "Shift+Tab reached a sizing copy"))
    expect_true(reached_x, info = paste(stage, "Shift+Tab did not reach X"))
  }

  app$wait_for_idle()
  app$set_inputs(main_nav_tabs = "data_provenance")
  app$wait_for_js(paste0("document.querySelector('", filter(1L), "') !== null"))
  observations <- read.csv(app$get_download("data_provenance-download"))
  expect_equal(nrow(observations), 200L)
  check_filters("initial")

  app$run_js(paste0("document.querySelector('", filter(1L), "').focus()"))
  browser$Input$insertText(text = "0 ... 1")
  key("Tab")
  expected <- sum(observations$X >= 0 & observations$X <= 1)
  expect_gt(expected, 0L)
  expect_lt(expected, 200L)
  app$wait_for_js(paste0(table, ".page.info().recordsDisplay === ", expected))
  rows <- unlist(app$get_js(paste0(table, ".column(0).data().toArray()")))
  expect_true(length(rows) > 0L && all(as.numeric(rows) >= 0 & as.numeric(rows) <= 1))
  check_filters("filtered redraw")

  app$run_js(paste0("document.querySelector('", filter(1L), "').focus()"))
  key("a", modifiers = 2L)
  key("Backspace")
  key("Tab")
  app$wait_for_js(paste0(table, ".page.info().recordsDisplay === 200"))
  app$click(selector = paste0(root, " .dataTables_scrollHead thead tr:first-child th:first-child"))
  app$wait_for_idle()
  app$click(selector = paste0(root, " .paginate_button.next"))
  app$wait_for_js(paste0(table, ".page.info().page === 1"))
  expect_equal(app$get_js(paste0(table, ".page.info().recordsDisplay")), 200L)
  check_filters("sorted and paginated redraw")
  app$set_window_size(width = 1100, height = 900)
  app$wait_for_idle()
  check_filters("resized columns")

  app$set_inputs(`configuration-model_type` = "lm_3d")
  app$wait_for_idle()
  app$wait_for_idle()
  app$wait_for_js(paste0("document.querySelector('", root,
    " .dataTables_scrollHead thead tr:first-child th:nth-child(2)').textContent === 'Y'"))
  check_filters("new analysis with Y", active_count = 5L)
  screenshot <- Sys.getenv("LMPLOT_DT_SCREENSHOT")
  if (nzchar(screenshot)) {
    writeBin(jsonlite::base64_dec(browser$Page$captureScreenshot()$data), screenshot)
  }
})
