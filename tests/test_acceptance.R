source(file.path("..", "R", "config.R"))
source(file.path("..", "R", "model_registry.R"))
source(file.path("..", "R", "mod_model.R"))
source(file.path("..", "R", "mod_simulation.R"))
source(file.path("..", "R", "mod_visualization.R"))

test_that("the complete beta matrix executes end to end", {
  combinations <- do.call(rbind, lapply(model_ids(), function(id) {
    data.frame(
      model_type = id,
      link = valid_links(id),
      stringsAsFactors = FALSE
    )
  }))

  expect_equal(nrow(combinations), 15L)

  for (row in seq_len(nrow(combinations))) {
    model_type <- combinations$model_type[[row]]
    link <- combinations$link[[row]]
    combination <- paste(model_type, link, sep = "/")
    data <- simulate_data(model_type, link, n = 40L, seed = 100L + row)

    warnings <- character()
    fit <- withCallingHandlers(
      fit_model(data, model_type, link),
      warning = function(warning) {
        warnings <<- c(warnings, conditionMessage(warning))
        invokeRestart("muffleWarning")
      }
    )
    if (startsWith(model_type, "glm_binomial") && link == "cloglog") {
      expect_true(
        length(warnings) <= 1L && all(
          warnings == "glm.fit: fitted probabilities numerically 0 or 1 occurred"
        ),
        info = combination
      )
    } else {
      expect_identical(warnings, character(), info = combination)
    }

    plot <- build_main_plot(data, fit, model_type)
    enriched <- enrich_data(data, fit)

    expect_s3_class(plot, "plotly")
    expect_equal(nrow(enriched), nrow(data), info = combination)
    expect_true(
      all(c(".fitted", ".residual") %in% names(enriched)),
      info = combination
    )
    expect_true(all(is.finite(enriched$.fitted)), info = combination)
    expect_true(all(is.finite(enriched$.residual)), info = combination)
    expect_equal(
      enriched$.fitted,
      as.numeric(fitted_response(fit)),
      info = combination
    )
    expect_equal(
      enriched$.residual,
      as.numeric(response_residuals(fit)),
      info = combination
    )
  }
})
