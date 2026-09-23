source(file.path("..", "app.R"), local = TRUE)

scientific_plot_specs <- list(
  adelie_flipper_mass = list(
    model_type = "lm_2d",
    family = "Simple LM (2D)",
    x = "Flipper length (mm)",
    z = "Body mass (g)"
  ),
  concrete_28d = list(
    model_type = "lm_3d",
    family = "Multiple LM (3D)",
    x = "Cement (kg/m\u00b3)",
    y = "Water (kg/m\u00b3)",
    z = "Compressive strength (MPa)"
  ),
  adelie_sex = list(
    model_type = "glm_binomial",
    family = "Binomial GLM",
    x = "Bill length (mm)",
    y = "Body mass (g)",
    z = "Probability molecular sex is female",
    observed = 'Female indicator (0/1)'
  ),
  abalone_rings = list(
    model_type = "glm_poisson",
    family = "Poisson GLM",
    x = "Shell length (mm)",
    y = "Dried shell weight (g)",
    z = "Expected ring count",
    observed = 'Observed ring count'
  ),
  forest_fire_positive_area = list(
    model_type = "glm_gamma",
    family = "Gamma GLM",
    x = "Temperature (\u00b0C)",
    y = "Relative humidity (%)",
    z = "Expected burned area given area > 0 (ha)",
    observed = 'Burned area (ha)'
  ),
  inner_london_exam = list(
    model_type = "glmm",
    family = "Gaussian GLMM",
    x = "Standardized London Reading Test",
    y = "School mean intake score",
    z = "Normalized examination achievement",
    group = "School"
  )
)

.real_plot_cache <- new.env(parent = emptyenv())
built_real_plot <- function(example_id) {
  if (exists(example_id, envir = .real_plot_cache, inherits = FALSE)) {
    return(get(example_id, envir = .real_plot_cache))
  }
  example <- load_real_example(example_id, root = "..")
  fit <- fit_model(
    example$analysis,
    example$metadata$model_type,
    example$metadata$default_link
  )
  res <- plotly::plotly_build(example_plot(example, fit))
  assign(example_id, res, envir = .real_plot_cache)
  res
}

trace_hover_content <- function(trace) {
  paste(
    c(trace$hovertemplate %||% character(), trace$text %||% character()),
    collapse = "\n"
  )
}

expect_scientific_hover <- function(traces, labels, example_id, role) {
  expect_true(length(traces) > 0L, info = paste(example_id, role))
  content <- vapply(traces, trace_hover_content, character(1))
  expect_true(
    all(nzchar(content)),
    info = paste(example_id, role, "explicit hover")
  )
  for (label in unlist(labels, use.names = FALSE)) {
    expect_true(
      all(grepl(label, content, fixed = TRUE)),
      info = paste(example_id, role, label)
    )
  }
  expect_false(
    any(grepl("(^|<br>)(X|Y|Z|Group):", content, perl = TRUE)),
    info = paste(example_id, role, "canonical hover label")
  )
}

test_that("all real Plotly traces use literal scientific hover labels", {
  for (example_id in names(scientific_plot_specs)) {
    spec <- scientific_plot_specs[[example_id]]
    built <- built_real_plot(example_id)
    observed <- Filter(function(trace) {
      trace$type %in% c("scatter", "scatter3d") &&
        identical(trace$mode, "markers")
    }, built$x$data)

    observed_labels <- spec[c('x', 'y', 'z', 'group')]
    observed_labels$z <- spec$observed %||% spec$z
    expect_scientific_hover(
      observed,
      observed_labels,
      example_id,
      "observed"
    )
    expect_true(
      all(vapply(
        observed,
        function(trace) {
          length(trace$hoverinfo) > 0L && all(trace$hoverinfo == "text")
        },
        logical(1)
      )),
      info = paste(example_id, "observed hover mode")
    )

    if (identical(spec$model_type, "lm_2d")) {
      fitted <- Filter(function(trace) {
        identical(trace$type, "scatter") &&
          identical(trace$mode, "lines")
      }, built$x$data)
      expect_scientific_hover(
        fitted,
        spec[c("x", "z")],
        example_id,
        "fitted"
      )
    } else {
      surface <- Filter(function(trace) {
        identical(trace$type, "surface")
      }, built$x$data)
      expect_scientific_hover(
        surface,
        spec[c("x", "y", "z")],
        example_id,
        "surface"
      )
    }
  }
})

