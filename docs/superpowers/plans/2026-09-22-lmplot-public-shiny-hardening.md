# LM Plot Explorer 0.10.0-beta.1 Public Shiny Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Deliver the approved English-only public Shiny application with one
R engine, deterministic Model Brain, secure local-only Expert mode, reproducible
Docker deployment, CI, accessibility, and release metadata.

**Architecture:** Build a modular Shiny monolith around pure R scientific
services. Named function registries dispatch fitting and family diagnostics;
dependency injection exists at the analysis boundary; the CLI is a JSON
adapter; app.R only composes services and modules.

**Tech Stack:** R 4.6.0, Shiny, bslib, Plotly, DT, ggplot2, lme4, jsonlite,
testthat, shinytest2, renv, Docker Compose, GitHub Actions.

**Spec:** docs/superpowers/specs/2026-09-22-lmplot-public-shiny-hardening-design.md

## Global Constraints

- Preserve fit_model(df, model_type, link) as the stable dispatcher.
- Gaussian GLMM requires lme4::lmer; no nlme or lm fallback is permitted.
- Public execution never evaluates user R code. Expert mode requires
  LMPLOT_TRUSTED_LOCAL=1 in both UI and use-case validation.
- Use named function registries only for fit and diagnostic dispatch; use
  dependency injection at the analysis boundary and adapters only at external
  boundaries.
- The canonical Model Brain contract is model-brain/1.0 and is built once per
  successful analysis; observation navigation never refits.
- CLI schemas are lmplot-analysis-request/1.0,
  lmplot-analysis-result/1.0, and lmplot-error/1.0.
- CLI exit codes are 2 for request/security errors, 3 for
  analysis/dependency errors, and 4 for serialization errors.
- JSON contains null for unavailable or non-finite values and never NaN/Inf.
- The UI and user-facing documentation are English-only and use cautious
  statistical language.
- Every complex chart includes units, N, uncertainty status, a text summary,
  and an underlying table or download.
- Target WCAG 2.2 AA; use system/local fonts and no runtime web assets.
- Runtime code must not call install.packages().
- Docker base is exactly
  rocker/shiny:4.6.0@sha256:95a0d826be0bfc9bd41300385b35cf0ec074fc6b82cfaa92fddd7c6f6f2fd0dd.
- Release version is 0.10.0-beta.1 and the license is MIT for
  “lmplot contributors”.
- Follow strict TDD for production behavior: record the expected RED failure,
  then the GREEN result, before committing.

---

### Task 1: Model Registry and Fitting Strategies

**Files:**
- Create: R/model_registry.R
- Modify: R/mod_model.R
- Modify: app.R
- Modify: tests/test_model.R
- Create: tests/test_model_fitting.R

**Interfaces:**
- Consumes: existing MODEL_REGISTRY model IDs and validate_model_link behavior.
- Produces: MODEL_REGISTRY, FIT_STRATEGIES, fit_model(df, model_type, link),
  model_config(model_type), validate_model_link(model_type, link), and
  model_fit_warnings(fit).

- [ ] **Step 1: Add regression tests for dispatch and the forbidden fallback**

Add literal behavior tests equivalent to:

~~~r
test_that("every registry entry resolves a named fit strategy", {
  expect_setequal(
    unique(vapply(MODEL_REGISTRY, function(x) x$fit_strategy, character(1))),
    names(FIT_STRATEGIES)
  )
})

test_that("GLMM reports a dependency error when lme4 is unavailable", {
  expect_error(
    fit_glmm_strategy(example_glmm_frame(), "identity",
      namespace_available = function(pkg) FALSE),
    "requires the lme4 package"
  )
})

test_that("GLMM never returns an lm or lme fallback", {
  skip_if_not_installed("lme4")
  fit <- fit_model(example_glmm_frame(), "glmm", "identity")
  expect_s4_class(fit, "merMod")
})
~~~

- [ ] **Step 2: Run the focused tests and capture RED**

Run:

~~~text
Rscript -e "testthat::test_file('tests/test_model_fitting.R')"
~~~

Expected: failure because FIT_STRATEGIES/fit_glmm_strategy do not exist and the
current fallback can return lm or lme.

- [ ] **Step 3: Split registry and fitting responsibilities**

Move model metadata/validation into R/model_registry.R. Add named functions
fit_lm_strategy, fit_glm_strategy, and fit_glmm_strategy plus:

