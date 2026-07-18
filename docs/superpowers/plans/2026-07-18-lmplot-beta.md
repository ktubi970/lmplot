# LM Plot Explorer 0.9.0-beta.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the verified `0.9.0-beta.1` Shiny application described in `docs/superpowers/specs/2026-07-18-lmplot-beta-design.md`.

**Architecture:** Keep `app.R` as a thin composition root. Put version/configuration, model behavior, simulation behavior, and visualization behavior in focused `R/` files with ordinary-value interfaces that are testable outside Shiny; connect them through one event-driven Shiny flow.

**Tech Stack:** R 4.6.x, Shiny, bslib, Plotly, ggplot2, ggfortify, DT, lme4, shinyWidgets, shinyAce, testthat, shinytest2, renv.

## Global Constraints

- The visible and programmatic version is exactly `0.9.0-beta.1`.
- Preserve `lm_2d`, `lm_3d`, `glm_binomial`, `glm_poisson`, `glm_gamma`, and `glmm`.
- The acceptance matrix contains exactly 12 model/link combinations.
- GLM predictions used by plots and downloads come from `predict(..., type = "response")` through a model helper.
- Model/link changes update controls immediately but only Generate & Fit replaces the last successful result.
- Expert R code is documented as trusted-local-only and is evaluated in an isolated environment.
- Do not stage or overwrite unrelated pre-existing worktree changes.
- Use `C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe` for Windows verification commands.

## File Structure

| Path | Responsibility |
|---|---|
| `R/config.R` | Version and application constants |
| `R/mod_model.R` | Registry, validation, fits, response predictions/residuals |
| `R/mod_simulation.R` | Pure simulation, expert evaluation, Shiny simulation module |
| `R/mod_visualization.R` | Prediction grids, Plotly, diagnostics, enriched data |
| `app.R` | UI and reactive orchestration only |
| `tests/test_config.R` | Version contract |
| `tests/test_model.R` | Registry and 12-combination model contract |
| `tests/test_simulation.R` | Simulation and expert-mode contract |
| `tests/test_visualization.R` | Plot/grid/download-data contract |
| `tests/test_server.R` | Shiny reactive contract |
| `tests/test_app.R` | Real-browser smoke workflow |
| `README.md`, `renv.lock`, `run.bat`, `TODO.md` | Reproducibility and release truth |

---

### Task 1: Version Contract and Model Registry

**Files:**
- Create: `R/config.R`
- Create: `R/mod_model.R`
- Create: `tests/test_config.R`
- Create: `tests/test_model.R`

**Interfaces:**
- Consumes: no project interfaces.
- Produces: `APP_VERSION`, `MODEL_REGISTRY`, `model_ids()`, `model_config(model_type)`, `valid_links(model_type)`, and `validate_model_link(model_type, link)`.

- [ ] **Step 1: Write failing version and registry tests**

```r
# tests/test_config.R
config_path <- file.path("..", "R", "config.R")
if (file.exists(config_path)) source(config_path)

test_that("beta version is exact", {
  expect_true(exists("APP_VERSION", inherits = TRUE))
  expect_identical(APP_VERSION, "0.9.0-beta.1")
})

# tests/test_model.R
model_path <- file.path("..", "R", "mod_model.R")
if (file.exists(model_path)) source(model_path)

expected_matrix <- list(
  lm_2d = "identity",
  lm_3d = "identity",
  glm_binomial = c("logit", "probit", "cloglog"),
  glm_poisson = c("log", "identity", "sqrt"),
  glm_gamma = c("inverse", "log", "identity"),
  glmm = "identity"
)

test_that("registry exposes the beta acceptance matrix", {
  expect_true(exists("MODEL_REGISTRY", inherits = TRUE))
  expect_setequal(model_ids(), names(expected_matrix))
  expect_identical(unname(lapply(model_ids(), valid_links)), unname(expected_matrix))
  expect_equal(sum(lengths(lapply(model_ids(), valid_links))), 12L)
})

test_that("invalid models and links fail explicitly", {
  expect_error(model_config("unknown"), "Unknown model type")
  expect_error(validate_model_link("glm_binomial", "identity"), "Invalid link")
})
```

- [ ] **Step 2: Run the tests and confirm the missing-contract failure**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_config.R'); testthat::test_file('tests/test_model.R')"
```

Expected: FAIL because `APP_VERSION` and `MODEL_REGISTRY` do not exist.

- [ ] **Step 3: Implement the version and registry**

```r
# R/config.R
APP_VERSION <- "0.9.0-beta.1"

