# Streamlit + R public MVP design

> **Superseded on 2026-09-22.** The public product is now the Shiny-only
> application defined in `2026-09-22-lmplot-public-shiny-hardening-design.md`.
> This document remains as historical context; its Streamlit, Python runtime,
> and deployment decisions are no longer requirements.

Date: 2026-07-27
Status: approved for specification

## ELI5 summary

Streamlit is the shop window: it shows the controls, tables, and charts. R is
the statistician in the workshop: it receives a small, well-defined analysis
request, performs the calculation, and returns the results. Docker puts
Streamlit, R, and every required dependency in one portable box that can run
locally or on a public hosting service.

## Objective

Migrate the first useful vertical slice of LM Plot Explorer from a Shiny user
interface to a Streamlit dashboard while keeping R as the sole statistical
engine. Publish the source in the existing public GitHub repository and deploy
the MVP publicly from one Docker image.

The MVP must remain pedagogical, reproducible, and safe to expose on the
internet. It must not evaluate formulas or code supplied by a visitor.

## MVP scope

The first public release supports exactly three analysis configurations:

| Model ID | R fit | Link | Real-data example |
|---|---|---|---|
| `lm_2d` | `stats::lm` | identity | Adélie penguin body mass |
| `glm_binomial` | `stats::glm(family = binomial)` | logit | Adélie penguin sex |
| `glm_poisson` | `stats::glm(family = poisson)` | log | Abalone shell-ring count |

Each configuration supports:

- deterministic simulation controlled by an explicit seed;
- its bundled, provenance-documented real-data example;
- an interactive response-scale visualization;
- coefficients and a compact model summary;
- essential model-appropriate diagnostics;
- a preview of the analysis data;
- an enriched CSV export containing the response, fitted value, and residual.

## Out of scope

The MVP does not include the multiple linear model, Gamma GLM, Gaussian mixed
model, alternate links, uploaded datasets, arbitrary formulas, arbitrary R
code, user accounts, saved server-side projects, report generation, or an API
for third-party clients. The existing full Shiny implementation remains
available temporarily under `legacy/` for parity checks during migration.

## Chosen architecture

The application uses one Docker container and a subprocess boundary between
Python and R.

```text
Browser
  -> Streamlit UI
  -> Python validation and R bridge
  -> per-request temporary directory
  -> Rscript analysis entry point
  -> result JSON + enriched CSV
  -> Plotly, tables, summary, and download in Streamlit
```

This design was selected over two alternatives:

1. Embedding R with `rpy2` would reduce process startup time but create a more
   fragile Python/R ABI and deployment surface.
2. Running a separate Plumber service would provide a scalable service
   boundary but require two deployments, network security, and additional
   operations that the MVP does not need.

The `Rscript` process boundary is simple to inspect, deterministic, portable,
and sufficient for the expected teaching workload.

## Components and responsibilities

### Streamlit entry point

`streamlit_app.py` owns page configuration, navigation, forms, session-facing
state, result presentation, and download buttons. It does not implement
statistical formulas or parse untrusted R output directly.

### Python application package

The `lmplot/` package contains:

- a closed model registry with the three supported configurations;
- typed request validation and safe numeric bounds;
- temporary-directory lifecycle management;
- the `Rscript` subprocess invocation, timeout, and output capture;
- response-schema validation;
- presentation helpers that convert validated results to Plotly figures and
  Streamlit-ready tables.

The bridge passes arguments as data, never as interpolated R source code or
shell fragments.

### R analysis layer

The R layer contains small functions for:

- deterministic simulation for each model;
- loading and validating the three bundled real datasets;
- fitting the selected fixed model specification;
- producing model-specific summaries and diagnostics;
- writing a versioned result document and enriched CSV.

The command-line entry point accepts paths to an input JSON document, an input
CSV when required, an output JSON document, and an output CSV document. It
selects work only through the closed model registry.

### Data and provenance

The existing prepared CSV files, source snapshots, checksums, licenses, and
example-specific README files remain the canonical real-data assets. Normal
dashboard sessions do not fetch remote data. Provenance links are displayed
for people who want to inspect the original publication or dataset.

### Legacy application

The current Shiny implementation moves to `legacy/` without being rewritten.
It is excluded from the production container entry point but remains usable
during the migration to compare statistical outputs and interaction coverage.

## Interchange contract

The request JSON includes:

- schema version;
- model ID;
- data-source ID (`simulation` or `real`);
- random seed and permitted simulation parameters when applicable;
- requested diagnostic set.

The result JSON includes:

- schema version and application version;
- model ID and data-source metadata;
- row count and elapsed fit time;
- coefficient names, estimates, standard errors, statistics, and p-values;
- model-appropriate goodness-of-fit metrics;
- warnings intended for display;
- visualization metadata;
- diagnostic metadata;
- the relative name of the enriched CSV output.

Tabular observations travel as CSV to keep the boundary transparent and easy
to reproduce outside Python. JSON values that are not finite are represented
as `null` plus a display warning. Python rejects results with the wrong schema,
missing fields, unexpected output paths, or an unsuccessful R exit status.

## User experience

The first dashboard copy explains in plain language that Streamlit controls the
experience while R calculates the statistics.

The sidebar contains the model, data source, and relevant simulation controls.
Changing a control does not launch R. A clearly labelled “Fit model” action
submits the complete request.

The result page presents, in order:

1. the interactive visualization;
2. key metrics and coefficient table;
3. essential diagnostics;
4. analysis-data preview;
5. the enriched CSV download.

Real-data mode also presents publication, dataset, license, variable
definitions, preprocessing, and pedagogical-adaptation metadata. A visible
label states that R produced the statistical results.

## Failure handling and public safety

Python validates model IDs, source IDs, seeds, numeric ranges, and request
shape before starting R. The R layer validates the schema and the statistical
domain again.

Every analysis runs in a unique temporary directory with a fixed timeout and a
bounded input size. Temporary files are deleted after the response or error.
The application never accepts uploaded files, arbitrary formulas, package
names, filesystem paths, shell text, or executable code in the MVP.

Expected statistical warnings are returned as concise user-facing messages.
Invalid data, failed fits, timeouts, malformed output, and unavailable R
processes produce recoverable Streamlit error states. Browser users never see
stack traces, local paths, environment variables, or raw subprocess commands.
Detailed server logs exclude observation-level data.

## Packaging and public deployment

One multi-runtime `Dockerfile` installs a pinned Python runtime, a pinned R
runtime, required system libraries, locked Python packages, and locked R
packages. The container starts Streamlit on the host-provided port, runs as a
non-root user, exposes a health endpoint, and contains no development secrets.

The initial public target is Render, connected to the public GitHub repository
and built from the Dockerfile. The design remains portable to another
Docker-compatible host. Production configuration is supplied through
environment variables; no credentials are committed.

The application code uses the MIT license. Bundled datasets and source
snapshots retain their existing upstream licenses, which remain documented in
the data NOTICE and example metadata. Public deployment occurs only after the
same Git revision and locked container definition pass their automated checks.

## Verification strategy

### R tests

`testthat` verifies deterministic simulations, input validation, model fits,
coefficient and prediction shapes, diagnostics, enriched exports, and the
versioned output schema. Fixed seeds and small committed fixtures make expected
results reproducible.

### Python tests

`pytest` verifies model-registry validation, request serialization, safe
subprocess arguments, timeouts, cleanup, response validation, error mapping,
Plotly preparation, and CSV download behavior.

### Cross-language integration

Integration tests run the real `Rscript` entry point, validate the complete
JSON/CSV round trip, and compare bridge results with direct R calculations
within explicit numeric tolerances. Selected fixtures are also compared with
the legacy Shiny engine to detect unintended scientific drift.

### Application and container checks

A Streamlit smoke test verifies startup and the health endpoint. A Docker check
builds the production image, starts it, exercises one deterministic analysis,
and verifies that the service responds without running as root.

GitHub Actions runs R, Python, integration, and container checks for pull
requests and the default branch.

## README structure

The public README is ordered as follows:

1. ELI5 summary;
2. live public dashboard link and screenshot;
3. prominent development-workflow note recommending **Codex with Sol in Extra
   High reasoning mode** to understand, verify, and extend the repository;
4. supported MVP models and limitations;
5. local Docker quick start;
6. optional native Python/R development setup;
7. technical Python–R architecture and data flow;
8. testing and reproducibility;
9. real-data provenance and licenses;
10. deployment notes, security boundary, contribution guidance, and MIT
    license.

The Codex section describes the recommendation as a reproducible engineering
workflow: inspect before editing, make scoped changes, run both language test
suites, and review generated statistical code and documentation. It does not
claim that model choice or high reasoning effort replaces scientific review.

## Acceptance criteria

The MVP is complete when:

- all three fixed model configurations work with simulation and their bundled
  real-data example;
- every successful fit is performed by R through the documented contract;
- the visualization, compact results, diagnostics, data preview, and enriched
  CSV are available in Streamlit;
- invalid or failed requests recover without exposing internals;
- deterministic fixtures agree with direct R results within documented
  tolerances;
- the production Docker image passes automated checks;
- the GitHub repository is public, licensed, and contains the ordered README;
- the deployed public URL passes the health check and one end-to-end analysis.
