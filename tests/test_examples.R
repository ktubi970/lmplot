source(file.path("..", "R", "mod_model.R"))
source(file.path("..", "R", "mod_simulation.R"))
examples_path <- file.path("..", "R", "mod_examples.R")
if (file.exists(examples_path)) source(examples_path)

test_that("six prepared examples load, validate, and fit", {
  ids <- example_ids(root = "..")
  expect_equal(length(ids), 6L)
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