test_that("real plot titles include exact model family labels and citations", {
  expected_titles <- c(
    adelie_flipper_mass = "Ad\u00e9lie penguin body mass",
    concrete_28d = "28-day concrete compressive strength",
    adelie_sex = "Ad\u00e9lie penguin sex from morphology",
    abalone_rings = "Abalone shell-ring count",
    forest_fire_positive_area = "Positive forest-fire burned area",
    inner_london_exam = "Inner London examination achievement"
  )
  for (example_id in names(scientific_plot_specs)) {
    built <- built_real_plot(example_id)
    title <- built$x$layout$title$text
    expect_match(
      title, expected_titles[[example_id]], fixed = TRUE,
      info = example_id
    )
    expect_match(
      title,
      scientific_plot_specs[[example_id]]$family,
      fixed = TRUE,
      info = example_id
    )
    expect_match(title, "Publication", fixed = TRUE, info = example_id)
  }
})

test_that("simulation plots retain generic canonical axes without labels", {
  fit_beta_model <- function(model_type) {
    link <- model_config(model_type)$default_link
    data <- simulate_data(model_type, link, seed = 71L)
    list(
      data = data,
      fit = fit_model(data, model_type, link)
    )
  }
  two_d <- fit_beta_model("lm_2d")
  two_d_built <- plotly::plotly_build(
    build_main_plot(two_d$data, two_d$fit, "lm_2d")
  )
  expect_identical(two_d_built$x$layout$xaxis$title, "X")
  expect_identical(two_d_built$x$layout$yaxis$title, "Z")

  three_d <- fit_beta_model("lm_3d")
  three_d_built <- plotly::plotly_build(
    build_main_plot(three_d$data, three_d$fit, "lm_3d")
  )
  expect_identical(three_d_built$x$layout$scene$xaxis$title, "X")
  expect_identical(three_d_built$x$layout$scene$yaxis$title, "Y")
  expect_identical(three_d_built$x$layout$scene$zaxis$title, "Z")
})

