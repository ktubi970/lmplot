source(file.path('..', 'app.R'), local = TRUE)

test_that('Overview coefficients and enriched CSV include each predictor unit', {
  fixture <- run_analysis_usecase(new_analysis_request(list(schema_version = 'lmplot-analysis-request/1.0',
    data_source = 'real', model_type = 'lm_3d', example_id = 'concrete_28d', grid_length_out = 3L)),
    create_analysis_services(), '..')
  shiny::testServer(overview_server, args = list(result = shiny::reactive(fixture)), {
    expect_match(output$coefficients, 'MPa per kg/m³', fixed = TRUE)
  })
  shiny::testServer(data_provenance_server, args = list(result = shiny::reactive(fixture)), {
    exported <- read.csv(output$download, check.names = FALSE)
    expect_identical(unique(exported$.x_unit), 'kg/m³')
    expect_identical(unique(exported$.y_unit), 'kg/m³')
    expect_identical(unique(exported$.response_unit), 'MPa')
  })
})

test_that('unit validation rejects empty supplied metadata and names the actual link scale', {
  fixture <- simulate_data('lm_2d', n = 30L, seed = 21L)
  fitted <- fit_model(fixture, 'lm_2d', 'identity')
  for (bad in list(list(x = ''), list(z = NA_character_), list(x = 'g', x = 'mm'), list(unknown = 'mm'))) {
    expect_error(build_model_brain(fitted, fixture, 'lm_2d', 'identity', units = bad), 'units')
  }
  metadata <- example_config('concrete_28d', '..'); metadata$predictor_y_unit <- ' '
  expect_error(example_units(metadata), 'non-empty')
  units <- list(x = 'mm', y = 'g', z = 'ha')
  expected <- c(identity = 'ha', log = 'log mean (response in ha)', inverse = '1/(ha)',
    sqrt = 'sqrt(ha)', logit = 'log-odds', probit = 'probit scale', cloglog = 'complementary log-log scale')
  for (link in names(expected)) expect_identical(.brain_units(units, link)$eta, unname(expected[link]))
})