~~~r
FIT_STRATEGIES <- list(
  lm = fit_lm_strategy,
  glm = fit_glm_strategy,
  glmm = fit_glmm_strategy
)

fit_model <- function(df, model_type, link = NULL) {
  config <- model_config(model_type)
  resolved_link <- validate_model_link(model_type, link)
  FIT_STRATEGIES[[config$fit_strategy]](df, resolved_link)
}
~~~

Inject only the lme4 namespace check into fit_glmm_strategy for dependency
testing. Capture fit warnings without suppressing optimizer information.

- [ ] **Step 4: Source model_registry.R before mod_model.R everywhere**

Update app.R and the affected tests. Keep prediction/residual helpers in
mod_model.R. Remove all nlme and lm GLMM fallback branches.

- [ ] **Step 5: Verify GREEN and the complete baseline**

Run the focused file, then:

~~~text
Rscript -e "testthat::test_dir('tests', reporter='summary')"
~~~

Expected: all tests pass; only known environment/package-build warnings remain.

- [ ] **Step 6: Commit**

~~~text
git add R/model_registry.R R/mod_model.R app.R tests/test_model.R tests/test_model_fitting.R
git commit -m "refactor: enforce registered model fitting strategies"
~~~

### Task 2: Family Metrics, Diagnostics, Intervals, and Guided Interpretation

**Files:**
- Create: R/model_metrics.R
- Create: R/model_diagnostics.R
- Modify: R/mod_model.R
- Modify: R/mod_eli5.R
- Modify: app.R
- Modify: tests/test_model.R
- Modify: tests/test_eli5.R
- Create: tests/test_model_diagnostics.R

**Interfaces:**
- Consumes: Task 1 fitted lm/glm/merMod objects and model metadata.
- Produces: extract_model_metrics(fit, model_type, data),
  extract_coefficient_table(fit, model_type, link),
  predict_response_interval(fit, newdata, model_type, level = 0.95),
  DIAGNOSTIC_STRATEGIES, diagnose_model(fit, data, model_type), and
  guided_interpretation(result).

- [ ] **Step 1: Add failing scientific regression tests**

Cover literal contracts:

~~~r
test_that("AIC and BIC are neutral comparison values", {
  metrics <- extract_model_metrics(stats::lm(mpg ~ wt, mtcars), "lm_2d", mtcars)
  expect_named(metrics, c("family", "sample_size", "r_squared",
    "adjusted_r_squared", "aic", "bic"))
  expect_false(any(grepl("optimal|parsim", unlist(metrics), ignore.case = TRUE)))
})

test_that("GLM metrics expose deviance explained and Pearson dispersion", {
  fit <- stats::glm(am ~ wt, mtcars, family = stats::binomial())
  metrics <- extract_model_metrics(fit, "glm_binomial", mtcars)
  expect_true(is.numeric(metrics$deviance_explained))
  expect_true(is.numeric(metrics$pearson_dispersion))
})

test_that("logit interpretation discusses odds, not probability points", {
  text <- explain_coefficient(0.5, 0.01, link = "logit", term = "X")
  expect_match(text, "odds ratio")
  expect_false(grepl("chance of randomness|probability increases by 0.5", text))
})
~~~

Also add fixtures that mutate lme4 optinfo and create a singular fit; assert
the diagnostic reports optimizer/singularity warnings and never claims
successful convergence.

- [ ] **Step 2: Run focused tests and capture RED**

~~~text
Rscript -e "testthat::test_file('tests/test_model_diagnostics.R'); testthat::test_file('tests/test_eli5.R')"
~~~

Expected: missing functions plus failures on existing evaluative/casual copy.

- [ ] **Step 3: Implement neutral metrics and coefficient intervals**

Use R-squared/adjusted R-squared for lm, deviance explained and Pearson
dispersion for glm, and separately named squared correlations between response
and population/conditional predictions for GLMM. AIC/BIC carry numeric value
and comparison-only description. Coefficient tables include estimate,
standard_error, conf_low, conf_high, and interval_available.

- [ ] **Step 4: Implement response-scale intervals**

For lm use predict(..., interval = "confidence"). For glm compute link-scale
fit ± qnorm(0.975) * se.fit and apply family(fit)$linkinv. For GLMM return:

~~~r
list(
  available = FALSE,
  level = 0.95,
  reason = "Response-scale intervals are unavailable for this GLMM."
)
~~~

