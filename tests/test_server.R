source(file.path("..", "app.R"), local = TRUE)

rendered_html <- function(tag) {
  rendered <- htmltools::renderTags(tag)
  paste(rendered$head, rendered$html, collapse = "\n")
}

set_standard_inputs <- function(session, n = 80L, seed = 12L) {
  session$setInputs(
    `simulation-n` = n,
    `simulation-seed` = seed,
    `simulation-beta0` = 2,
    `simulation-beta1` = 0.5,
    `simulation-beta2` = -0.25,
    `simulation-sigma` = 1,
    `simulation-shape` = 2,
    `simulation-group_sd` = 1,
    `simulation-groups` = 5L,
    `simulation-expert_mode` = FALSE
  )
}

test_that("UI exposes beta identity and required controls", {
  html <- rendered_html(ui)

  expect_match(html, "0.9.0-beta.1", fixed = TRUE)
  expect_match(html, "model_type", fixed = TRUE)
  expect_match(html, "link_ui", fixed = TRUE)
  expect_match(html, "simulation-expert_mode", fixed = TRUE)
  expect_match(html, "generate", fixed = TRUE)
  expect_match(html, "download_data", fixed = TRUE)
})

test_that("dynamic link UI exposes only links valid for the selected model", {
  shiny::testServer(server, {
    session$setInputs(model_type = "glm_binomial")
    session$flushReact()
    link_html <- rendered_html(output$link_ui)
    expect_match(link_html, "logit", fixed = TRUE)
    expect_match(link_html, "probit", fixed = TRUE)
    expect_match(link_html, "cloglog", fixed = TRUE)
    expect_false(grepl("sqrt", link_html, fixed = TRUE))
    expect_false(grepl("inverse", link_html, fixed = TRUE))

    session$setInputs(model_type = "lm_2d")
    session$flushReact()
    fixed_html <- rendered_html(output$link_ui)
    expect_match(fixed_html, "identity", fixed = TRUE)
    expect_match(fixed_html, "link_sel", fixed = TRUE)
    expect_match(fixed_html, "<select", fixed = TRUE)
    expect_match(fixed_html, "display:none", fixed = TRUE)
  })
})

test_that("model transitions reset a shared valid link to the new default", {
  shiny::testServer(server, {
    session$setInputs(model_type = "glm_poisson")
    session$flushReact()
    session$setInputs(link_sel = "identity")
    set_standard_inputs(session)
    session$flushReact()

    session$setInputs(model_type = "glm_gamma", generate = 1L)
    session$flushReact()

    expect_identical(last_result()$model_type, "glm_gamma")
    expect_identical(last_result()$link, "inverse")
    gamma_html <- rendered_html(output$link_ui)
    expect_match(gamma_html, 'value="inverse" selected', fixed = TRUE)
  })
})

test_that("fixed-link models generate through a Shiny-bound link input", {
  shiny::testServer(server, {
    session$setInputs(model_type = "lm_2d")
    session$flushReact()

    fixed_html <- rendered_html(output$link_ui)
    expect_match(fixed_html, "<select", fixed = TRUE)
    expect_match(fixed_html, "identity", fixed = TRUE)

    set_standard_inputs(session)
    session$setInputs(generate = 1L)
    session$flushReact()
    expect_identical(last_result()$model_type, "lm_2d")
    expect_identical(last_result()$link, "identity")
  })
})

test_that("server generates plot summary diagnostics and table for all six modes", {
  cases <- list(
    lm_2d = "identity",
    lm_3d = "identity",
    glm_binomial = "probit",
    glm_poisson = "log",
    glm_gamma = "log",
    glmm = "identity"
  )

  for (model_type in names(cases)) {
    link <- cases[[model_type]]
    shiny::testServer(server, {
      session$setInputs(model_type = model_type)
      session$flushReact()
      if (length(valid_links(model_type)) > 1L) {
        session$setInputs(link_sel = link)
      }
      set_standard_inputs(session)
      session$setInputs(generate = 1L, show_surface = TRUE)
      session$flushReact()

      result <- last_result()
      expect_identical(result$model_type, model_type, info = model_type)
      expect_identical(result$link, link, info = model_type)
      expect_equal(nrow(result$data), 80L, info = model_type)
      expect_false(is.null(output$main_plot), info = model_type)
      expect_true(length(output$model_summary) > 0L, info = model_type)
      expect_false(is.null(output$diag_plots), info = model_type)
      expect_false(is.null(output$data_table), info = model_type)
    })
  }
})

