source(file.path('..', 'app.R'), local = TRUE)

copy_example <- function(id) {
  metadata <- example_config(id, '..')
  run_analysis_usecase(new_analysis_request(list(schema_version = 'lmplot-analysis-request/1.0',
    data_source = 'real', model_type = metadata$model_type, example_id = id,
    link = metadata$default_link, grid_length_out = 3L)), create_analysis_services(), '..')
}

test_that('documented real units reach the strict Brain and exported chart data', {
  expected <- list(adelie_flipper_mass = c('mm', NA, 'g'), concrete_28d = c('kg/m³', 'kg/m³', 'MPa'),
    adelie_sex = c('mm', 'g', 'dimensionless'), adelie_sex_2d = c('mm', NA, 'dimensionless'),
    abalone_rings = c('mm', 'g', 'rings'), forest_fire_positive_area = c('°C', '%', 'ha'),
    inner_london_exam = c('standardized score', 'standardized score', 'normalized score'))
  for (id in names(expected)) {
    result <- copy_example(id); want <- expected[[id]]
    expect_identical(unname(vapply(result$model_brain$units[1:3], function(x) x %||% NA_character_, character(1))), want, info = id)
    expect_silent(validate_model_brain(result$model_brain))
    observed <- analysis_chart_observations(result); grid <- analysis_chart_grid(result)
    expect_identical(unique(observed$response_unit), want[3], info = id)
    expect_identical(unique(grid$x_unit), want[1], info = id)
    if (!is.na(want[2])) expect_identical(unique(grid$y_unit), want[2], info = id)
    view <- brain_view_data(result$model_brain, 1L)
    expect_match(exact_equation_view(view)$summary, want[3], fixed = TRUE)
    expect_identical(unique(link_transformation_plot(view)$table$response_unit), want[3])
    plot <- plotly::plotly_build(render_analysis_main_plot(result))
    expect_true(all(grepl(want[3], plot$x$data[[1L]]$text, fixed = TRUE)), info = id)
    expect_true(all(grepl(paste0('Response residual (', want[3], ')'), plot$x$data[[1L]]$text, fixed = TRUE)), info = id)
  }
})

test_that('observations and fitted means use distinct scientifically correct chart labels', {
  cases <- c(adelie_sex_2d = 'Female indicator (0/1)', adelie_sex = 'Female indicator (0/1)',
    abalone_rings = 'Observed ring count', forest_fire_positive_area = 'Burned area (ha)')
  for (id in names(cases)) {
    result <- copy_example(id); built <- plotly::plotly_build(render_analysis_main_plot(result))
    observed <- built$x$data[[1L]]; predicted <- built$x$data[[2L]]
    expect_true(all(grepl(cases[[id]], observed$text, fixed = TRUE)), info = id)
    expect_false(any(grepl('Probability|Expected', observed$text)), info = id)
    axis <- if (model_config(result$model_type)$dimensions == 2L) built$x$layout$yaxis else built$x$layout$scene$zaxis
    expect_match(if (is.list(axis$title)) axis$title$text else axis$title, cases[[id]], fixed = TRUE)
    expect_match(predicted$hovertemplate, result$example$metadata$response_label, fixed = TRUE)
    expect_match(predicted$hovertemplate, 'Predicted')
    expect_identical(unique(analysis_chart_observations(result)$observed_response_label), cases[[id]])
    expect_match(unique(analysis_chart_grid(result)$predicted_response_label), result$example$metadata$response_label, fixed = TRUE)
    legacy <- plotly::plotly_build(example_plot(result$example, result$fit))
    expect_true(all(grepl(cases[[id]], legacy$x$data[[1L]]$text, fixed = TRUE)))
  }
})

test_that('coefficient units distinguish predictor units and transformed link scales', {
  mass <- copy_example('adelie_flipper_mass'); view <- brain_view_data(mass$model_brain, 1L)
  expect_identical(coefficient_overview_plot(view)$table$units, c('g', 'g per mm'))
  expect_identical(brain_contribution_table(view)$input_unit, c('dimensionless', 'mm'))
  expect_identical(brain_contribution_table(view)$coefficient_unit, c('g', 'g per mm'))
  sex <- copy_example('adelie_sex')
  expect_identical(coefficient_overview_plot(brain_view_data(sex$model_brain, 1L))$table$units,
    c('log-odds', 'log-odds per mm', 'log-odds per g'))
  invalid <- mass$model_brain; invalid$units$x <- ' '
  expect_error(validate_model_brain(invalid), 'invalid units')
  expect_error(build_model_brain(mass$fit, mass$data, 'lm_2d', 'identity', units = list(x = ' ')), 'units')
})

test_that('GLMM diagnostic and enriched exports identify conditional predictions without refitting', {
  fixture <- copy_example('inner_london_exam')
  fail <- function(...) stop('Scientific recomputation during navigation')
  rlang::local_bindings(fit_model = fail, predict_response = fail, build_model_brain = fail,
    .env = environment(overview_server))
  shiny::testServer(diagnostics_server, args = list(result = shiny::reactive(fixture)), {
    expect_match(output$chart_summary, 'conditional')
    expect_match(output$chart_summary, 'random intercepts')
    expect_match(output$chart_summary, 'population')
    expect_match(output$summary, 'conditional')
  })
  shiny::testServer(data_provenance_server, args = list(result = shiny::reactive(fixture)), {
    expect_match(output$table, 'conditional'); expect_match(output$table, 'population')
    downloaded <- read.csv(output$download, check.names = FALSE)
    expect_identical(unique(downloaded$.prediction_mode), 'conditional')
    expect_identical(unique(downloaded$.response_unit), 'normalized score')
    expect_equal(downloaded$.fitted, vapply(analysis_observations(fixture), `[[`, numeric(1), 'prediction'))
  })
  for (mode in c('conditional', 'population')) {
    view <- brain_view_data(fixture$model_brain, 12L, mode)
    expect_identical(view$observation$prediction_mode, mode)
    expect_identical(view$units$z, 'normalized score')
    expect_match(exact_equation_view(view)$summary, 'normalized score')
  }
  selection <- shiny::reactiveVal(list(observation_id = '12', generation = 1L))
  shiny::testServer(model_brain_server, args = list(result = shiny::reactive(fixture),
    generation = shiny::reactive(1L), selection = selection,
    select_observation = function(event) selection(event)), {
    expect_match(output$observation_summary, 'normalized score')
    session$setInputs(observation_index = 15L, prediction_mode = 'population')
    expect_match(output$observation_summary, 'population')
    expect_match(output$observation_summary, 'normalized score')
  })
})