# R/mod_model.R
MODEL_REGISTRY <- list(
  lm_2d = list(label = "Simple LM (2D)", family = "gaussian", links = "identity", default_link = "identity", dimensions = 2L, requires_group = FALSE),
  lm_3d = list(label = "Multiple LM (3D)", family = "gaussian", links = "identity", default_link = "identity", dimensions = 3L, requires_group = FALSE),
  glm_binomial = list(label = "Binomial GLM", family = "binomial", links = c("logit", "probit", "cloglog"), default_link = "logit", dimensions = 3L, requires_group = FALSE),
  glm_poisson = list(label = "Poisson GLM", family = "poisson", links = c("log", "identity", "sqrt"), default_link = "log", dimensions = 3L, requires_group = FALSE),
  glm_gamma = list(label = "Gamma GLM", family = "Gamma", links = c("inverse", "log", "identity"), default_link = "inverse", dimensions = 3L, requires_group = FALSE),
  glmm = list(label = "Gaussian GLMM", family = "gaussian", links = "identity", default_link = "identity", dimensions = 3L, requires_group = TRUE)
)

model_ids <- function() names(MODEL_REGISTRY)

model_config <- function(model_type) {
  config <- MODEL_REGISTRY[[model_type]]
  if (is.null(config)) stop("Unknown model type: ", model_type, call. = FALSE)
  c(list(id = model_type), config)
}

valid_links <- function(model_type) model_config(model_type)$links

validate_model_link <- function(model_type, link = NULL) {
  config <- model_config(model_type)
  selected <- link %||% config$default_link
  if (!selected %in% config$links) {
    stop("Invalid link '", selected, "' for model '", model_type, "'", call. = FALSE)
  }
  selected
}

`%||%` <- function(left, right) if (is.null(left) || length(left) == 0L) right else left
```

- [ ] **Step 4: Run the focused tests and full existing unit suite**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_dir('tests', reporter='summary')"
```

Expected: new tests PASS; existing browser test may still SKIP until Task 7.

- [ ] **Step 5: Commit the registry contract**

```powershell
git add R/config.R R/mod_model.R tests/test_config.R tests/test_model.R
git commit -m "feat: define beta model registry"
```

---

### Task 2: Deterministic Simulation Engine

**Files:**
- Modify: `R/mod_simulation.R`
- Create: `tests/test_simulation.R`

**Interfaces:**
- Consumes: `model_config()`, `validate_model_link()` from `R/mod_model.R`.
- Produces: `simulate_data()`, `validate_simulation_data()`, `evaluate_expert_simulation()`, and `simulation_code()`.

- [ ] **Step 1: Write failing matrix, determinism, and domain tests**

```r
# tests/test_simulation.R
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

test_that("expert evaluation rejects invalid output", {
  expect_error(
    evaluate_expert_simulation("data.frame(X = 1:3)", list(), "lm_2d", "identity"),
    "required columns"
  )
})
```

- [ ] **Step 2: Run the simulation tests and confirm the new API is missing**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_simulation.R')"
```

Expected: FAIL because `simulate_data()` does not exist.

- [ ] **Step 3: Implement pure simulation and validation helpers**

Replace the current data-generation behavior in `R/mod_simulation.R` with helpers following this exact contract:

```r
simulate_data <- function(model_type, link = NULL, n = 200L, seed = 123L,
                          beta0 = 2, beta1 = 0.5, beta2 = -0.25,
                          sigma = 1, shape = 2, group_sd = 1, groups = 5L) {
  config <- model_config(model_type)
  link <- validate_model_link(model_type, link)
  stopifnot(n >= 10L, groups >= 2L, sigma > 0, shape > 0, group_sd >= 0)
  set.seed(as.integer(seed))
  X <- stats::runif(n, -1, 1)
  Y <- stats::runif(n, -1, 1)
  eta <- beta0 + beta1 * X + beta2 * Y

  if (model_type == "lm_2d") {
    result <- data.frame(X = X, Z = beta0 + beta1 * X + stats::rnorm(n, 0, sigma))
  } else if (model_type == "lm_3d") {
    result <- data.frame(X = X, Y = Y, Z = eta + stats::rnorm(n, 0, sigma))
  } else if (model_type == "glmm") {
    Group <- factor(rep(seq_len(groups), length.out = n))
    offsets <- stats::rnorm(groups, 0, group_sd)
    Z <- eta + offsets[as.integer(Group)] + stats::rnorm(n, 0, sigma)
    result <- data.frame(X = X, Y = Y, Z = Z, Group = Group)
  } else {
    family_object <- do.call(config$family, list(link = link))
    mu <- family_object$linkinv(eta)
    if (any(!is.finite(mu))) stop("Selected coefficients produce non-finite means", call. = FALSE)
    if (config$family == "binomial") {
      mu <- pmin(pmax(mu, .Machine$double.eps), 1 - .Machine$double.eps)
      Z <- stats::rbinom(n, 1, mu)
    } else if (config$family == "poisson") {
      if (any(mu <= 0)) stop("Selected coefficients produce non-positive Poisson means", call. = FALSE)
      Z <- stats::rpois(n, mu)
    } else {
      if (any(mu <= 0)) stop("Selected coefficients produce non-positive Gamma means", call. = FALSE)
      Z <- stats::rgamma(n, shape = shape, rate = shape / mu)
    }
    result <- data.frame(X = X, Y = Y, Z = Z)
  }
  validate_simulation_data(result, model_type)
  result
}