test_that("model and link changes do not replace the last generated snapshot", {
  shiny::testServer(server, {
    session$setInputs(model_type = "lm_2d")
    session$flushReact()
    set_standard_inputs(session, seed = 41L)
    session$setInputs(generate = 1L)
    session$flushReact()
    first <- last_result()

    session$setInputs(
      `simulation-n` = 120L,
      `simulation-beta1` = 1.25
    )
    session$flushReact()
    expect_identical(last_result(), first)

    session$setInputs(model_type = "glm_binomial")
    session$flushReact()
    session$setInputs(link_sel = "probit")
    session$flushReact()

    expect_identical(last_result(), first)
    expect_identical(first$model_type, "lm_2d")
    expect_identical(first$link, "identity")
    expect_identical(names(first$data), c("X", "Z"))

    session$setInputs(generate = 2L)
    session$flushReact()
    second <- last_result()
    expect_identical(second$model_type, "glm_binomial")
    expect_identical(second$link, "probit")
    expect_identical(names(second$data), c("X", "Y", "Z"))
  })
})

test_that("a failed generation leaves the last successful result visible", {
  notifications <- list()
  rlang::local_bindings(
    showNotification = function(ui, type = NULL, ...) {
      notifications[[length(notifications) + 1L]] <<- list(
        message = as.character(ui),
        type = type
      )
      invisible("notification")
    },
    .env = environment(server)
  )

  shiny::testServer(server, {
    session$setInputs(model_type = "lm_2d")
    session$flushReact()
    set_standard_inputs(session, n = 80L, seed = 17L)
    session$setInputs(generate = 1L)
    session$flushReact()
    successful <- last_result()

    set_standard_inputs(session, n = 1L, seed = 18L)
    session$setInputs(generate = 2L)
    session$flushReact()

    expect_identical(last_result(), successful)
    expect_false(is.null(output$main_plot))
    expect_gt(length(output$model_summary), 0L)
    expect_false(is.null(output$data_table))
  })

  expect_identical(notifications[[length(notifications)]]$type, "error")
})

test_that("fit warnings notify non-fatally and are muffled narrowly", {
  notifications <- list()
  real_fit_model <- get("fit_model", envir = environment(server))
  rlang::local_bindings(
    fit_model = function(...) {
      warning("deliberate fit warning", call. = FALSE)
      real_fit_model(...)
    },
    showNotification = function(ui, type = NULL, ...) {
      notifications[[length(notifications) + 1L]] <<- list(
        message = as.character(ui),
        type = type
      )
      invisible("notification")
    },
    .env = environment(server)
  )

  expect_silent(shiny::testServer(server, {
    session$setInputs(model_type = "lm_2d")
    session$flushReact()
    set_standard_inputs(session)
    session$setInputs(generate = 1L)
    session$flushReact()
    expect_identical(last_result()$model_type, "lm_2d")
  }))

  expect_true(any(vapply(notifications, function(x) {
    identical(x$type, "warning") && grepl("deliberate fit warning", x$message, fixed = TRUE)
  }, logical(1))))
})

test_that("trusted-local expert mode uses canonical evaluation and output paths", {
  shiny::testServer(server, {
    session$setInputs(model_type = "lm_2d")
    session$flushReact()
    set_standard_inputs(session, n = 60L, seed = 27L)
    session$setInputs(
      `simulation-expert_mode` = TRUE,
      `simulation-code` = paste(
        "simulate_data(model_type = 'lm_2d', link = 'identity',",
        "n = n, seed = seed, beta0 = beta0, beta1 = beta1, sigma = sigma)"
      )
    )
    session$setInputs(generate = 1L)
    session$flushReact()

    result <- last_result()
    expect_identical(result$model_type, "lm_2d")
    expect_equal(nrow(result$data), 60L)
    expect_match(result$code, "simulate_data", fixed = TRUE)
    expect_false(is.null(output$main_plot))
    expect_gt(length(output$model_summary), 0L)
    expect_false(is.null(output$data_table))
  })
})

test_that("download data is enriched from the same last successful result", {
  shiny::testServer(server, {
    session$setInputs(model_type = "glm_poisson")
    session$flushReact()
    session$setInputs(link_sel = "log")
    set_standard_inputs(session, n = 75L, seed = 33L)
    session$setInputs(generate = 1L)
    session$flushReact()

    expected <- enrich_data(last_result()$data, last_result()$fit)
    download <- output$download_data
    expect_true(file.exists(download))
    downloaded <- utils::read.csv(download)
    expect_identical(names(downloaded), names(expected))
    expect_equal(downloaded, expected, tolerance = 1e-12)
  })
})