scientific_provenance_specs <- list(
  lm_2d = list(
    family = "Simple LM (2D)",
    link = "identity",
    response = c("Body mass (g)", "Body Mass (g)"),
    x = c("Flipper length (mm)", "Flipper Length (mm)"),
    preprocessing = paste(
      "From 152 Ad\u00e9lie source rows, retain complete finite flipper",
      "length and body mass values; remove 1 incomplete row, retain 151",
      "rows, and apply no unit conversion."
    ),
    interpretation = paste(
      "Descriptive within-species association; sex, island, and year",
      "are omitted."
    )
  ),
  lm_3d = list(
    family = "Multiple LM (3D)",
    link = "identity",
    response = c(
      "Compressive strength (MPa)",
      "Concrete compressive strength(MPa, megapascals)"
    ),
    x = c("Cement (kg/m\u00b3)", "Cement (component 1)(kg in a m^3 mixture)"),
    y = c("Water (kg/m\u00b3)", "Water  (component 4)(kg in a m^3 mixture)"),
    preprocessing = paste(
      "Verify and extract Concrete_Data.xls, retain rows with age exactly",
      "28 days, and map cement, water, and compressive strength; retain",
      "425 rows with kg/m\u00b3 and MPa unchanged."
    ),
    interpretation = paste(
      "Educational additive plane at fixed age 28 days; the published",
      "engineering relationship is nonlinear and uses more ingredients."
    )
  ),
  glm_binomial = list(
    family = "Binomial GLM",
    link = "logit",
    response = c("Probability molecular sex is female", "Sex"),
    x = c("Bill length (mm)", "Culmen Length (mm)"),
    y = c("Body mass (g)", "Body Mass (g)"),
    preprocessing = paste(
      "From 152 Ad\u00e9lie source rows, retain finite culmen length and",
      "body mass with Sex equal to FEMALE or MALE, sort by Sample Number,",
      "and encode FEMALE = 1 and MALE = 0; retain 146 rows (73/73)."
    ),
    interpretation = paste(
      "Full-data pedagogical fit of a paper-supported two-predictor model;",
      "the paper used splitting and model averaging."
    )
  ),
  glm_poisson = list(
    family = "Poisson GLM",
    link = "log",
    response = c("Expected ring count", "Rings"),
    x = c("Shell length (mm)", "Length"),
    y = c("Dried shell weight (g)", "Shell_weight"),
    preprocessing = paste(
      "Retain all 4,177 source rows, convert normalized Length and",
      "Shell_weight by \u00d7200 to millimetres and grams, and keep integer",
      "Rings unchanged."
    ),
    interpretation = paste(
      "Associative Poisson mean model with moderate underdispersion and",
      "correlated size predictors."
    )
  ),
  glm_gamma = list(
    family = "Gamma GLM",
    link = "log",
    response = c("Expected burned area given area &gt; 0 (ha)", "area"),
    x = c("Temperature (\u00b0C)", "temp"),
    y = c("Relative humidity (%)", "RH"),
    preprocessing = paste(
      "From 517 source rows, retain area &gt; 0, remove 247 zero-area rows,",
      "and retain 270 rows; temperature (\u00b0C), relative humidity (%),",
      "and area (ha) remain unchanged."
    ),
    interpretation = paste(
      "Conditional severity model after excluding 247 zero-area records;",
      "not an occurrence model."
    )
  ),
  glmm = list(
    family = "Gaussian GLMM",
    link = "identity",
    response = c("Normalized examination achievement", "normexam"),
    x = c("Standardized London Reading Test", "standLRT"),
    y = c("School mean intake score", "schavg"),
    group = c("School", "school"),
    preprocessing = paste(
      "Verify and extract Exam.rda, retain all 4,059 rows, order and",
      "factor school into 65 levels, and map standLRT, schavg, and",
      "normexam; apply no unit conversion."
    ),
    interpretation = paste(
      "Two-continuous-predictor teaching specification of a richer",
      "published multilevel analysis."
    )
  )
)

rendered_scientific_html <- function(tag) {
  rendered <- htmltools::renderTags(tag)
  paste(rendered$head, rendered$html, collapse = "\n")
}

test_that("every real provenance card defines variables and preprocessing", {
  shiny::testServer(server, {
    session$flushReact()
    generation <- 0L
    for (model_type in names(scientific_provenance_specs)) {
      session$setInputs(`configuration-model_type` = model_type, `configuration-data_source` = "real")
      session$flushReact()
      generation <- generation + 1L
      session$setInputs(`configuration-generate` = generation)
      info <- rendered_scientific_html(output$`data_provenance-provenance`)
      expected <- scientific_provenance_specs[[model_type]]

      expect_match(info, "Model family", fixed = TRUE, info = model_type)
      expect_match(info, expected$family, fixed = TRUE, info = model_type)
      expect_match(
        info,
        "Literature-backed default link",
        fixed = TRUE,
        info = model_type
      )
      expect_match(info, expected$link, fixed = TRUE, info = model_type)
      expect_match(info, "Response", fixed = TRUE, info = model_type)
      expect_match(info, "Predictor X", fixed = TRUE, info = model_type)
      if (!is.null(expected$y)) {
        expect_match(info, "Predictor Y", fixed = TRUE, info = model_type)
      }
      if (!is.null(expected$group)) {
        expect_match(info, "Group", fixed = TRUE, info = model_type)
      }
      variable_text <- unlist(
        expected[c("response", "x", "y", "group")],
        use.names = FALSE
      )
      for (text in variable_text) {
        expect_match(info, text, fixed = TRUE, info = model_type)
      }
      expect_match(info, "Preparation", fixed = TRUE, info = model_type)
      expect_match(
        info,
        expected$preprocessing,
        fixed = TRUE,
        info = model_type
      )
      expect_match(
        info,
        "Adaptation and limitations",
        fixed = TRUE,
        info = model_type
      )
      expect_match(
        info,
        expected$interpretation,
        fixed = TRUE,
        info = model_type
      )
    }
  })
})