validate_simulation_data <- function(df, model_type) {
  config <- model_config(model_type)
  required <- c("X", "Z", if (config$dimensions == 3L) "Y", if (config$requires_group) "Group")
  missing <- setdiff(required, names(df))
  if (!is.data.frame(df) || length(missing)) stop("Simulation must return a data frame with required columns: ", paste(required, collapse = ", "), call. = FALSE)
  numeric_columns <- intersect(c("X", "Y", "Z"), required)
  if (any(!vapply(df[numeric_columns], is.numeric, logical(1)))) stop("Simulation columns X, Y, and Z must be numeric", call. = FALSE)
  if (any(!is.finite(as.matrix(df[numeric_columns])))) stop("Simulation contains non-finite values", call. = FALSE)
  if (model_type == "glm_binomial" && any(!df$Z %in% c(0, 1))) stop("Binomial response must contain only 0 and 1", call. = FALSE)
  if (model_type == "glm_poisson" && any(df$Z < 0 | df$Z != floor(df$Z))) stop("Poisson response must contain non-negative integers", call. = FALSE)
  if (model_type == "glm_gamma" && any(df$Z <= 0)) stop("Gamma response must be strictly positive", call. = FALSE)
  invisible(df)
}

evaluate_expert_simulation <- function(code, parameters, model_type, link = NULL) {
  environment <- list2env(c(parameters, list(simulate_data = simulate_data)), parent = baseenv())
  result <- eval(parse(text = code), envir = environment)
  validate_simulation_data(result, model_type)
  result
}

simulation_code <- function(model_type, link, parameters) {
  call <- as.call(c(quote(simulate_data), list(model_type = model_type, link = link), parameters))
  paste(deparse(call, width.cutoff = 100L), collapse = "\n")
}
```

- [ ] **Step 4: Run simulation tests and the full unit suite**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_simulation.R'); testthat::test_dir('tests', reporter='summary')"
```

Expected: simulation tests PASS and no existing unit regression.

- [ ] **Step 5: Commit the simulation engine**

```powershell
git add R/mod_simulation.R tests/test_simulation.R
git commit -m "feat: add deterministic beta simulations"
```

---

### Task 3: Fit, Predict, and Residual Contract

**Files:**
- Modify: `R/mod_model.R`
- Modify: `tests/test_model.R`

**Interfaces:**
- Consumes: canonical data frames from `simulate_data()`.
- Produces: `fit_model()`, `predict_response()`, `fitted_response()`, and `response_residuals()`.

- [ ] **Step 1: Add a failing 12-combination fitting test**

```r
source(file.path("..", "R", "mod_simulation.R"))

test_that("every beta combination fits and returns response-scale values", {
  matrix <- do.call(rbind, lapply(model_ids(), function(id) {
    data.frame(model_type = id, link = valid_links(id), stringsAsFactors = FALSE)
  }))
  for (row in seq_len(nrow(matrix))) {
    model_type <- matrix$model_type[[row]]
    link <- matrix$link[[row]]
    df <- simulate_data(model_type, link, n = 120L, seed = row)
    fit <- fit_model(df, model_type, link)
    expected_class <- if (model_type == "glmm") "lmerMod" else if (startsWith(model_type, "glm_")) "glm" else "lm"
    if (model_type == "glmm") expect_s4_class(fit, "lmerMod", info = model_type)
    else expect_s3_class(fit, expected_class, info = model_type)
    expect_length(fitted_response(fit), nrow(df))
    expect_length(response_residuals(fit), nrow(df))
    expect_true(all(is.finite(fitted_response(fit))))
  }
})
```

- [ ] **Step 2: Run the model test and confirm `fit_model()` is missing from the module**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_model.R')"
```

Expected: FAIL because the modular `fit_model()` contract is absent.

- [ ] **Step 3: Implement fitting and response helpers**

```r
required_model_columns <- function(model_type) {
  config <- model_config(model_type)
  c("X", "Z", if (config$dimensions == 3L) "Y", if (config$requires_group) "Group")
}

fit_model <- function(df, model_type, link = NULL) {
  config <- model_config(model_type)
  link <- validate_model_link(model_type, link)
  missing <- setdiff(required_model_columns(model_type), names(df))
  if (length(missing)) stop("Missing model columns: ", paste(missing, collapse = ", "), call. = FALSE)
  numeric <- intersect(c("X", "Y", "Z"), required_model_columns(model_type))
  if (any(!vapply(df[numeric], is.numeric, logical(1))) || any(!is.finite(as.matrix(df[numeric])))) {
    stop("Model data must contain finite numeric predictors and response", call. = FALSE)
  }
  if (model_type == "glm_binomial" && any(!df$Z %in% c(0, 1))) stop("Binomial response must contain only 0 and 1", call. = FALSE)
  if (model_type == "glm_poisson" && any(df$Z < 0 | df$Z != floor(df$Z))) stop("Poisson response must contain non-negative integers", call. = FALSE)
  if (model_type == "glm_gamma" && any(df$Z <= 0)) stop("Gamma response must be strictly positive", call. = FALSE)
  if (model_type == "lm_2d") return(stats::lm(Z ~ X, data = df))
  if (model_type == "lm_3d") return(stats::lm(Z ~ X + Y, data = df))
  if (model_type == "glmm") return(lme4::lmer(Z ~ X + Y + (1 | Group), data = df))
  family_object <- do.call(config$family, list(link = link))
  stats::glm(Z ~ X + Y, data = df, family = family_object)
}

