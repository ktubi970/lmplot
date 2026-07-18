# LM Plot Explorer 0.9.0-beta.1 — Design Specification

**Status:** Approved  
**Date:** 2026-07-18  
**Target:** `0.9.0-beta.1`

## 1. Objective

Deliver a coherent, reproducible beta of LM Plot Explorer that preserves the
five model modes already present, adds the planned Gamma and multi-link GLM
support, restores the promised simulation and download workflows, and can be
verified automatically from model helpers through a real Shiny session.

The beta is an exploratory and educational application. It is not a production
inference service and does not accept untrusted remote users.

## 2. Beta Scope

The beta supports these model modes and links:

| Model ID | UI label | Fit | Predictors | Valid links |
|---|---|---|---|---|
| `lm_2d` | Simple LM (2D) | `lm` | `X` | `identity` |
| `lm_3d` | Multiple LM (3D) | `lm` | `X + Y` | `identity` |
| `glm_binomial` | Binomial GLM | `glm(binomial)` | `X + Y` | `logit`, `probit`, `cloglog` |
| `glm_poisson` | Poisson GLM | `glm(poisson)` | `X + Y` | `log`, `identity`, `sqrt` |
| `glm_gamma` | Gamma GLM | `glm(Gamma)` | `X + Y` | `inverse`, `log`, `identity` |
| `glmm` | Gaussian GLMM | `lmer` | `X + Y + (1 | Group)` | `identity` |

This is a 12-combination acceptance matrix: two LM combinations, nine GLM
family/link combinations, and one GLMM combination.

Out of scope for this beta:

- authentication, hosted multi-user isolation, and remote code execution;
- arbitrary formulas or user-uploaded datasets;
- additional distributions, random slopes, or generalized mixed models;
- localization beyond the current English UI copy.

## 3. Architecture

`app.R` is a thin composition root. Domain logic is split into focused files:

- `R/config.R` owns `APP_VERSION` and package-independent application constants.
- `R/mod_model.R` owns the model registry, link validation, fitting, response-
  scale predictions, response residuals, and model metadata.
- `R/mod_simulation.R` owns simulation controls, standard data generation,
  expert-mode evaluation, and validation of the returned data frame.
- `R/mod_visualization.R` owns Plotly construction, prediction grids, diagnostic
  plot construction, and enriched download data.
- `app.R` composes the UI, connects reactives, renders outputs, and translates
  domain errors into Shiny validation messages or notifications.

No module may depend on the global `input` object. Pure helper functions accept
ordinary R values so they can be tested without a Shiny session.

## 4. Model Registry and Interfaces

`MODEL_REGISTRY` is the single source of truth. Each entry contains `id`,
`label`, `family`, `links`, `default_link`, `dimensions`, and `requires_group`.

Required public interfaces:

```r
model_ids()
model_config(model_type)
valid_links(model_type)
validate_model_link(model_type, link)
fit_model(df, model_type, link = NULL)
fitted_response(fit)
response_residuals(fit)
```

Unknown model IDs and invalid links fail with explicit errors. `fit_model()`
validates required columns and response-domain constraints before fitting.
Predictions and residuals are always returned on the response scale.

## 5. Simulation

### Standard mode

The sidebar exposes model-aware controls for sample size, seed, coefficients,
and the distribution-specific noise parameter. Generated data use canonical
columns `X`, `Y`, `Z`, and optional `Group`.

- `lm_2d`: continuous `Z`, no required `Y` in the formula.
- `lm_3d`: continuous `Z` with two predictors.
- `glm_binomial`: binary `Z` generated from the selected inverse link.
- `glm_poisson`: non-negative integer `Z`; the simulated mean is finite and
  strictly positive for every supported link.
- `glm_gamma`: finite, strictly positive `Z`; shape is configurable.
- `glmm`: continuous `Z` with five or more groups and a random intercept.

Simulation is deterministic for a given model, link, seed, and control set.

### Expert mode

Expert mode uses `shinyAce` and evaluates the supplied R expression in an
isolated environment populated only with documented simulation parameters.
The result must be a data frame with the columns required by the selected model
and must pass the same domain validation as standard simulation.

Because expert mode executes R code, the README explicitly limits it to trusted
local use. Hosted untrusted execution remains out of scope.

## 6. User Interface and Data Flow

