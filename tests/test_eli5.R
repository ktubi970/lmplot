source(file.path("..", "R", "model_registry.R"))
source(file.path("..", "R", "mod_model.R"))
source(file.path("..", "R", "mod_simulation.R"))
source(file.path("..", "R", "mod_eli5.R"))
for (file in c("model_metrics.R", "model_diagnostics.R")) {
  path <- file.path("..", "R", file)
  if (file.exists(path)) source(path)
}

test_that("coefficient copy uses link-specific associations and conditional p-values", {
  identity <- explain_coefficient(.5, .01, link = "identity", term = "X")
  log <- explain_coefficient(.5, .01, link = "log", term = "X")
  logit <- explain_coefficient(.5, .01, link = "logit", term = "X")
  expect_match(identity, "response units")
  expect_match(log, "multiplicative")
  expect_match(logit, "odds ratio")
  for (text in c(identity, log, logit)) {
    expect_match(text, "assumptions")
    expect_false(grepl("chance of randomness|probability increases by 0.5|causes", text))
  }
  for (link in c("probit", "cloglog", "inverse", "sqrt")) {
    text <- explain_coefficient(.5, NA_real_, link, "X")
    expect_match(text, link)
    expect_match(text, "link scale")
    expect_false(grepl("odds ratio|multiplicative factor", text))
  }
})

test_that("Guided interpretation is deterministic for all 15 combinations", {
  count <- 0L
  for (id in model_ids()) for (link in valid_links(id)) {
    count <- count + 1L
    data <- simulate_data(id, link, n = 120L, seed = count)
    fit <- suppressWarnings(fit_model(data, id, link))
    result <- list(data = data, model_type = id, link = link,
      coefficients = extract_coefficient_table(fit, id, link),
      metrics = extract_model_metrics(fit, id, data), diagnostics = diagnose_model(fit, data, id))
    explanation <- guided_interpretation(result)
    expect_identical(explanation, guided_interpretation(result))
    expect_true(length(explanation$effects) >= 2)
    expect_true(nzchar(explanation$concept))
    expect_match(explanation$caution, "association")
    expect_false(any(grepl("Ollama|ELI5|chance of randomness|excellent|optimal", unlist(explanation), ignore.case = TRUE)))
    if (id == "glmm") expect_match(paste(explanation$effects, collapse = " "), "common random-effect")
  }
  expect_equal(count, 15L)
})

test_that("Guided interpretation renders an English public module", {
  html <- as.character(guided_interpretation_ui("guide"))
  expect_match(html, "Guided interpretation")
  expect_false(grepl("Ollama|ELI5|Assistant IA", html))
})