predict_response <- function(fit, newdata = NULL, population = FALSE) {
  if (inherits(fit, "glm")) return(stats::predict(fit, newdata = newdata, type = "response"))
  if (inherits(fit, "merMod")) return(stats::predict(fit, newdata = newdata, re.form = if (population) NA else NULL, allow.new.levels = TRUE))
  stats::predict(fit, newdata = newdata)
}

fitted_response <- function(fit) as.numeric(predict_response(fit))

response_residuals <- function(fit) {
  observed <- stats::model.response(stats::model.frame(fit))
  as.numeric(observed - fitted_response(fit))
}
```

- [ ] **Step 4: Run model and simulation tests**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_model.R'); testthat::test_file('tests/test_simulation.R')"
```

Expected: 12 combinations PASS with finite fitted values and residuals.

- [ ] **Step 5: Commit the model contract**

```powershell
git add R/mod_model.R tests/test_model.R
git commit -m "feat: fit and predict beta model matrix"
```

---

### Task 4: Visualization and Enriched Data

**Files:**
- Create: `R/mod_visualization.R`
- Create: `tests/test_visualization.R`

**Interfaces:**
- Consumes: `model_config()`, `predict_response()`, `fitted_response()`, and `response_residuals()`.
- Produces: `prediction_grid()`, `build_main_plot()`, `build_diagnostic_plot()`, and `enrich_data()`.

- [ ] **Step 1: Write failing grid, plot, and enrichment tests**

```r
# tests/test_visualization.R
source(file.path("..", "R", "mod_model.R"))
source(file.path("..", "R", "mod_simulation.R"))
visualization_path <- file.path("..", "R", "mod_visualization.R")
if (file.exists(visualization_path)) source(visualization_path)

test_that("2D and 3D models produce finite plotting objects", {
  for (model_type in c("lm_2d", "glm_binomial", "glm_gamma", "glmm")) {
    link <- model_config(model_type)$default_link
    df <- simulate_data(model_type, link, seed = 10L)
    fit <- fit_model(df, model_type, link)
    grid <- prediction_grid(df, fit, model_type, length_out = 12L)
    expect_true(all(is.finite(grid$.fitted)))
    expect_s3_class(build_main_plot(df, fit, model_type), "plotly")
    enriched <- enrich_data(df, fit)
    expect_true(all(c(".fitted", ".residual") %in% names(enriched)))
    expect_equal(nrow(enriched), nrow(df))
  }
})
```

- [ ] **Step 2: Run the visualization test and confirm the API is missing**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_visualization.R')"
```

Expected: FAIL because `prediction_grid()` and `build_main_plot()` do not exist.

- [ ] **Step 3: Implement prediction grids and enriched data**

```r
prediction_grid <- function(df, fit, model_type, length_out = 30L) {
  config <- model_config(model_type)
  x <- seq(min(df$X), max(df$X), length.out = length_out)
  if (config$dimensions == 2L) {
    grid <- data.frame(X = x)
  } else {
    y <- seq(min(df$Y), max(df$Y), length.out = length_out)
    grid <- expand.grid(X = x, Y = y)
    if (config$requires_group) grid$Group <- factor(levels(df$Group)[1L], levels = levels(df$Group))
  }
  grid$.fitted <- as.numeric(predict_response(fit, grid, population = config$requires_group))
  grid
}

enrich_data <- function(df, fit) {
  df$.fitted <- fitted_response(fit)
  df$.residual <- response_residuals(fit)
  df
}

build_main_plot <- function(df, fit, model_type, show_surface = TRUE) {
  config <- model_config(model_type)
  enriched <- enrich_data(df, fit)
  if (config$dimensions == 2L) {
    curve <- enriched[order(enriched$X), ]
    return(plotly::plot_ly(
      enriched, x = ~X, y = ~Z, type = "scatter", mode = "markers",
      text = ~sprintf("X: %.3f<br>Z: %.3f<br>Residual: %.3f", X, Z, .residual),
      hoverinfo = "text", marker = list(color = "#2563eb", opacity = 0.65)
    ) |>
      plotly::add_lines(data = curve, x = ~X, y = ~.fitted,
                        name = "Fitted", line = list(color = "#ef4444")) |>
      plotly::layout(xaxis = list(title = "X"), yaxis = list(title = "Z")))
  }

  markers <- if (config$requires_group) {
    plotly::plot_ly(enriched, x = ~X, y = ~Y, z = ~Z, color = ~Group,
                    type = "scatter3d", mode = "markers", marker = list(size = 4))
  } else {
    plotly::plot_ly(enriched, x = ~X, y = ~Y, z = ~Z,
                    type = "scatter3d", mode = "markers",
                    marker = list(size = 4, color = "#2563eb", opacity = 0.7))
  }
  if (isTRUE(show_surface)) {
    grid <- prediction_grid(df, fit, model_type)
    x <- sort(unique(grid$X)); y <- sort(unique(grid$Y))
    z <- t(matrix(grid$.fitted, nrow = length(x), ncol = length(y)))
    markers <- plotly::add_surface(markers, x = x, y = y, z = z,
                                   opacity = 0.45, showscale = FALSE,
                                   name = "Population fit")
  }
  plotly::layout(markers, scene = list(
    xaxis = list(title = "X"), yaxis = list(title = "Y"), zaxis = list(title = "Z")
  ))
}

