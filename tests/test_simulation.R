source(file.path("..", "R", "mod_model.R"))
source(file.path("..", "R", "mod_simulation.R"))

acceptance_matrix <- do.call(rbind, lapply(model_ids(), function(id) {
  data.frame(model_type = id, link = valid_links(id), stringsAsFactors = FALSE)
}))

test_that("all beta combinations simulate deterministically", {
  expect_equal(nrow(acceptance_matrix), 12L)
  for (row in seq_len(nrow(acceptance_matrix))) {
    args <- acceptance_matrix[row, ]
    first <- simulate_data(args$model_type, args$link, n = 80L, seed = 42L)
    second <- simulate_data(args$model_type, args$link, n = 80L, seed = 42L)
    expect_identical(first, second, info = paste(args, collapse = "/"))
    expect_equal(nrow(first), 80L)
    expect_silent(validate_simulation_data(first, args$model_type))
  }
})

test_that("simulated responses respect their domains", {
  binomial <- simulate_data("glm_binomial", "probit", seed = 2L)
  poisson <- simulate_data("glm_poisson", "sqrt", seed = 2L)
  gamma <- simulate_data("glm_gamma", "log", seed = 2L)
  mixed <- simulate_data("glmm", "identity", n = 103L, seed = 2L)
  expect_true(all(binomial$Z %in% c(0, 1)))
  expect_true(all(poisson$Z >= 0 & poisson$Z == floor(poisson$Z)))
  expect_true(all(is.finite(gamma$Z) & gamma$Z > 0))
  expect_gte(length(unique(mixed$Group)), 5L)
})

test_that("standard GLMM simulation enforces the group-count contract", {
  expect_error(
    simulate_data("glmm", "identity", n = 80L, groups = 2L),
    "GLMM groups must be a single integer of at least 5",
    fixed = TRUE
  )
  expect_error(
    simulate_data("glmm", "identity", n = 10L, groups = 11L),
    "GLMM groups must not exceed sample size n",
    fixed = TRUE
  )
  expect_error(
    simulate_data("glmm", "identity", n = 80L, groups = 5.5),
    "GLMM groups must be a single integer of at least 5",
    fixed = TRUE
  )
})

test_that("GLMM simulation data requires complete membership in five observed groups", {
  valid <- simulate_data("glmm", "identity", n = 80L, groups = 5L)

  missing_group <- valid
  missing_group$Group[[1L]] <- NA
  expect_error(
    validate_simulation_data(missing_group, "glmm"),
    "GLMM Group must not contain missing values",
    fixed = TRUE
  )

  too_few_groups <- valid
  too_few_groups$Group <- rep(1:4, length.out = nrow(too_few_groups))
  expect_error(
    validate_simulation_data(too_few_groups, "glmm"),
    "GLMM data must contain at least 5 observed groups",
    fixed = TRUE
  )
})

test_that("expert evaluation rejects invalid output", {
  expect_error(
    evaluate_expert_simulation("data.frame(X = 1:3)", list(), "lm_2d", "identity"),
    "required columns"
  )

  expect_error(
    evaluate_expert_simulation(
      "data.frame(X = 1:20, Y = 1:20, Z = 1:20, Group = rep(1:4, 5))",
      list(),
      "glmm",
      "identity"
    ),
    "at least 5 observed groups",
    fixed = TRUE
  )
})