- [ ] **Step 5: Implement diagnostic strategy registry**

Create strategies lm, binomial, count_gamma, and glmm. Each returns stable
fields: strategy, status, summary, checks, warnings. GLMM reads optinfo
convergence codes/messages and lme4::isSingular. No strategy returns
“linear model adequate” or a global validity verdict.

- [ ] **Step 6: Replace ELI5/Ollama with deterministic Guided interpretation**

Delete try_ollama_llm_explanation. Rename UI/server functions and visible copy
to Guided interpretation. State p-values as conditional evidence under the
model. Use response-unit, exp(beta) multiplicative, and odds-ratio language for
identity, log, and logit links respectively.

- [ ] **Step 7: Verify focused and complete suites**

Run:

~~~text
Rscript -e "testthat::test_file('tests/test_model_diagnostics.R'); testthat::test_file('tests/test_model.R'); testthat::test_file('tests/test_eli5.R')"
Rscript -e "testthat::test_dir('tests', reporter='summary')"
~~~

- [ ] **Step 8: Commit**

~~~text
git add R/model_metrics.R R/model_diagnostics.R R/mod_model.R R/mod_eli5.R app.R tests
git commit -m "fix: make model assessment family specific"
~~~

### Task 3: Validated Analysis Boundary and Trusted-Local Expert Gate

**Files:**
- Modify: R/mod_pipeline.R
- Modify: R/mod_simulation.R
- Modify: app.R
- Modify: tests/test_pipeline.R
- Modify: tests/test_server.R

**Interfaces:**
- Consumes: Task 1/2 fit, metrics, diagnostics, prediction, simulation, examples.
- Produces:
  new_analysis_request(payload, trusted_local = FALSE) -> analysis_request;
  create_analysis_services(...) -> analysis_services;
  run_analysis_usecase(request, services, root = ".") -> analysis_result.
- analysis_result contains data, display, example, fit, model_type, link, code,
  labels, metrics, coefficients, diagnostics, prediction_grid, warnings.

- [ ] **Step 1: Add failing request validation and security tests**

Use the exact request schema from the design. Assert unknown top-level and
nested fields fail, real requests reject simulation/expert fields, simulation
requests reject example_id, unsupported/missing schema versions fail, and:

~~~r
test_that("Expert mode is denied by default and works only when trusted", {
  payload <- valid_simulation_payload()
  payload$expert <- list(enabled = TRUE, code = "data.frame(X=1:20, Z=1:20)")
  expect_error(new_analysis_request(payload, FALSE), "trusted local")
  request <- new_analysis_request(payload, TRUE)
  expect_s3_class(request, "analysis_request")
})
~~~

Add a direct use-case regression for the old broken Expert argument order.

- [ ] **Step 2: Run tests and capture RED**

~~~text
Rscript -e "testthat::test_file('tests/test_pipeline.R')"
~~~

Expected: new constructors absent and direct Expert execution fails or bypasses
the requested security contract.

- [ ] **Step 3: Implement strict request construction**

Allow exactly schema_version, data_source, model_type, link, grid_length_out,
example_id, simulation, and expert. Validate nested simulation and expert key
sets, scalar types, model/link compatibility, and source exclusivity. Store
trusted_local as a non-JSON internal field on the analysis_request object.

- [ ] **Step 4: Implement the analysis service factory**

The default factory injects load_example, simulate, evaluate_expert, fit,
metrics, coefficients, diagnostics, prediction_grid, and build_model_brain
functions. Validate that every dependency is callable and return class
analysis_services.

- [ ] **Step 5: Refactor the use case**

Accept only request, services, and root. Recheck trusted_local before calling
evaluate_expert. Correct the Expert call to
evaluate_expert_simulation(code, parameters, model_type, link). Collect
recoverable warnings. Do not read Shiny input or environment variables inside
the use case.

- [ ] **Step 6: Gate the temporary UI entry point**

Compute trusted_local as identical(Sys.getenv("LMPLOT_TRUSTED_LOCAL"), "1") in
the composition root and pass it to request construction. Expert controls are
not created when false.

- [ ] **Step 7: Verify focused and complete suites**

~~~text
Rscript -e "testthat::test_file('tests/test_pipeline.R'); testthat::test_file('tests/test_server.R')"
Rscript -e "testthat::test_dir('tests', reporter='summary')"
~~~

- [ ] **Step 8: Commit**

