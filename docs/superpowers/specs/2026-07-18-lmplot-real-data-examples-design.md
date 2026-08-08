# LM Plot Explorer — Scientific Real-Data Examples Design

**Status:** Approved in conversation
**Date:** 2026-07-18
**Target:** six beta model modes integrated into the Shiny application

## 1. Objective

Add one literature-backed, reproducible real-data example for each of the six
beta model modes:

| Model ID | Model | Required response domain |
|---|---|---|
| `lm_2d` | Simple linear model | finite continuous response |
| `lm_3d` | Multiple linear model | finite continuous response |
| `glm_binomial` | Binomial generalized linear model | binary response |
| `glm_poisson` | Poisson generalized linear model | non-negative integer response |
| `glm_gamma` | Gamma generalized linear model | strictly positive continuous response |
| `glmm` | Gaussian random-intercept mixed model | finite continuous response with grouping factor |

Users can switch between simulated data and a scientific real-data case inside
Shiny. Both sources use the same validation, fitting, prediction, diagnostic,
table, and plotting pipeline. The application also exports a reproducible
static graph for every real-data case.

## 2. Scope

The first release includes exactly one primary case per model. Each case must
have:

- a scientific publication that demonstrates or substantively analyzes the
  application domain;
- openly accessible data with redistribution terms that permit inclusion in
  the repository, or a deterministic retrieval workflow when redistribution is
  not permitted;
- a stable source URL and, when available, a DOI;
- an identifiable license or explicit usage terms;
- enough observations and suitable variables for the model and plot geometry;
- no direct personal identifiers or other unsuitable sensitive data;
- deterministic preprocessing from source variables to the model-ready table.

The work does not add arbitrary dataset uploads, arbitrary formulas, new model
families, random slopes, generalized mixed models, or a general literature
browser.

## 3. Research Workflow

Six independent research agents are assigned one model each. Because the
runtime supports three workers beside the coordinator, research runs in two
parallel waves of three agents.

Each agent must return an evidence package containing:

1. the primary publication and a direct source supporting the case;
2. the dataset landing page and direct machine-readable data location;
3. license or usage terms;
4. response, predictor, and grouping-variable candidates;
5. the model family and link used or justified by the publication;
6. preprocessing steps, exclusions, and missing-value handling;
7. one preferred dataset and one fallback when possible;
8. a short explanation of why the example is scientifically and visually
   suitable.

Primary papers, official repositories, journal supplements, institutional
archives, and authoritative package documentation are preferred. Secondary
blogs and unattributed mirrors are not acceptable evidence. The coordinator
verifies every citation, download, license statement, and variable mapping
before integration.

## 4. Selection Criteria

Cases are ranked in this order:

1. reproducibility and lawful redistribution;
2. scientific relevance to the assigned model;
3. compatibility with the beta response domain and fit contract;
4. compatibility with the existing 2D or 3D visualization geometry;
5. data quality and manageable preprocessing;
6. pedagogical clarity;
7. publication prominence or historical interest.

For the two-predictor plots, agents should prefer two continuous predictors.
If a scientifically important case includes additional covariates, the
integrated example uses a documented two-predictor specification instead of
silently fixing or discarding covariates. The GLMM case requires a grouping
factor with at least five observed levels.

## 5. Architecture

The beta model registry remains the single source of truth for model IDs,
families, links, dimensions, and response domains. Real-data support is added
through a separate example registry rather than model-specific conditions in
`app.R`.

Planned responsibilities:

| Path | Responsibility |
|---|---|
| `R/mod_examples.R` | Example registry, metadata access, loading, mapping, and validation |
| `data/real/manifest.csv` | Machine-readable provenance and model-variable mapping |
| `data/real/<model-id>/source.*` | Redistributable source snapshot when permitted |
| `data/real/<model-id>/model-data.csv` | Deterministic model-ready snapshot |
| `data/real/<model-id>/README.md` | Human-readable citation, license, variables, and transformations |
| `scripts/fetch_real_examples.R` | Rebuild source snapshots from stable upstream locations |
| `scripts/build_real_examples.R` | Normalize, validate, fit, and export all six cases |
| `artifacts/real-examples/<model-id>.png` | Reproducible static graph for handoff and QA |
| `tests/test_examples.R` | Registry, provenance, schema, fit, and plot contracts |

`app.R` remains a composition root. It does not download remote data during a
session and does not contain dataset-specific transformations.

## 6. Example Data Contract

Every integrated example exposes original, human-readable variable names and a
mapping to the canonical model roles:

- `response` maps to the observed outcome;
- `predictor_x` maps to the primary predictor;
- `predictor_y` is required for all three-dimensional modes;
- `group` is required only for `glmm`;
- `link` identifies the literature-backed default link;
- optional display labels and units preserve scientific meaning.