build_diagnostic_plot <- function(fit) {
  if (!inherits(fit, "merMod")) {
    return(ggfortify::autoplot(fit, which = 1:4, ncol = 2, colour = "#2563eb"))
  }
  fitted <- fitted_response(fit)
  residual <- response_residuals(fit)
  qq <- stats::qqnorm(residual, plot.it = FALSE)
  diagnostics <- rbind(
    data.frame(panel = "Residuals vs fitted", x = fitted, y = residual),
    data.frame(panel = "Normal Q-Q", x = qq$x, y = qq$y)
  )
  ggplot2::ggplot(diagnostics, ggplot2::aes(x, y)) +
    ggplot2::geom_point(alpha = 0.65, colour = "#2563eb") +
    ggplot2::facet_wrap(~panel, scales = "free") +
    ggplot2::theme_minimal()
}
```

- [ ] **Step 4: Run visualization and model tests**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_visualization.R'); testthat::test_file('tests/test_model.R')"
```

Expected: both suites PASS without non-finite surfaces.

- [ ] **Step 5: Commit visualization helpers**

```powershell
git add R/mod_visualization.R tests/test_visualization.R
git commit -m "feat: add beta visualization helpers"
```

---

### Task 5: Event-Driven Shiny Composition

**Files:**
- Modify: `R/mod_simulation.R`
- Replace: `app.R`
- Modify: `www/style.css`
- Create: `tests/test_server.R`
- Delete: `tests/test_helpers.R`

**Interfaces:**
- Consumes: all helper interfaces from Tasks 1–4.
- Produces: `sim_ui(id)`, `sim_server(id, model_type, link, trigger)`, `ui`, and `server`.

- [ ] **Step 1: Write failing UI and server contract tests**

```r
# tests/test_server.R
source(file.path("..", "app.R"), local = TRUE)

test_that("UI exposes beta identity and required controls", {
  rendered <- htmltools::renderTags(ui)
  html <- paste(rendered$head, rendered$html, collapse = "\n")
  expect_match(html, "0.9.0-beta.1", fixed = TRUE)
  expect_match(html, "model_type", fixed = TRUE)
  expect_match(html, "link_ui", fixed = TRUE)
  expect_match(html, "download_data", fixed = TRUE)
})

test_that("server renders the last generated result", {
  shiny::testServer(server, {
    session$setInputs(model_type = "glm_binomial")
    session$setInputs(link_sel = "probit")
    session$setInputs(`simulation-n` = 80, `simulation-seed` = 12,
                      `simulation-beta0` = 2, `simulation-beta1` = 0.5,
                      `simulation-beta2` = -0.25, `simulation-expert_mode` = FALSE)
    session$setInputs(generate = 1)
    session$flushReact()
    expect_false(is.null(output$main_plot))
    expect_gt(length(output$model_summary), 0L)
    expect_false(is.null(output$data_table))
  })
})
```

- [ ] **Step 2: Run the server tests and confirm the beta UI contract fails**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_server.R')"
```

Expected: FAIL because the version, link selector, module controls, and download are absent.

- [ ] **Step 3: Implement the simulation Shiny module**

```r
sim_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shinyWidgets::switchInput(ns("expert_mode"), "Simulation mode",
                              onLabel = "Expert", offLabel = "Standard", value = FALSE),
    shiny::uiOutput(ns("controls_ui"))
  )
}