The UI remains a responsive `bslib::page_sidebar()` application and displays
`0.9.0-beta.1` visibly in the title or header.

The sidebar contains:

1. model selector;
2. dynamic link selector, hidden for fixed-link LM and GLMM modes;
3. standard/expert simulation mode;
4. model-aware simulation controls;
5. Generate & Fit action;
6. regression surface toggle where a surface is meaningful;
7. enriched CSV download.

The workspace contains:

- the primary interactive 2D curve or 3D surface;
- model summary;
- reproducible simulation code;
- diagnostics;
- paginated data table.

Data flow:

```text
model + link + controls
        -> validated simulation
        -> validated model fit
        -> response predictions/residuals
        -> plot + summary + diagnostics + table + CSV
```

Changing model or link updates available controls but does not refit until the
Generate & Fit action is triggered. This prevents half-updated reactive states.

## 7. Visualization and Diagnostics

- `lm_2d` renders points and a fitted line with residual-aware tooltips.
- two-predictor LM, GLM, and GLMM modes render a 3D point cloud and fitted
  response surface; GLMM uses fixed effects for the population surface and
  colors observations by group.
- GLM surfaces are computed with `predict(..., type = "response")`, never by
  duplicating link equations in the plotting layer.
- LM and GLM diagnostics use `ggfortify::autoplot()` when supported.
- GLMM diagnostics use explicit residual-versus-fitted and normal Q-Q panels.

The enriched table and CSV contain original columns plus `.fitted` and
`.residual`.

## 8. Error Handling

Domain helpers fail fast with specific messages for unknown models, invalid
links, missing columns, non-finite values, and invalid response domains.

The Shiny server catches simulation and fitting failures, displays one concise
notification, and leaves the last successful result visible. Outputs use
`validate(need(...))` rather than emitting stack traces into the interface.

Warnings caused by deliberately non-canonical GLM links are captured and shown
as non-fatal notifications when the fit remains usable.

## 9. Reproducibility and Launching

- `renv.lock` records the beta runtime dependencies.
- `README.md` documents R 4.6.x, restore, test, and launch commands.
- `run.bat` uses the discovered R installation, restores missing dependencies,
  and launches the project directory rather than treating `app.R` as a folder.
- `.gitignore` excludes Shiny, renv, test, screenshot, and local-state artifacts
  without hiding source, snapshots, or documentation required by the beta.

Required runtime packages include `shiny`, `plotly`, `bslib`, `DT`, `ggplot2`,
`ggfortify`, `lme4`, `shinyWidgets`, and `shinyAce`. Test dependencies include
`testthat` and `shinytest2`.

## 10. Testing Strategy

Development follows red-green-refactor. New behavior is introduced only after
a focused test fails for the expected reason.

Automated layers:

1. **Registry tests:** exact model IDs, valid links, defaults, and invalid-link
   rejection.
2. **Simulation tests:** deterministic output, schemas, domains, group counts,
   and every one of the 12 accepted model/link combinations.
3. **Model tests:** correct fit class and finite response predictions/residuals
   for all 12 combinations.
4. **Visualization tests:** 2D/3D selection, finite prediction grids, enriched
   data columns, and no duplicated inverse-link formulas.
5. **Server tests:** `shiny::testServer()` exercises all model modes and verifies
   plot, summary, diagnostics, table, and download reactives.
6. **Browser smoke test:** `shinytest2` launches the real app, switches model and
   link, regenerates data, toggles the surface, and confirms no JavaScript or
   Shiny error is exposed.
7. **HTTP smoke test:** a clean process serves the app and returns status 200.

## 11. Beta Acceptance Criteria

The beta is complete only when all of the following are evidenced:

- the 12 model/link combinations generate, fit, predict, and produce residuals;
- the six model modes render their required outputs in a Shiny server test;
- the browser smoke workflow passes with `shinytest2` installed;
- the app starts from the documented clean command and responds over HTTP;
- the enriched CSV contains `.fitted` and `.residual`;
- the visible version is exactly `0.9.0-beta.1`;
- `README.md`, `renv.lock`, `run.bat`, and `TODO.md` agree with the delivered
  behavior;
- no beta source or test is left untracked or staged accidentally;
- the final Git diff contains no temporary Graphify, browser, or server files.