~~~text
git add R/mod_pipeline.R R/mod_simulation.R app.R tests/test_pipeline.R tests/test_server.R
git commit -m "feat: validate analysis requests and gate expert mode"
~~~

### Task 4: Stable JSON CLI Adapter

**Files:**
- Modify: scripts/run_analysis.R
- Create: R/json_contract.R
- Create: tests/test_cli_contract.R
- Modify: tests/test_release.R

**Interfaces:**
- Consumes: Task 3 request/services/use-case boundary.
- Produces: analysis_result_to_contract(result),
  sanitize_json_values(value), error_contract(code, message), and the stable
  two-path CLI invocation.

- [ ] **Step 1: Add subprocess contract tests**

Create temporary request/output files and invoke the repository Rscript.
Assert a valid request exits 0 with lmplot-analysis-result/1.0. Table-drive
invalid JSON, unknown fields, bad schema, incompatible source fields, and
public Expert requests to exit 2 with lmplot-error/1.0. Inject an unavailable
dependency/analysis failure to exit 3. Use an unwritable/invalid output target
fixture for exit 4 where supported.

- [ ] **Step 2: Add non-finite serialization RED test**

~~~r
test_that("JSON sanitizer replaces every non-finite number with null", {
  value <- sanitize_json_values(list(a = NaN, b = Inf, c = -Inf, d = 1.5))
  json <- jsonlite::toJSON(value, auto_unbox = TRUE, null = "null")
  expect_false(grepl("NaN|Inf", json))
  expect_match(json, '"a":null')
})
~~~

- [ ] **Step 3: Run tests and capture RED**

~~~text
Rscript -e "testthat::test_file('tests/test_cli_contract.R')"
~~~

- [ ] **Step 4: Implement JSON contract helpers**

Recursively sanitize atomic vectors, matrices/data frames, and nested lists.
Map the analysis result to the documented result keys, including validated
Model Brain. Error messages are safe stable English strings; full exceptions
go to stderr only.

- [ ] **Step 5: Rewrite the adapter**

Remove user-library mutation and every install.packages call. Parse exactly two
arguments, classify request/security, analysis/dependency, and serialization
conditions, write the contract atomically through a sibling temporary file,
then quit with 0/2/3/4.

- [ ] **Step 6: Verify focused and complete suites**

~~~text
Rscript -e "testthat::test_file('tests/test_cli_contract.R'); testthat::test_file('tests/test_release.R')"
Rscript -e "testthat::test_dir('tests', reporter='summary')"
~~~

- [ ] **Step 7: Commit**

~~~text
git add scripts/run_analysis.R R/json_contract.R tests/test_cli_contract.R tests/test_release.R
git commit -m "feat: stabilize versioned analysis CLI contracts"
~~~

### Task 5: Complete and Validate Model Brain

**Files:**
- Modify: R/mod_model_brain.R
- Create: tests/test_model_brain_contract.R
- Modify: tests/test_model_brain.R
- Modify: tests/helper-model-brain.R
- Modify: R/mod_pipeline.R

**Interfaces:**
- Consumes: fitted model, source data, coefficient table, intervals, warnings.
- Produces: build_model_brain(fit, data, model_type, link, labels, warnings,
  prediction_mode), validate_model_brain(brain), select_model_brain_observation(
  brain, index), and model-brain/1.0.

- [ ] **Step 1: Add failing schema and numerical decomposition tests**

For every supported model/link fixture assert intercept + term contributions +
random intercept equals eta within 1e-8 and inverse link equals prediction
within 1e-8. Mutate schema version, observation index, topology order, eta,
prediction, and inject non-finite values; validation must reject each mutation.

- [ ] **Step 2: Add interval, mode, and no-refit tests**

Assert LM/GLM coefficient intervals and response intervals are present. Assert
GLMM explicitly marks response intervals unavailable. For GLMM test both
population and conditional modes. Inject a fit function counter and prove
select_model_brain_observation changes the selection without incrementing it.

- [ ] **Step 3: Add the performance budget test**

Build a deterministic 5,000-row LM contract, measure elapsed time and
object.size, and assert less than 2 seconds and 25 * 1024^2 bytes. Skip only on
CRAN-like constrained environments, not in repository CI.

- [ ] **Step 4: Run tests and capture RED**

~~~text
Rscript -e "testthat::test_file('tests/test_model_brain_contract.R')"
~~~