sim_server <- function(id, model_type, link, trigger) {
  shiny::moduleServer(id, function(input, output, session) {
    output$controls_ui <- shiny::renderUI({
      config <- model_config(model_type())
      if (isTRUE(input$expert_mode)) {
        default_code <- simulation_code(model_type(), link(), list(n = 200L, seed = 123L))
        return(shinyAce::aceEditor(session$ns("code"), value = default_code,
                                   mode = "r", theme = "monokai", height = "220px"))
      }
      controls <- list(
        shiny::numericInput(session$ns("n"), "Sample size", 200L, min = 10L, max = 2000L),
        shiny::numericInput(session$ns("seed"), "Seed", 123L),
        shiny::sliderInput(session$ns("beta0"), "Intercept", -3, 5, 2, step = 0.1),
        shiny::sliderInput(session$ns("beta1"), "X coefficient", -2, 2, 0.5, step = 0.1)
      )
      if (config$dimensions == 3L) controls <- c(controls, list(
        shiny::sliderInput(session$ns("beta2"), "Y coefficient", -2, 2, -0.25, step = 0.1)
      ))
      if (model_type() %in% c("lm_2d", "lm_3d", "glmm")) controls <- c(controls, list(
        shiny::sliderInput(session$ns("sigma"), "Noise sigma", 0.1, 5, 1, step = 0.1)
      ))
      if (model_type() == "glm_gamma") controls <- c(controls, list(
        shiny::sliderInput(session$ns("shape"), "Gamma shape", 0.5, 10, 2, step = 0.5)
      ))
      if (model_type() == "glmm") controls <- c(controls, list(
        shiny::sliderInput(session$ns("group_sd"), "Group SD", 0, 4, 1, step = 0.1),
        shiny::numericInput(session$ns("groups"), "Groups", 5L, min = 2L, max = 20L)
      ))
      do.call(shiny::tagList, controls)
    })

    shiny::eventReactive(trigger(), {
      parameters <- list(
        n = input$n %||% 200L, seed = input$seed %||% 123L,
        beta0 = input$beta0 %||% 2, beta1 = input$beta1 %||% 0.5,
        beta2 = input$beta2 %||% -0.25, sigma = input$sigma %||% 1,
        shape = input$shape %||% 2, group_sd = input$group_sd %||% 1,
        groups = input$groups %||% 5L
      )
      code <- if (isTRUE(input$expert_mode)) input$code else simulation_code(model_type(), link(), parameters)
      data <- if (isTRUE(input$expert_mode)) {
        evaluate_expert_simulation(code, parameters, model_type(), link())
      } else {
        do.call(simulate_data, c(list(model_type = model_type(), link = link()), parameters))
      }
      list(data = data, code = code, parameters = parameters)
    }, ignoreInit = TRUE)
  })
}
```

- [ ] **Step 4: Replace `app.R` with thin composition**

```r
library(shiny)
library(bslib)
library(plotly)
library(DT)

source("R/config.R")
source("R/mod_model.R")
source("R/mod_simulation.R")
source("R/mod_visualization.R")

model_choices <- stats::setNames(model_ids(), vapply(MODEL_REGISTRY, `[[`, character(1), "label"))

ui <- bslib::page_sidebar(
  title = shiny::div("LM Plot Explorer ", shiny::span(APP_VERSION, class = "version-badge")),
  theme = bslib::bs_theme(version = 5, bootswatch = "flatly", primary = "#2563eb"),
  sidebar = bslib::sidebar(
    shiny::selectInput("model_type", "Model", choices = model_choices, selected = "lm_3d"),
    shiny::uiOutput("link_ui"),
    sim_ui("simulation"),
    shiny::actionButton("generate", "Generate & Fit", class = "btn-primary w-100"),
    shiny::checkboxInput("show_surface", "Show fitted surface", TRUE),
    shiny::downloadButton("download_data", "Download enriched CSV", class = "w-100")
  ),
  bslib::layout_column_wrap(
    width = 1,
    bslib::card(full_screen = TRUE, bslib::card_header("Visualization"),
                plotly::plotlyOutput("main_plot", height = "480px")),
    bslib::layout_column_wrap(
      width = 1 / 2,
      bslib::card(bslib::card_header("Model summary"), shiny::verbatimTextOutput("model_summary")),
      bslib::card(bslib::card_header("Simulation code"), shiny::verbatimTextOutput("sim_code")),
      bslib::navset_card_tab(
        title = "Diagnostics & data",
        bslib::nav_panel("Diagnostics", shiny::plotOutput("diag_plots", height = "380px")),
        bslib::nav_panel("Data", DT::DTOutput("data_table"))
      )
    )
  )
)

server <- function(input, output, session) {
output$link_ui <- renderUI({
  config <- model_config(input$model_type)
  if (length(config$links) == 1L) return(tags$input(id = "link_sel", type = "hidden", value = config$default_link))
  selectInput("link_sel", "Link", choices = config$links, selected = config$default_link)
})

selected_link <- reactive({
  config <- model_config(input$model_type)
  candidate <- input$link_sel %||% config$default_link
  if (!candidate %in% config$links) candidate <- config$default_link
  validate_model_link(input$model_type, candidate)
})
simulation <- sim_server("simulation", reactive(input$model_type), selected_link, reactive(input$generate))
last_result <- reactiveVal(NULL)

observeEvent(simulation(), {
  tryCatch({
    generated <- simulation()
    fit <- withCallingHandlers(
      fit_model(generated$data, input$model_type, selected_link()),
      warning = function(warning) {
        showNotification(conditionMessage(warning), type = "warning")
        invokeRestart("muffleWarning")
      }
    )
    last_result(list(data = generated$data, fit = fit, model_type = input$model_type,
                     link = selected_link(), code = generated$code))
  }, error = function(error) {
    showNotification(conditionMessage(error), type = "error")
  })
})

output$main_plot <- plotly::renderPlotly({
  result <- last_result(); shiny::req(result)
  build_main_plot(result$data, result$fit, result$model_type, input$show_surface)
})
output$model_summary <- shiny::renderPrint({ result <- last_result(); shiny::req(result); summary(result$fit) })
output$sim_code <- shiny::renderText({ result <- last_result(); shiny::req(result); result$code })
output$diag_plots <- shiny::renderPlot({ result <- last_result(); shiny::req(result); print(build_diagnostic_plot(result$fit)) })
output$data_table <- DT::renderDT({ result <- last_result(); shiny::req(result); DT::datatable(enrich_data(result$data, result$fit), options = list(pageLength = 8)) })
output$download_data <- shiny::downloadHandler(
  filename = function() paste0("lmplot-", Sys.Date(), ".csv"),
  content = function(file) {
    result <- last_result(); shiny::req(result)
    utils::write.csv(enrich_data(result$data, result$fit), file, row.names = FALSE)
  }
)
}