The loader returns a canonical analysis frame with `X`, optional `Y`, `Z`, and
optional `Group`, while retaining the original source columns for tables and
downloads. It also returns metadata separately; bibliographic fields are never
encoded as observation columns.

Validation rejects missing required variables, non-finite predictor values,
invalid response domains, unusable grouping factors, empty post-filter data,
duplicate manifest IDs, or absent provenance fields. Missing observations are
handled only by explicit, documented preprocessing rules.

## 7. Reproducibility and Provenance

The application reads bundled model-ready snapshots so all examples work
offline. The retrieval script records the source URL, retrieval date, upstream
file name, checksum, and license. The build script is deterministic and must
reproduce the committed model-ready file from the committed or retrieved
source.

When source redistribution is prohibited, the repository contains metadata and
the deterministic retrieval/preparation script but not the restricted raw
file. A candidate that cannot be retrieved automatically and lawfully is
rejected in favor of its fallback.

Each example README includes:

- full publication citation and DOI or stable URL;
- dataset citation and download location;
- license or usage terms;
- original variable definitions and units;
- analysis-variable mapping;
- row exclusions, transformations, and missing-value treatment;
- the model formula, family, and literature-backed default link;
- a statement distinguishing exact reproduction from pedagogical adaptation.

## 8. Shiny User Experience

The sidebar adds a data-source selector with `Simulation` and `Real data`.

In simulation mode, the existing beta controls and behavior remain unchanged.
In real-data mode:

- model-aware simulation controls are hidden;
- the example title and scientific domain are shown;
- a citation/provenance card displays publication, DOI or URL, data source,
  license, sample size, variable definitions, and preprocessing summary;
- `Generate & Fit` loads the bundled example and runs the common model pipeline;
- the literature-backed link becomes the default;
- alternative valid links remain selectable and are labeled exploratory;
- the table and CSV retain original variable labels and add `.fitted` and
  `.residual` values.

Changing model, source, or link updates available controls but does not replace
the last successful result until `Generate & Fit` is activated. A failed load
or fit leaves the previous successful result visible and shows one concise
error.

## 9. Graphs and Analysis

The six real-data graphs use the beta plotting contract:

- `lm_2d`: observed points and fitted line;
- `lm_3d`: observed point cloud and fitted response plane;
- `glm_binomial`: binary observations and fitted response-probability surface;
- `glm_poisson`: observed counts and fitted response-count surface;
- `glm_gamma`: observed positive response and fitted mean-response surface;
- `glmm`: observations colored by group and a population-level fixed-effect
  surface.

All GLM surfaces use `predict(..., type = "response")`. The GLMM population
surface excludes random effects while fitted values and residuals for observed
rows include their fitted group effects. Axes, tooltips, captions, and static
exports use the scientific variable names and units rather than only `X`, `Y`,
and `Z`.

Static graphs are produced by the same prediction and labeling helpers used by
Shiny. They include the example name, model family, response and predictor
labels, and a compact source citation. Static exports are QA artifacts, not a
second independent plotting implementation.

## 10. Error Handling

Network failures affect only explicit rebuild commands, never normal Shiny
sessions. Retrieval failures report the model ID, source URL, and underlying
error without deleting the last valid snapshot.

Checksum changes stop the rebuild and require review. Schema changes identify
the missing or changed source variables. License ambiguity blocks integration
of the candidate. Model-domain and fit errors use the same explicit validation
messages as simulated data.

## 11. Testing Strategy

Implementation follows red-green-refactor. Automated tests cover:

1. exactly six manifest entries matching the beta model registry;
2. complete citation, URL, license, retrieval, and variable-mapping metadata;
3. deterministic preparation and expected checksums;
4. required schemas, response domains, finite values, and GLMM group count;
5. successful fitting, response predictions, residuals, and enriched exports;
6. successful interactive and static plot construction for all six examples;
7. Shiny switching between simulation and real-data modes;
8. preservation of the last successful result after a load or fit error;
9. visible citations and exploratory-link labeling;
10. an offline application smoke test with no data download.

Visual QA renders all six static files and exercises every real-data case in a
real Shiny browser session.

## 12. Acceptance Criteria

The feature is complete only when:

- six independent research reports identify verified scientific cases;
- all six selected datasets have verified access and redistribution terms;
- the application loads every example without network access;
- every example passes its model-domain validation and fits successfully;
- all six interactive graphs render with scientific labels and citations;
- all six static graphs are freshly regenerated and visually inspected;
- the publication, dataset, license, transformations, and model mapping are
  documented per example;
- simulations and real data share one validated model and plot pipeline;
- alternative GLM links are clearly marked exploratory;
- automated unit, server, browser, and offline smoke tests pass;
- no temporary downloads, browser artifacts, or Graphify files are included in
  the final change set.