- [ ] **Step 5: Implement the complete contract**

Remove fallback-specific branches. Add coefficient intervals, interval status,
warnings, prediction mode, contribution topology, link samples, global
summaries, units, and N. Keep all statistical values produced in R.

- [ ] **Step 6: Implement strict validation and selection**

Validate exact required names and reject unknown names in schema-bearing
objects. Verify finite numerics before JSON sanitization, decomposition,
prediction, index range, and GLMM mode consistency. Selection returns only
precomputed observation data.

- [ ] **Step 7: Build and validate once in the use case**

Task 3 services call build_model_brain then validate_model_brain once after a
successful fit. Store the validated contract on analysis_result$model_brain.

- [ ] **Step 8: Verify focused and complete suites**

~~~text
Rscript -e "testthat::test_file('tests/test_model_brain.R'); testthat::test_file('tests/test_model_brain_contract.R')"
Rscript -e "testthat::test_dir('tests', reporter='summary')"
~~~

- [ ] **Step 9: Commit**

~~~text
git add R/mod_model_brain.R R/mod_pipeline.R tests/test_model_brain.R tests/test_model_brain_contract.R tests/helper-model-brain.R
git commit -m "feat: complete validated model brain contract"
~~~

### Task 6: Modular English Shiny Workflows and Recoverable Coordinator

**Files:**
- Create: R/mod_configuration.R
- Create: R/mod_overview.R
- Create: R/mod_diagnostics.R
- Create: R/mod_data_provenance.R
- Create: R/app_coordinator.R
- Modify: R/mod_eli5.R
- Modify: app.R
- Modify: tests/test_app_structure.R
- Modify: tests/test_server.R
- Create: tests/test_shiny_modules.R

**Interfaces:**
- Consumes: Task 3 analysis request/services/use case and Task 5 model_brain.
- Produces: configuration_ui/server, overview_ui/server,
  diagnostics_ui/server, data_provenance_ui/server, create_app_coordinator(),
  and a thin app.R composition root.

- [ ] **Step 1: Add failing module-isolation tests**

Use shiny::testServer on each server module. Assert configuration emits a
validated payload, views accept an analysis_result reactive, and no module
accesses another module's raw input IDs. Test Expert controls absent when
trusted_local is false and present/functional when true.

- [ ] **Step 2: Add coordinator recovery and sanitization tests**

Drive one successful request followed by a service error. Assert result remains
identical to the prior success, stale is true, and public_error equals
“Analysis failed. Review the settings and try again.” Capture stderr and assert
the original exception is logged there but not returned to the UI.

- [ ] **Step 3: Run tests and capture RED**

~~~text
Rscript -e "testthat::test_file('tests/test_shiny_modules.R'); testthat::test_file('tests/test_server.R')"
~~~

- [ ] **Step 4: Implement the coordinator**

Return reactive accessors result, warnings, public_error, stale, running, and
an analyze(payload) method. Construct/execute requests inside tryCatch, retain
last valid result, log conditionMessage(error) plus call to stderr, and expose
only the stable public message.

- [ ] **Step 5: Implement four workflow views**

Configuration owns source/model/link/simulation controls. Overview owns
metrics, main prediction chart, coefficient table, and Guided interpretation.
Diagnostics owns family-specific checks and alternatives. Data & provenance
owns data table/download, source/license/hash, preparation, and limitations.
All visible copy is English.

- [ ] **Step 6: Reduce app.R to composition**

Source modules/core in dependency order, construct trusted_local and services,
create semantic page/navigation, instantiate modules, and wire coordinator
reactives. Remove business calculations and rendering branches from app.R.

- [ ] **Step 7: Verify modules, smoke test, and suite**

~~~text
Rscript -e "testthat::test_file('tests/test_shiny_modules.R'); testthat::test_file('tests/test_app.R')"
Rscript -e "testthat::test_dir('tests', reporter='summary')"
~~~

- [ ] **Step 8: Commit**

~~~text
git add R/mod_configuration.R R/mod_overview.R R/mod_diagnostics.R R/mod_data_provenance.R R/app_coordinator.R R/mod_eli5.R app.R tests
git commit -m "refactor: compose modular public Shiny workflows"
~~~

### Task 7: Accessible Model Brain and Scientific Chart Alternatives