shiny::shinyApp(ui, server)
```

- [ ] **Step 5: Update CSS and remove stale helper tests**

```css
.version-badge { display: inline-block; margin-left: .5rem; padding: .15rem .5rem; border-radius: 999px; background: #dbeafe; color: #1d4ed8; font-size: .75rem; font-weight: 700; }
.bslib-sidebar-layout > .sidebar { border-right: 1px solid #dbe3ee; }
.card { border: 0; box-shadow: 0 10px 30px rgba(15, 23, 42, .08); }
#main_plot { min-height: 420px; }
.shiny-output-error-validation { color: #b91c1c; padding: 1rem; }
@media (max-width: 768px) { #main_plot { min-height: 360px; } }
```

Delete `tests/test_helpers.R`; its inline helper contract is superseded by `tests/test_model.R`, `tests/test_simulation.R`, and `tests/test_visualization.R`.

- [ ] **Step 6: Run server and full unit tests**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_server.R'); testthat::test_dir('tests', reporter='summary')"
```

Expected: server tests PASS; browser test is the only permitted skip before Task 7.

- [ ] **Step 7: Commit the Shiny integration**

```powershell
git add app.R R/mod_simulation.R www/style.css tests/test_server.R
git rm tests/test_helpers.R
git commit -m "feat: integrate event-driven beta UI"
```

---

### Task 6: Reproducible Beta Runtime and Documentation

**Files:**
- Create: `README.md`
- Create: `renv.lock`
- Modify: `run.bat`
- Modify: `.gitignore`
- Modify: `TODO.md`

**Interfaces:**
- Consumes: the final package imports and launch command.
- Produces: reproducible restore, test, and launch workflows.

- [ ] **Step 1: Write a failing release-truth test**

```r
# tests/test_release.R
test_that("release artifacts agree on the beta version", {
  root <- ".."
  read <- function(path) paste(readLines(file.path(root, path), warn = FALSE), collapse = "\n")
  expect_match(read("README.md"), "0.9.0-beta.1", fixed = TRUE)
  expect_match(read("TODO.md"), "0.9.0-beta.1", fixed = TRUE)
  expect_true(file.exists(file.path(root, "renv.lock")))
  expect_match(read("run.bat"), "shiny::runApp('.')", fixed = TRUE)
})
```

- [ ] **Step 2: Run the release test and confirm missing artifacts**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_release.R')"
```

Expected: FAIL because `README.md` and `renv.lock` are absent and the version is undocumented.

- [ ] **Step 3: Write beta documentation and launcher**

Create `README.md` with this executable quick start and the 12-row matrix from Task 1:

```markdown
# LM Plot Explorer 0.9.0-beta.1

Interactive local exploration of linear, generalized linear, and Gaussian mixed models.

## Quick start

Requires R 4.6.x. From the project root:

```r
install.packages("renv")
renv::restore()
shiny::runApp(".")
```

Run tests with `testthat::test_dir("tests", reporter = "summary")`.

Expert mode evaluates R code and is restricted to trusted local use. This beta does not provide hosted-user isolation, arbitrary formulas, uploaded datasets, random slopes, or generalized mixed models.
```

Replace `run.bat` with:

```bat
@echo off
setlocal
set "RSCRIPT=C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe"
if not exist "%RSCRIPT%" (
  echo R 4.6.0 was not found at %RSCRIPT%.
  exit /b 1
)
"%RSCRIPT%" -e "if (!requireNamespace('renv', quietly=TRUE)) install.packages('renv', repos='https://cloud.r-project.org'); renv::restore(prompt=FALSE); shiny::runApp('.', launch.browser=TRUE)"
endlocal
```

Replace `TODO.md` with:

```markdown
# LM Plot Explorer 0.9.0-beta.1

- [x] Modular model registry and 12 model/link combinations
- [x] Deterministic standard and trusted-local expert simulation
- [x] Response-scale plots, diagnostics, data table, and enriched CSV
- [x] Reproducible runtime and automated beta verification
- [ ] Post-beta: uploaded datasets and formula builder
- [ ] Post-beta: random slopes and generalized mixed models
```

- [ ] **Step 4: Generate the lockfile from discovered dependencies**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "if (!requireNamespace('renv', quietly=TRUE)) install.packages('renv', repos='https://cloud.r-project.org'); renv::init(bare=TRUE); renv::snapshot(prompt=FALSE, type='all')"
```

Expected: `renv.lock` includes runtime and test packages used by source files.

- [ ] **Step 5: Update ignore rules without hiding release evidence**

Ignore `.Rproj.user/`, `.Rhistory`, `.RData`, `.Ruserdata`, `.env`, `.worktrees/`, `.superpowers/`, `renv/library/`, `renv/staging/`, test-result directories, and temporary screenshots. Do not ignore `renv.lock`, `tests/`, or committed browser baselines.

Use these exact additions in `.gitignore`:

```gitignore
renv/library/
renv/staging/
tests/testthat/_snaps/_new/
tests/shinytest2/_screenshots/
*.tmp.png
```

- [ ] **Step 6: Run release and full unit tests**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_release.R'); testthat::test_dir('tests', reporter='summary')"
```

Expected: release truth PASS and no new skip beyond the browser dependency if still absent.

- [ ] **Step 7: Commit reproducibility artifacts**

```powershell
git add README.md renv.lock run.bat .gitignore TODO.md tests/test_release.R
git commit -m "docs: package reproducible beta runtime"
```

---

### Task 7: Browser Verification and Final Acceptance Audit

**Files:**
- Modify: `tests/test_app.R`
- Create: `tests/test_acceptance.R`

**Interfaces:**
- Consumes: the complete beta application.
- Produces: executable browser smoke and requirement-by-requirement acceptance evidence.

- [ ] **Step 1: Replace skipped snapshots with a failing browser workflow**

```r
# tests/test_app.R
testthat::skip_if_not_installed("shinytest2")
app <- shinytest2::AppDriver$new("..", name = "beta-smoke", seed = 123, load_timeout = 1e5)
on.exit(app$stop(), add = TRUE)

app$set_inputs(model_type = "glm_binomial")
app$set_inputs(link_sel = "probit")
app$set_inputs(`simulation-n` = 80, `simulation-seed` = 12)
app$click("generate")
app$wait_for_idle()

testthat::expect_false(is.null(app$get_value(output = "main_plot")))
testthat::expect_false(is.null(app$get_value(output = "model_summary")))
testthat::expect_false(is.null(app$get_value(output = "data_table")))
testthat::expect_length(app$get_logs(), 0L)
```

- [ ] **Step 2: Install browser-test support and run the test red**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "install.packages('shinytest2', repos='https://cloud.r-project.org'); testthat::test_file('tests/test_app.R')"
```

Expected: the test executes rather than skips; any missing namespaced input or output fails visibly.

- [ ] **Step 3: Fix only browser-observed integration defects using a failing regression test for each defect**

For every failure, first add the smallest assertion to `tests/test_app.R` or `tests/test_server.R` that reproduces it, rerun to confirm the expected failure, then modify the owning module. Do not weaken log assertions to hide Shiny or JavaScript errors.

- [ ] **Step 4: Add the complete acceptance matrix audit**

```r
# tests/test_acceptance.R
source(file.path("..", "R", "config.R"))
source(file.path("..", "R", "mod_model.R"))
source(file.path("..", "R", "mod_simulation.R"))
source(file.path("..", "R", "mod_visualization.R"))

test_that("beta acceptance matrix is executable end to end", {
  combinations <- do.call(rbind, lapply(model_ids(), function(id) {
    data.frame(model_type = id, link = valid_links(id), stringsAsFactors = FALSE)
  }))
  expect_equal(nrow(combinations), 12L)
  for (row in seq_len(nrow(combinations))) {
    model_type <- combinations$model_type[[row]]
    link <- combinations$link[[row]]
    data <- simulate_data(model_type, link, n = 100L, seed = 100L + row)
    fit <- fit_model(data, model_type, link)
    plot <- build_main_plot(data, fit, model_type)
    export <- enrich_data(data, fit)
    expect_s3_class(plot, "plotly")
    expect_true(all(is.finite(export$.fitted)))
    expect_true(all(is.finite(export$.residual)))
  }
})
```

- [ ] **Step 5: Run all automated tests with zero skips**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "result <- testthat::test_dir('tests', reporter='summary'); if (any(vapply(result, function(x) length(x$results) && any(vapply(x$results, inherits, logical(1), 'expectation_skip')), logical(1)))) quit(status=1)"
```

Expected: exit 0, zero failures, zero errors, zero skips.

- [ ] **Step 6: Run an isolated HTTP smoke test**

Start `shiny::runApp('.', host='127.0.0.1', port=48761, launch.browser=FALSE)` in a hidden child process, poll `http://127.0.0.1:48761` until it returns 200, capture logs, and always terminate only that child process. Expected: HTTP 200 and no application error in stderr.

- [ ] **Step 7: Perform the requirement-by-requirement audit**

Check every acceptance criterion in `docs/superpowers/specs/2026-07-18-lmplot-beta-design.md` against current files and fresh command output. Confirm `git status --short` contains no temporary Graphify/browser/server files and no accidentally staged unrelated change.

- [ ] **Step 8: Commit final beta verification**

```powershell
git add tests/test_app.R tests/test_acceptance.R
git commit -m "test: verify LM Plot Explorer beta"
```
