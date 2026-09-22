# LM Plot Explorer 0.10.0-beta.1 — Public Shiny Hardening Design

Date: 2026-09-22  
Status: approved for implementation  
Supersedes: the Streamlit public MVP and conflicting portions of the earlier
Model Brain design

## 1. Outcome

LM Plot Explorer becomes a public, anonymous, English-only educational Shiny
application backed by one authoritative R scientific engine. The release must
be scientifically cautious, deterministic, accessible to WCAG 2.2 AA, and
reproducible in a Linux/AMD64 container.

The current dirty worktree is preserved first as the reviewed baseline commit
`chore: snapshot current model brain worktree`. That snapshot is historical,
not a deployment approval: it intentionally records the insecure Streamlit
configuration and root container that this design removes.

## 2. Scope and non-goals

In scope:

- the existing 15 model/link combinations and bundled real-data examples;
- simulated or bundled real data only;
- LM, supported GLMs, and Gaussian random-intercept GLMM;
- deterministic Guided interpretation and Model Brain output;
- Shiny, a JSON CLI adapter, Docker/Compose, and GitHub Actions;
- keyboard and screen-reader access to the core workflow.

Out of scope:

- authentication, multi-tenancy, uploaded data, arbitrary formulas, random
  slopes, generalized mixed models, or hosted code execution;
- TLS and reverse-proxy termination inside this repository;
- Streamlit compatibility or a Python runtime;
- model selection claims based on a single AIC or BIC value.

## 3. Architecture

The application is a modular Shiny monolith. Pure R functions own scientific
calculation. Shiny modules own workflow presentation. `app.R` is a composition
root that loads modules, constructs services, and wires the coordinator.

The R core is split by responsibility:

- `R/model_registry.R`: model metadata and named fitting strategies;
- `R/model_metrics.R`: family-specific neutral metrics and coefficient tables;
- `R/model_diagnostics.R`: named diagnostic strategies and GLMM fit warnings;
- `R/mod_simulation.R`: deterministic simulation and trusted-local expert code;
- `R/mod_model_brain.R`: canonical `model-brain/1.0` construction/validation;
- `R/model_brain_plots.R`: Plotly/table render data without refitting;
- `R/mod_pipeline.R`: request validation, service factory, and use case;
- `R/mod_visualization.R`: shared plot facades for existing scientific views.

Named function registries are required only where behavior genuinely varies:
model fitting and family-specific diagnostics. No class hierarchy is added.
Dependencies enter through `create_analysis_services()`. Adapters are used only
at real external boundaries: the JSON CLI and Plotly/Shiny rendering.

## 4. Stable scientific interfaces

The stable model dispatcher remains:

```r
fit_model(df, model_type, link)
```

It validates the model/link through `MODEL_REGISTRY`, selects a named fitting
strategy, and returns the fitted object with captured warnings. Gaussian GLMM
uses `lme4::lmer` only. Missing `lme4` is a dependency error; optimizer failure
or singularity is a warning/status, never a silent `nlme` or `lm` replacement.

The analysis boundary is:

```r
new_analysis_request(payload, trusted_local = FALSE) -> analysis_request
create_analysis_services(...) -> analysis_services
run_analysis_usecase(request, services, root = ".") -> analysis_result
```

`new_analysis_request()` rejects unknown fields, unsupported schemas,
incompatible source parameters, and Expert requests unless
`trusted_local = TRUE`. `run_analysis_usecase()` checks the trusted-local rule
again so UI manipulation cannot bypass it.

## 5. Request contract

The canonical JSON request is:

```json
{
  "schema_version": "lmplot-analysis-request/1.0",
  "data_source": "simulation",
  "model_type": "lm_2d",
  "link": "identity",
  "grid_length_out": 30,
  "simulation": {
    "n": 200,
    "seed": 123,
    "beta0": 2,
    "beta1": 0.5,
    "beta2": -0.25,
    "sigma": 1,
    "shape": 2,
    "group_sd": 1,
    "groups": 5,
    "pattern": "linear"
  },
  "expert": {"enabled": false, "code": null}
}
```

For `data_source = "real"`, `example_id` is allowed and `simulation`/`expert`
are rejected. For `data_source = "simulation"`, `example_id` is rejected.
Unknown top-level and nested fields are rejected. Null `link` selects the
registry default. The CLI never treats a missing schema version as legacy.

## 6. Result and error contracts

Successful CLI output has `schema_version = "lmplot-analysis-result/1.0"`
and contains model/source metadata, labels, data, fitted values, response
residuals, neutral metrics, coefficient estimates and intervals, diagnostics,
warnings, prediction grid, and a validated `model_brain` object.

Failures have this shape:

```json
{
  "schema_version": "lmplot-error/1.0",
  "error": {"code": "invalid_request", "message": "Safe public message"}
}
```

The adapter returns exit 2 for invalid/security requests, exit 3 for
analysis/dependency failure, and exit 4 for serialization failure. It writes
one valid JSON document even on error when the output path is usable. All
non-finite numbers are recursively converted to JSON null; `NaN` and `Inf`
must never appear in serialized output.

