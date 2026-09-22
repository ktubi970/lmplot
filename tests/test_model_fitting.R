source(file.path("..", "R", "model_registry.R"))
source(file.path("..", "R", "mod_model.R"))

example_glmm_frame <- function() {
  group <- rep(seq_len(5L), each = 12L)
  x <- rep(seq(-1, 1, length.out = 12L), 5L)
  y <- rep(seq(-0.75, 0.75, length.out = 4L), length.out = length(group))
  noise <- rep(c(-0.13, 0.05, 0.10, -0.08, 0.03, -0.04), length.out = length(group))

  data.frame(
    X = x,
    Y = y,
    Z = 1 + 0.6 * x - 0.3 * y + rep(c(-1, -0.5, 0, 0.5, 1), each = 12L) + noise,
    Group = group
  )
}

test_that("every registry entry resolves a named fit strategy", {
  expect_setequal(
    unique(vapply(MODEL_REGISTRY, function(x) x$fit_strategy, character(1))),
    names(FIT_STRATEGIES)
  )
})

test_that("GLMM reports a dependency error when lme4 is unavailable", {
  expect_error(
    fit_glmm_strategy(
      example_glmm_frame(),
      "identity",
      namespace_available = function(pkg) FALSE
    ),
    "requires the lme4 package"
  )
})

test_that("GLMM never returns an lm or lme fallback", {
  skip_if_not_installed("lme4")

  fit <- fit_model(example_glmm_frame(), "glmm", "identity")

  expect_s4_class(fit, "merMod")
})

test_that("lm_2d ignores an extra Y column", {
  data <- data.frame(
    X = seq_len(12L),
    Y = rep(c(-10, 10), each = 6L),
    Z = 4 + 2 * seq_len(12L)
  )

  fit <- fit_model(data, "lm_2d", "identity")

  expect_equal(attr(stats::terms(fit), "term.labels"), "X")
})
