source(file.path("..", "R", "model_registry.R"))
source(file.path("..", "R", "mod_model.R"))
source(file.path("..", "R", "mod_simulation.R"))
source(file.path("..", "R", "mod_visualization.R"))
examples_path <- file.path("..", "R", "mod_examples.R")
if (file.exists(examples_path)) source(examples_path)

test_that("prepared examples load, validate, and fit", {
  ids <- example_ids(root = "..")
  expect_equal(length(ids), 7L)
  for (id in ids) {
    example <- load_real_example(id, root = "..")
    config <- example_config(id, root = "..")
    expect_equal(nrow(example$analysis), config$expected_rows)
    expect_silent(validate_simulation_data(example$analysis, config$model_type))
    fit <- fit_model(example$analysis, config$model_type, config$default_link)
    expect_equal(length(fitted_response(fit)), config$expected_rows)
    expect_true(all(is.finite(fitted_response(fit))))
    expect_true(all(is.finite(response_residuals(fit))))
  }
})

test_that("prepared examples satisfy their exact domains", {
  binomial <- load_real_example("adelie_sex", root = "..")$analysis
  poisson <- load_real_example("abalone_rings", root = "..")$analysis
  gamma <- load_real_example("forest_fire_positive_area", root = "..")$analysis
  mixed <- load_real_example("inner_london_exam", root = "..")$analysis
  expect_true(all(binomial$Z %in% c(0, 1)))
  counts <- table(binomial$Z)
  expect_equal(as.integer(counts), c(73L, 73L))
  expect_equal(names(counts), c("0", "1"))
  expect_true(all(poisson$Z == floor(poisson$Z) & poisson$Z >= 0))
  expect_true(all(gamma$Z > 0))
  expect_equal(nlevels(mixed$Group), 65L)
})

test_that("each model resolves to its assigned scientific example", {
  expected <- c(
    lm_2d = "adelie_flipper_mass",
    lm_3d = "concrete_28d",
    glm_binomial = "adelie_sex",
    glm_poisson = "abalone_rings",
    glm_gamma = "forest_fire_positive_area",
    glmm = "inner_london_exam"
  )
  actual <- vapply(
    names(expected),
    example_for_model,
    character(1),
    root = ".."
  )
  expect_equal(actual, expected)
})

test_that("prepared examples retain exact source-role display columns", {
  expected <- list(
    adelie_flipper_mass = c(
      "Sample Number", "Flipper Length (mm)", "Body Mass (g)"
    ),
    concrete_28d = c(
      "source_row", "cement_kg_m3", "water_kg_m3", "strength_mpa"
    ),
    adelie_sex = c(
      "Sample Number", "Culmen Length (mm)", "Body Mass (g)", "Sex"
    ),
    abalone_rings = c(
      "source_row", "length_mm", "shell_weight_g", "rings"
    ),
    forest_fire_positive_area = c(
      "source_row", "temp_c", "rh_pct", "area_ha"
    ),
    inner_london_exam = c(
      "source_row", "standLRT", "schavg", "normexam", "school"
    )
  )
  for (id in names(expected)) {
    example <- load_real_example(id, root = "..")
    expect_equal(names(example$display), expected[[id]], info = id)
  }
})

test_that("example metadata retains exact scientific labels and units", {
  expected <- list(
    adelie_flipper_mass = c(
      response_label = "Body mass (g)",
      predictor_x_label = "Flipper length (mm)",
      predictor_y_label = ""
    ),
    concrete_28d = c(
      response_label = "Compressive strength (MPa)",
      predictor_x_label = "Cement (kg/m\u00b3)",
      predictor_y_label = "Water (kg/m\u00b3)"
    ),
    adelie_sex = c(
      response_label = "Probability molecular sex is female",
      predictor_x_label = "Bill length (mm)",
      predictor_y_label = "Body mass (g)"
    ),
    abalone_rings = c(
      response_label = "Expected ring count",
      predictor_x_label = "Shell length (mm)",
      predictor_y_label = "Dried shell weight (g)"
    ),
    forest_fire_positive_area = c(
      response_label = "Expected burned area given area > 0 (ha)",
      predictor_x_label = "Temperature (\u00b0C)",
      predictor_y_label = "Relative humidity (%)"
    ),
    inner_london_exam = c(
      response_label = "Normalized examination achievement",
      predictor_x_label = "Standardized London Reading Test",
      predictor_y_label = "School mean intake score"
    )
  )
  label_fields <- c(
    "response_label", "predictor_x_label", "predictor_y_label"
  )
  for (id in names(expected)) {
    metadata <- load_real_example(id, root = "..")$metadata
    actual <- vapply(
      label_fields,
      function(field) metadata[[field]],
      character(1)
    )
    expect_equal(actual, expected[[id]], info = id)
  }
})

test_that("real examples expose scientific plots and enriched diagnostics", {
  for (id in example_ids(root = "..")) {
    example <- load_real_example(id, root = "..")
    fit <- fit_model(
      example$analysis,
      example$metadata$model_type,
      example$metadata$default_link
    )

    plot <- example_plot(example, fit)
    enriched <- enrich_real_example(example, fit)

    expect_s3_class(plot, "plotly")
    built <- plotly::plotly_build(plot)
    expect_match(built$x$layout$title$text, example$metadata$title, fixed = TRUE)
    expect_equal(nrow(enriched), nrow(example$analysis))
    expect_true(all(c(".fitted", ".residual") %in% names(enriched)))
    expect_true(all(is.finite(enriched$.fitted)))
  }
})

test_that("GLMM example omits the unreadable 65-school legend", {
  example <- load_real_example("inner_london_exam", root = "..")
  fit <- fit_model(
    example$analysis,
    example$metadata$model_type,
    example$metadata$default_link
  )
  expect_warning(
    built <- plotly::plotly_build(example_plot(example, fit)),
    NA
  )
  expect_false(built$x$layout$showlegend)
})

test_that("all source hashes pass before any builder or writer runs", {
  root <- tempfile("real-example-root-")
  sources <- file.path(root, "data", "real", "sources")
  dir.create(sources, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  expect_true(file.copy(
    file.path("..", "data", "real", "manifest.csv"),
    file.path(root, "data", "real", "manifest.csv")
  ))
  committed_sources <- list.files(
    file.path("..", "data", "real", "sources"),
    full.names = TRUE
  )
  expect_true(all(file.copy(committed_sources, sources)))

  tampered <- file.path(sources, "adelie.csv")
  connection <- file(tampered, open = "ab")
  writeBin(as.raw(10L), connection)
  close(connection)

  output <- file.path(
    root, "data", "real", "adelie_flipper_mass", "model-data.csv"
  )
  dir.create(dirname(output), recursive = TRUE)
  sentinel <- charToRaw("reviewed-output-sentinel")
  writeBin(sentinel, output)

  expect_error(
    build_real_examples(root),
    paste0(
      "SHA-256 mismatch for adelie.csv: expected ",
      "76a2b8eeadc052b31753e525115698785a68299d07a827d63867446579cb9138",
      ", actual [0-9a-f]+"
    )
  )
  actual <- readBin(output, what = "raw", n = file.info(output)$size)
  expect_identical(actual, sentinel)
})
