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

set_link_choice <- function(session, model_type, link) {
  default_link <- model_config(model_type)$default_link
  session$setInputs(link_sel = default_link)
  session$flushReact()
  if (!identical(link, default_link)) {
    session$setInputs(link_sel = link)
    session$flushReact()
  }
}

test_that("UI exposes beta identity and required controls", {
  html <- rendered_html(ui)

  expect_match(html, "0.9.0-beta.1", fixed = TRUE)
  expect_match(html, "model_type", fixed = TRUE)
  expect_match(html, "link_ui", fixed = TRUE)
  expect_match(html, "simulation-expert_mode", fixed = TRUE)
  expect_match(html, "generate", fixed = TRUE)
  expect_match(html, "surface_ui", fixed = TRUE)
  expect_false(grepl("show_surface", html, fixed = TRUE))
  expect_match(html, "download_data", fixed = TRUE)
})

test_that("UI exposes simulation and real-data sources", {
  html <- rendered_html(ui)

  expect_match(html, "data_source", fixed = TRUE)
  expect_match(html, "Real data", fixed = TRUE)
  expect_match(html, "example_info", fixed = TRUE)
})

test_that("UI controls, dynamic links, and link transitions react correctly", {
  shiny::testServer(server, {
    # Surface control visibility
    session$setInputs(model_type = "lm_2d")
    session$flushReact()
    expect_false(grepl(
      "show_surface",
      rendered_html(output$surface_ui),
      fixed = TRUE
    ))

    session$setInputs(model_type = "lm_3d")
    session$flushReact()
    surface_html <- rendered_html(output$surface_ui)
    expect_match(surface_html, "show_surface", fixed = TRUE)
    expect_match(surface_html, "checked", fixed = TRUE)

    session$setInputs(model_type = "glmm")
    session$flushReact()
    controls_html <- rendered_html(output$`simulation-controls_ui`)
    expect_match(controls_html, 'id="simulation-groups"', fixed = TRUE)
    expect_match(controls_html, 'min="5"', fixed = TRUE)

    # Dynamic link UI
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
    expect_match(fixed_html, 'type="hidden"', fixed = TRUE)

    # Real-data links
    session$setInputs(model_type = "glm_gamma", data_source = "real")
    session$flushReact()
    link_html <- rendered_html(output$link_ui)
    expect_match(link_html, "log (literature-backed)", fixed = TRUE)
    expect_match(link_html, "inverse (exploratory)", fixed = TRUE)
    expect_match(link_html, "identity (exploratory)", fixed = TRUE)
    expect_match(link_html, 'value="log" selected', fixed = TRUE)

    # Model transitions reset shared valid link
    session$setInputs(data_source = "simulation", model_type = "glm_poisson")
    session$flushReact()
    set_link_choice(session, "glm_poisson", "identity")
    set_standard_inputs(session, n = 40L)
    session$flushReact()

    session$setInputs(model_type = "glm_gamma", generate = 1L)
    session$flushReact()

    expect_identical(last_result()$model_type, "glm_gamma")
    expect_identical(last_result()$link, "inverse")
    gamma_html <- rendered_html(output$link_ui)
    expect_match(gamma_html, 'value="inverse" selected', fixed = TRUE)

    # Delayed link events
    session$setInputs(model_type = "glm_poisson")
    session$flushReact()
    set_link_choice(session, "glm_poisson", "identity")
    expect_identical(selected_link(), "identity")

    session$setInputs(model_type = "glm_gamma")
    session$flushReact()
    expect_identical(selected_link(), "inverse")

    session$setInputs(link_sel = "identity")
    session$flushReact()
    expect_identical(selected_link(), "inverse")

    session$setInputs(link_sel = "inverse")
    session$flushReact()
    session$setInputs(link_sel = "log")
    session$flushReact()
    expect_identical(selected_link(), "log")

    set_standard_inputs(session, n = 40L)
    session$setInputs(generate = 2L)
    session$flushReact()
    expect_identical(last_result()$model_type, "glm_gamma")
    expect_identical(last_result()$link, "log")

    # Fixed-link models generate
    session$setInputs(model_type = "lm_2d")
    session$flushReact()
    fixed_html <- rendered_html(output$link_ui)
    expect_match(fixed_html, 'type="hidden"', fixed = TRUE)
    expect_match(fixed_html, "identity", fixed = TRUE)

    set_standard_inputs(session, n = 40L)
    session$setInputs(generate = 3L)
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

  shiny::testServer(server, {
    for (model_type in names(cases)) {
      link <- cases[[model_type]]
      session$setInputs(model_type = model_type)
      session$flushReact()
      if (length(valid_links(model_type)) > 1L) {
        set_link_choice(session, model_type, link)
      }
      set_standard_inputs(session, n = 40L)
      session$setInputs(generate = 1L, show_surface = TRUE)
      session$flushReact()

      result <- last_result()
      expect_identical(result$model_type, model_type, info = model_type)
      expect_identical(result$link, link, info = model_type)
      expect_equal(nrow(result$data), 40L, info = model_type)
      expect_false(is.null(output$main_plot), info = model_type)
      expect_true(length(output$model_summary) > 0L, info = model_type)
      coefficient_html <- output$coef_table_ui$html
      expected_method <- if (model_type == "glmm") "Unavailable for this model" else if (startsWith(model_type, "glm")) "Wald" else "Student t"
      expect_match(coefficient_html, expected_method, info = model_type)
      expect_false(grepl("Adéquat|bien respectée|successful convergence", output$linearity_diag_banner$html))
      expect_false(is.null(output$diag_plots), info = model_type)
      expect_false(is.null(output$data_table), info = model_type)
    }
  })
})

test_that("server fits every real-data example without evaluating simulation", {
  real_links <- c(
    lm_2d = "identity",
    lm_3d = "identity",
    glm_binomial = "logit",
    glm_poisson = "log",
    glm_gamma = "log",
    glmm = "identity"
  )
  real_rows <- c(
    lm_2d = 151L,
    lm_3d = 425L,
    glm_binomial = 146L,
    glm_poisson = 4177L,
    glm_gamma = 270L,
    glmm = 4059L
  )
  rlang::local_bindings(
    simulate_data = function(...) {
      stop("Simulation must remain lazy in real-data mode", call. = FALSE)
    },
    .env = environment(server)
  )

  shiny::testServer(server, {
    for (model_type in names(real_links)) {
      session$setInputs(model_type = model_type, data_source = "real")
      session$flushReact()
      session$setInputs(
        generate = shiny::isolate(input$generate %||% 0L) + 1L,
        show_surface = TRUE
      )
      session$flushReact()

      result <- last_result()
      expect_identical(result$model_type, model_type, info = model_type)
      expect_identical(result$link, real_links[[model_type]], info = model_type)
      expect_equal(nrow(result$data), real_rows[[model_type]], info = model_type)
      expect_false(is.null(result$example), info = model_type)
      expect_false(is.null(output$main_plot), info = model_type)
      info <- rendered_html(output$example_info)
      expect_match(info, "Publication", fixed = TRUE, info = model_type)
      expect_match(info, "Dataset", fixed = TRUE, info = model_type)
      expect_match(info, "License", fixed = TRUE, info = model_type)
      expect_match(info, "Rows", fixed = TRUE, info = model_type)
      expect_false(is.null(output$data_table), info = model_type)
      displayed <- display_result(result)
      expect_equal(nrow(displayed), real_rows[[model_type]], info = model_type)
      expect_true(
        all(c(".fitted", ".residual") %in% names(displayed)),
        info = model_type
      )
    }
  })
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
    set_link_choice(session, "glm_binomial", "probit")
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

test_that("invalid expert GLMM data preserves the previous result and CSV", {
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
    set_standard_inputs(session, n = 60L, seed = 29L)
    session$setInputs(generate = 1L)
    session$flushReact()
    successful <- last_result()
    expected <- enrich_data(successful$data, successful$fit)

    session$setInputs(model_type = "glmm")
    session$flushReact()
    session$setInputs(
      `simulation-expert_mode` = TRUE,
      `simulation-code` = paste(
        "data.frame(X = seq_len(n), Y = seq_len(n), Z = seq_len(n),",
        "Group = rep(1:4, length.out = n))"
      )
    )
    session$setInputs(generate = 2L)
    session$flushReact()

    expect_identical(last_result(), successful)
    download <- output$download_data
    downloaded <- utils::read.csv(download)
    expect_identical(names(downloaded), names(expected))
    expect_equal(downloaded, expected, tolerance = 1e-12)
  })

  expect_true(any(vapply(notifications, function(notification) {
    identical(notification$type, "error") &&
      grepl("at least 5 observed groups", notification$message, fixed = TRUE)
  }, logical(1))))
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
    set_link_choice(session, "glm_poisson", "log")
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