The invocation remains:

```text
Rscript scripts/run_analysis.R request.json output.json
```

## 7. Scientific semantics

Metrics use descriptive names and no evaluative badge:

- LM: R-squared and adjusted R-squared;
- GLM: deviance explained and Pearson dispersion;
- GLMM: explicitly named fixed-effects correlation-squared and conditional
  correlation-squared;
- all supported fits: AIC and BIC as neutral comparison values only.

Diagnostics are selected by named strategy for LM, binomial GLM, count/Gamma
GLM, and GLMM. Copy describes evidence and limitations; it never declares a
model globally adequate. GLMM diagnostics report optimizer messages,
non-zero convergence codes, and `lme4::isSingular()` explicitly.

Coefficient explanations state that a p-value is conditional evidence under
the fitted model, not the probability that an effect is random or true.
Identity-link effects use response units. Log-link effects use multiplicative
`exp(beta)` language. Logit effects use odds-ratio language and do not equate
odds with probability.

Response-scale 95% confidence intervals are returned for LM and supported GLM
predictions. When a reliable interval is not implemented, the result includes
`available = false` and a human-readable reason rather than a fabricated band.

## 8. Model Brain

`model-brain/1.0` is the only explainability contract. It is built and
validated once for each successful analysis. Observation selection reads the
precomputed contract and must not call `fit_model()` or re-run the use case.

The contract includes:

- schema/model/link metadata, units, N, warnings, and prediction mode;
- coefficients with estimate, standard error, and 95% interval where valid;
- observation rows with intercept, term contributions, random intercept when
  applicable, eta, inverse-link prediction, response, residual, and interval;
- a contribution topology describing exact equation order;
- link-curve samples and global coefficient summaries;
- population and conditional modes for GLMM, with unavailable intervals stated.

JSON validation rejects inconsistent decomposition, invalid indices, unknown
keys, non-finite values before sanitization, and schema mismatches. A 5,000-row
contract must build in under 2 seconds and measure under 40 MiB with
`utils::object.size()` in the release test environment. The initial 25 MiB
target was infeasible for the required nested observation records: the
complete 5,000-row fixture measures 33,598,128 bytes, while those records
alone have a measured lower bound of 33,360,048 bytes. The full contract,
including every observation and interval, remains required.

## 9. Shiny product and error model

The English UI has four primary views: **Overview**, **Diagnostics**,
**Model Brain**, and **Data & provenance**. Configuration is a reusable module,
not a fifth result view. A coordinator owns the current request, last valid
analysis result, warnings, and a recoverable public error.

If a later analysis fails, the last successful result remains visible with a
clear stale-result notice. Unexpected errors are logged with full details to
stderr and shown to users as a stable sanitized message without paths, stack
traces, commands, or environment details.

Expert mode is absent unless `LMPLOT_TRUSTED_LOCAL=1`. Both the configuration
module and use case enforce the gate. The public Docker image does not set the
flag and therefore cannot expose `eval(parse(...))`.

“ELI5” and “AI assistant” become **Guided interpretation**. The feature is
deterministic; the unused Ollama integration is deleted.

## 10. Accessible scientific visualization

The UI targets WCAG 2.2 AA:

- skip navigation, semantic landmarks/headings, explicit labels and errors;
- complete keyboard workflow and visible 2px-or-stronger focus indication;
- text/background contrast at least 4.5:1 for normal text and 3:1 for large
  text or meaningful graphical objects;
- status never conveyed by color alone;
- system/local fonts only; no Google Fonts or runtime web assets.

Each complex chart exposes units, N, uncertainty where available, a concise
text summary, and an underlying table/download. Plotly point selection and
previous/next observation buttons update Model Brain views without refitting.
The views include exact equation, contribution waterfall, link transformation,
coefficient overview, and GLMM random-effect view.

## 11. Deployment and release

Runtime code never invokes `install.packages()`. Dependency restoration occurs
only during explicit bootstrap or image build from committed `renv.lock`.

The Docker base is exactly:

```text
rocker/shiny:4.6.0@sha256:95a0d826be0bfc9bd41300385b35cf0ec074fc6b82cfaa92fddd7c6f6f2fd0dd
```

The image installs/restores locked dependencies, copies only required runtime
content, runs as the non-root `shiny` user, exposes 3838, and healthchecks `/`.
Compose applies resource limits, a read-only root filesystem with explicit
writable tmp mounts, and an internal network suitable for egress-blocked smoke
testing. TLS remains external.

GitHub Actions runs Windows and Linux R 4.6.0 jobs, the complete R suite,
`shinytest2`, CLI contract tests, Docker build, and container health. Release
metadata is `0.10.0-beta.1`; licensing is MIT, copyright “lmplot contributors”.

## 12. Acceptance

The release candidate must pass:

```text
Rscript -e "testthat::test_dir('tests', reporter='summary')"
docker compose config --quiet
docker build plus an egress-blocked container root-page healthcheck
git diff --check
```

CI must pass on Windows and Linux, followed by scientific copy review, the
accessibility checklist, and a staging smoke test. Rollback is the preceding
container tag; no data migration is required.