**Files:**
- Create: R/model_brain_plots.R
- Create: R/mod_model_brain_ui.R
- Modify: R/mod_visualization.R
- Modify: www/style.css
- Modify: app.R
- Modify: tests/test_visualization.R
- Modify: tests/test_app.R
- Create: tests/test_accessibility.R
- Create: tests/test_model_brain_ui.R

**Interfaces:**
- Consumes: precomputed model-brain/1.0 from Task 5 and coordinator result.
- Produces: exact_equation_view, contribution_waterfall,
  link_transformation_plot, coefficient_overview_plot,
  random_effect_plot, chart_accessibility_bundle, and model_brain_ui/server.

- [ ] **Step 1: Add failing plot-data and no-refit interaction tests**

Assert each plot helper consumes contract values without calling predict or
fit_model. Through testServer select a Plotly point and previous/next buttons;
assert index wraps/clamps as documented and fit counter stays unchanged.

- [ ] **Step 2: Add failing accessibility structure tests**

Render the UI and assert one skip link targets main content, header/nav/main
landmarks exist, heading order begins at h1, controls have explicit labels,
errors use role=alert, chart containers reference summaries, every chart has a
table/download alternative, and focus styling is at least 2px. Assert CSS has
no fonts.googleapis.com/import URL.

- [ ] **Step 3: Run tests and capture RED**

~~~text
Rscript -e "testthat::test_file('tests/test_model_brain_ui.R'); testthat::test_file('tests/test_accessibility.R')"
~~~

- [ ] **Step 4: Implement pure render-data helpers**

Return Plotly objects plus a shared bundle:

~~~r
list(
  plot = plot,
  summary = sprintf("%s; N = %d; %s", title, n, uncertainty_text),
  table = underlying_data,
  units = units,
  n = n,
  uncertainty = uncertainty_text
)
~~~

Encode sign/status with shape or text as well as color. Use accessible palette
tokens and preserve numeric values in the alternative table.

- [ ] **Step 5: Implement the Model Brain module**

Render exact equation, contribution waterfall, link transformation,
coefficient overview, and GLMM random effects. Maintain selected index in
reactiveVal; update only from contract rows. Add Previous/Next buttons,
aria-live observation summary, Plotly point selection, tables, and downloads.

- [ ] **Step 6: Apply WCAG structure and local typography**

Add skip navigation, semantic headings/landmarks, visible focus, non-color
status text/icons, explicit errors, AA contrast tokens, and system font stack.
Ensure keyboard-only configuration → analysis → tabs → observation navigation
works in shinytest2.

- [ ] **Step 7: Verify focused, browser, and complete suites**

~~~text
Rscript -e "testthat::test_file('tests/test_model_brain_ui.R'); testthat::test_file('tests/test_accessibility.R'); testthat::test_file('tests/test_app.R')"
Rscript -e "testthat::test_dir('tests', reporter='summary')"
~~~

- [ ] **Step 8: Commit**

~~~text
git add R/model_brain_plots.R R/mod_model_brain_ui.R R/mod_visualization.R www/style.css app.R tests
git commit -m "feat: add accessible model brain exploration"
~~~

### Task 8: Shiny-Only Reproducible Deployment

**Files:**
- Delete: streamlit_app.py
- Delete: .streamlit/config.toml
- Delete: requirements.txt
- Delete: packages.txt
- Modify: Dockerfile
- Modify: docker-compose.yml
- Modify: .dockerignore
- Modify: .renvignore
- Modify: scripts/run_analysis.R
- Modify: tests/test_release.R
- Create: tests/test_deployment.R

**Interfaces:**
- Consumes: Shiny app and renv.lock.
- Produces: Linux/AMD64 non-root image serving Shiny on 3838 and Compose
  service lmplot with root-page healthcheck.

- [ ] **Step 1: Add failing repository/deployment tests**

Assert deleted paths do not exist; scan runtime R files for install.packages;
assert Dockerfile starts with the exact digest, contains USER shiny,
EXPOSE 3838, renv restore, and root URL healthcheck; assert Compose has no
obsolete version key, maps 3838, uses read_only, tmpfs, resource limits, and
an internal network. These tests validate structured config where possible,
not merely comments.

- [ ] **Step 2: Run tests and capture RED**

~~~text
Rscript -e "testthat::test_file('tests/test_deployment.R'); testthat::test_file('tests/test_release.R')"
~~~

- [ ] **Step 3: Delete the Streamlit/Python runtime**

Remove exactly the four listed runtime paths. Remove Streamlit/Python ignores,
commands, ports, and documentation hooks from deployment files. Preserve no
compatibility shim.

- [ ] **Step 4: Build the Shiny image definition**

Use the pinned base, install system libraries as root, install renv, restore
from renv.lock during build, copy the app into /srv/shiny-server/lmplot, fix
ownership, switch to USER shiny, expose 3838, and healthcheck
http://127.0.0.1:3838/.

- [ ] **Step 5: Harden Compose**

Define service lmplot, port 3838:3838, read_only: true, tmpfs entries for /tmp
and Shiny runtime writes, no LMPLOT_TRUSTED_LOCAL, CPU/memory limits, and an
internal network. Do not include TLS/reverse proxy configuration.

- [ ] **Step 6: Verify config, build, and egress-blocked health**

Run:

~~~text
docker compose config --quiet
docker build -t lmplot:0.10.0-beta.1 .
docker run --rm --network none --name lmplot-health lmplot:0.10.0-beta.1
~~~

Use the image HEALTHCHECK status or an internal curl executed in the container
namespace; no external egress may be required after startup.

- [ ] **Step 7: Run the complete R suite**

~~~text
Rscript -e "testthat::test_dir('tests', reporter='summary')"
~~~

- [ ] **Step 8: Commit**

~~~text
git add -A
git commit -m "build: ship reproducible Shiny-only container"
~~~

### Task 9: CI, Conventions, Documentation, Licensing, and Release Metadata

**Files:**
- Create: .github/workflows/ci.yml
- Create: LICENSE
- Create: CHANGELOG.md
- Modify: README.md
- Modify: AGENTS.md
- Modify: R/config.R
- Modify: tests/test_config.R
- Modify: tests/test_release.R
- Modify: renv.lock when an explicit renv snapshot proves required

**Interfaces:**
- Consumes: all prior tasks and their acceptance commands.
- Produces: release metadata 0.10.0-beta.1, public documentation, MIT license,
  evidence-specific architecture rules, and Windows/Linux/Docker CI.

- [ ] **Step 1: Add failing release metadata tests**

Assert APP_VERSION is 0.10.0-beta.1, LICENSE contains MIT and
lmplot contributors, README documents Shiny port 3838/security/CLI schemas and
contains no Streamlit runtime instructions, and workflow YAML has Windows and
Linux R 4.6.0 jobs plus Docker build/health jobs.

- [ ] **Step 2: Run tests and capture RED**

~~~text
Rscript -e "testthat::test_file('tests/test_config.R'); testthat::test_file('tests/test_release.R')"
~~~

- [ ] **Step 3: Update project conventions**

Replace the blanket pattern block in AGENTS.md with these enforceable rules:
Strategy only for model/diagnostic dispatch; DI at the analysis boundary;
adapters only for real external boundaries; Shiny modules per workflow; pure
calculation outside reactive handlers; KISS/YAGNI. Remove automatic judgments
based solely on file length or the presence of a third-party library.

- [ ] **Step 4: Add release files and English documentation**

Add the standard MIT license with year 2026 and “lmplot contributors”.
CHANGELOG describes the beta, Shiny-only breaking change, schemas, security,
science, accessibility, and deployment. README covers local renv restore/run,
Docker/Compose, LMPLOT_TRUSTED_LOCAL risk, CLI request/result/error examples,
data provenance, supported models, tests, and public deployment boundaries.

- [ ] **Step 5: Add GitHub Actions**

Use r-lib/actions with explicit R 4.6.0 on windows-latest and ubuntu-latest.
Restore renv cache, run the complete testthat suite including shinytest2 and
CLI contracts, then build the Docker image and run its healthcheck on Linux.
Do not enable trusted-local Expert mode in CI Docker.

- [ ] **Step 6: Verify release candidate**

Run exactly:

~~~text
Rscript -e "testthat::test_dir('tests', reporter='summary')"
docker compose config --quiet
docker build -t lmplot:0.10.0-beta.1 .
git diff --check
~~~

Then run the egress-blocked container healthcheck, inspect all user-facing
scientific copy for the prohibited claims, and complete the accessibility
checklist in CHANGELOG release notes.

- [ ] **Step 7: Commit**

~~~text
git add .github/workflows/ci.yml LICENSE CHANGELOG.md README.md AGENTS.md R/config.R tests renv.lock
git commit -m "chore: prepare 0.10.0-beta.1 release"
~~~
