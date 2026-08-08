# Streamlit + R Public MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a publicly deployed Streamlit MVP for three fixed teaching models while keeping R as the sole statistical engine.

**Architecture:** Streamlit validates a closed request schema and invokes a short-lived `Rscript` process with argument-list execution, JSON control documents, and CSV tabular output. One Docker image contains Python 3.12, R 4.6.0, the locked dependencies, the public dashboard, and the health endpoint; the existing Shiny app remains under `legacy/` for parity checks.

**Tech Stack:** Python 3.12, Streamlit, Pydantic, pandas, Plotly, pytest, R 4.6.0, `stats`, `jsonlite`, `testthat`, `renv`, Docker, Render, GitHub Actions.

## Global Constraints

- R is the sole statistical engine; Python must not fit or approximate a model.
- The only model IDs are `lm_2d`, `glm_binomial`, and `glm_poisson`.
- The only links are identity for `lm_2d`, logit for `glm_binomial`, and log for `glm_poisson`.
- The only data sources are deterministic simulation and the three committed real examples.
- Simulation sample size is an integer from 10 through 2,000.
- No uploaded data, arbitrary formulas, package names, filesystem paths, shell text, or executable code are accepted.
- The request/result schema version is exactly `1.0`.
- Every R subprocess uses an argument list, `shell=False`, a unique temporary directory, and a 30-second timeout.
- Successful exports contain all source columns plus `.fitted` and `.residual`.
- Python 3.12 and R 4.6.0 dependencies are locked and restored during image construction.
- The production process runs as non-root and binds to `0.0.0.0:${PORT:-8501}`.
- Code uses the MIT license; bundled data retain their upstream licenses and notices.
- The README starts with an ELI5 explanation and prominently recommends **Codex with Sol in Extra High reasoning mode**.
- Preserve unrelated working-tree changes, including the existing local `.gitignore` modification.

---

## Planned File Structure

### Python application

- `streamlit_app.py`: minimal executable entry point calling `lmplot.ui.main()`.
- `lmplot/__init__.py`: application and schema version constants.
- `lmplot/registry.py`: immutable definitions for the three supported models.
- `lmplot/contracts.py`: Pydantic request, result, plot, diagnostic, and error schemas.
- `lmplot/bridge.py`: safe subprocess boundary, temporary files, timeout, and CSV loading.
- `lmplot/plots.py`: validated result/data to Plotly figure conversion.
- `lmplot/ui.py`: Streamlit controls, submit flow, result rendering, provenance, and download.

### R engine

- `R/simulation_core.R`: UI-free deterministic simulation and domain checks.
- `R/mvp_analysis.R`: closed MVP registry, data selection, fit orchestration, summaries, diagnostics, and prediction grids.
- `scripts/run_analysis.R`: four-argument JSON/CSV command-line adapter and sanitized error document.
- Existing `R/mod_model.R`, `R/mod_visualization.R`, and `R/mod_examples.R`: reused statistical and provenance functions; `R/mod_simulation.R` retains Shiny controls plus calls into `simulation_core.R`.

### Legacy application

- `legacy/app.R`: moved Shiny entry point.
- `legacy/www/style.css`: moved Shiny stylesheet.
- `legacy/run.bat`: Shiny-only Windows launcher that activates the root `renv`.

### Packaging and operations

- `pyproject.toml`, `.python-version`, `requirements.lock`, `renv-mvp.lock`: Python metadata and production R/Python locks.
- `Dockerfile`, `.dockerignore`, `render.yaml`: reproducible public container and Render Blueprint.
- `.streamlit/config.toml`: public-safe Streamlit defaults.
- `.github/workflows/ci.yml`: R, Python, integration, and container gates.
- `scripts/container_smoke.py`: cross-platform container health and deterministic-analysis smoke check.

### Tests and documentation

- `tests/python/`: Python unit, application, repository, and integration tests.
- `tests/test_mvp_analysis.R`: direct R engine tests.
- `tests/test_mvp_runner.R`: command-line contract tests.
- Existing Shiny tests: retained and redirected to `legacy/`.
- `README.md`, `LICENSE`, `docs/dashboard.png`: public documentation and evidence.

---

### Task 1: Define the Python Project, Registry, and Versioned Contracts

**Files:**
- Create: `.python-version`
- Create: `pyproject.toml`
- Create: `requirements.lock`
- Create: `lmplot/__init__.py`
- Create: `lmplot/registry.py`
- Create: `lmplot/contracts.py`
- Create: `tests/python/test_registry.py`
- Create: `tests/python/test_contracts.py`

**Interfaces:**
- Consumes: no application code; only the global constants in this plan.
- Produces: `APP_VERSION`, `SCHEMA_VERSION`, `MVP_MODELS`, `model_spec()`, `SimulationParameters`, `AnalysisRequest`, `AnalysisResult`, `AnalysisErrorDocument`, `PlotPayload`, and `DiagnosticPayload`.

- [ ] **Step 1: Add failing registry and contract tests**

```python
# tests/python/test_registry.py
import pytest

from lmplot.registry import MVP_MODELS, model_spec


def test_registry_is_the_exact_public_mvp():
    assert tuple(MVP_MODELS) == ("lm_2d", "glm_binomial", "glm_poisson")
    assert MVP_MODELS["lm_2d"].link == "identity"
    assert MVP_MODELS["glm_binomial"].real_example_id == "adelie_sex"
    assert MVP_MODELS["glm_poisson"].real_example_id == "abalone_rings"


def test_unknown_model_is_rejected():
    with pytest.raises(ValueError, match="Unsupported model"):
        model_spec("glm_gamma")
```

```python
# tests/python/test_contracts.py
import pytest
from pydantic import ValidationError

from lmplot.contracts import AnalysisRequest, SimulationParameters


def test_simulation_request_has_a_closed_schema():
    request = AnalysisRequest(
        model_id="glm_binomial",
        data_source="simulation",
        simulation=SimulationParameters(n=80, seed=12),
    )
    assert request.schema_version == "1.0"
    assert request.model_dump(mode="json")["simulation"]["beta2"] == -0.25


def test_real_request_forbids_simulation_parameters():
    with pytest.raises(ValidationError, match="must be omitted"):
        AnalysisRequest(
            model_id="lm_2d",
            data_source="real",
            simulation=SimulationParameters(),
        )


@pytest.mark.parametrize("n", [9, 2001])
def test_sample_size_is_bounded(n):
    with pytest.raises(ValidationError):
        SimulationParameters(n=n)


def test_extra_fields_are_forbidden():
    with pytest.raises(ValidationError):
        AnalysisRequest.model_validate(
            {
                "schema_version": "1.0",
                "model_id": "lm_2d",
                "data_source": "real",
                "formula": "Z ~ .",
            }
        )
```

- [ ] **Step 2: Run the tests and confirm the missing-package failure**

Run:

```powershell
py -3.12 -m pytest tests/python/test_registry.py tests/python/test_contracts.py -q
```

Expected: collection fails with `ModuleNotFoundError: No module named 'lmplot'`.

- [ ] **Step 3: Add the exact project metadata and model registry**

Create `.python-version` with:

```text
3.12
```

Create `pyproject.toml` with Python 3.12, these direct runtime dependencies,
and these development tools:

```toml
[project]
name = "lmplot"
version = "1.0.0"
description = "Streamlit teaching dashboard with an R statistical engine"
requires-python = ">=3.12,<3.13"
dependencies = [
  "pandas==2.3.1",
  "plotly==6.2.0",
  "pydantic==2.11.7",
  "streamlit==1.47.1",
]

[dependency-groups]
dev = [
  "playwright==1.54.0",
  "pytest==8.4.1",
  "pytest-timeout==2.4.0",
]

[tool.pytest.ini_options]
testpaths = ["tests/python"]
markers = [
  "integration: invokes the real R engine",
  "container: requires a local Docker daemon",
]
```

Create `lmplot/__init__.py`:

```python
APP_VERSION = "1.0.0"
SCHEMA_VERSION = "1.0"
```

Create `lmplot/registry.py` with an immutable `ModelSpec` dataclass:

```python
from dataclasses import dataclass
from types import MappingProxyType
from typing import Literal

ModelId = Literal["lm_2d", "glm_binomial", "glm_poisson"]


@dataclass(frozen=True, slots=True)
class ModelSpec:
    id: ModelId
    label: str
    family: str
    link: str
    dimensions: int
    real_example_id: str
    plot_kind: Literal["line_2d", "surface_3d"]


MVP_MODELS = MappingProxyType(
    {
        "lm_2d": ModelSpec(
            "lm_2d", "Simple linear model", "gaussian", "identity", 2,
            "adelie_flipper_mass", "line_2d",
        ),
        "glm_binomial": ModelSpec(
            "glm_binomial", "Binomial GLM", "binomial", "logit", 3,
            "adelie_sex", "surface_3d",
        ),
        "glm_poisson": ModelSpec(
            "glm_poisson", "Poisson GLM", "poisson", "log", 3,
            "abalone_rings", "surface_3d",
        ),
    }
)


def model_spec(model_id: str) -> ModelSpec:
    try:
        return MVP_MODELS[model_id]
    except KeyError as error:
        raise ValueError(f"Unsupported model: {model_id}") from error
```

- [ ] **Step 4: Implement the closed Pydantic schemas**

Use `ConfigDict(extra="forbid")` on every externally parsed model. Define:

```python
class SimulationParameters(BaseModel):
    model_config = ConfigDict(extra="forbid")
    n: int = Field(default=200, ge=10, le=2000)
    seed: int = Field(default=123, ge=-2147483648, le=2147483647)
    beta0: float = Field(default=2.0, ge=-3.0, le=5.0)
    beta1: float = Field(default=0.5, ge=-2.0, le=2.0)
    beta2: float = Field(default=-0.25, ge=-2.0, le=2.0)
    sigma: float = Field(default=1.0, ge=0.1, le=5.0)


class AnalysisRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    schema_version: Literal["1.0"] = SCHEMA_VERSION
    model_id: ModelId
    data_source: Literal["simulation", "real"]
    simulation: SimulationParameters | None = None
    diagnostics: tuple[Literal["residuals_vs_fitted", "qq"], ...] = ("residuals_vs_fitted", "qq")

    @model_validator(mode="after")
    def validate_source_payload(self):
        if self.data_source == "simulation" and self.simulation is None:
            raise ValueError("simulation parameters are required")
        if self.data_source == "real" and self.simulation is not None:
            raise ValueError("simulation parameters must be omitted")
        return self
```

Also define the result-side models with these exact fields:

```python
class Coefficient(BaseModel):
    term: str
    estimate: float | None
    std_error: float | None
    statistic: float | None
    p_value: float | None


class PlotPoint(BaseModel):
    x: float
    y: float | None = None
    fitted: float


class PlotPayload(BaseModel):
    kind: Literal["line_2d", "surface_3d"]
    x_label: str
    y_label: str | None = None
    response_label: str
    prediction: list[PlotPoint]


class DiagnosticPoint(BaseModel):
    x: float
    y: float


class DiagnosticPayload(BaseModel):
    residuals_vs_fitted: list[DiagnosticPoint]
    qq: list[DiagnosticPoint]


class SourceMetadata(BaseModel):
    title: str
    publication_url: str | None
    dataset_url: str | None
    license_name: str | None
    license_url: str | None
    preprocessing_summary: str | None
    adaptation_note: str | None


class AnalysisResult(BaseModel):
    model_config = ConfigDict(extra="forbid")
    schema_version: Literal["1.0"]
    status: Literal["ok"]
    app_version: str
    model_id: ModelId
    data_source: Literal["simulation", "real"]
    row_count: int = Field(gt=0, le=5000)
    elapsed_ms: float = Field(ge=0)
    coefficients: list[Coefficient]
    metrics: dict[str, float | None]
    warnings: list[str]
    plot: PlotPayload
    diagnostics: DiagnosticPayload
    source: SourceMetadata | None
    csv_name: str = Field(pattern=r"^[A-Za-z0-9_.-]+$")


class AnalysisError(BaseModel):
    code: Literal[
        "invalid_request", "analysis_failed", "timeout", "invalid_output"
    ]
    message: str = Field(min_length=1, max_length=300)


class AnalysisErrorDocument(BaseModel):
    model_config = ConfigDict(extra="forbid")
    schema_version: Literal["1.0"]
    status: Literal["error"]
    error: AnalysisError
```

- [ ] **Step 5: Lock Python dependencies and run the contract tests**

Run:

```powershell
py -3.12 -m pip install uv==0.8.4
py -3.12 -m uv lock
py -3.12 -m uv export --frozen --no-dev --format requirements-txt --output-file requirements.lock
py -3.12 -m uv run pytest tests/python/test_registry.py tests/python/test_contracts.py -q
```

Expected: all registry and contract tests pass; `uv.lock` and
`requirements.lock` are generated from `pyproject.toml`.

- [ ] **Step 6: Commit the Python contract slice**

```powershell
git add .python-version pyproject.toml uv.lock requirements.lock lmplot tests/python/test_registry.py tests/python/test_contracts.py
git commit -m "feat: define Streamlit R analysis contract"
```

---

### Task 2: Build the Closed R Analysis Engine

**Files:**
- Create: `R/mvp_analysis.R`
- Create: `R/simulation_core.R`
- Create: `tests/test_mvp_analysis.R`
- Modify: `R/config.R:1`
- Modify: `R/mod_simulation.R:1-81`
- Test: `tests/test_mvp_analysis.R`

**Interfaces:**
- Consumes: the `1.0` request/result field names and the existing
  `simulate_data()`, `load_real_example()`, `fit_model()`, `enrich_data()`,
  and `prediction_grid()` functions.
- Produces: `validate_mvp_request(request)`,
  `run_mvp_analysis(request, root = ".")`, and a named list matching
  `AnalysisResult`.

- [ ] **Step 1: Write failing direct-engine tests**

At test setup, source `R/config.R`, `R/mod_model.R`,
`R/simulation_core.R`, `R/mod_visualization.R`, `R/mod_examples.R`, and
`R/mvp_analysis.R` from the repository root.

```r
test_that("the R MVP registry is closed", {
  expect_identical(mvp_model_ids(), c("lm_2d", "glm_binomial", "glm_poisson"))
  expect_error(
    validate_mvp_request(list(
      schema_version = "1.0",
      model_id = "glm_gamma",
      data_source = "real",
      diagnostics = c("residuals_vs_fitted", "qq")
    )),
    "Unsupported model"
  )
})

test_that("deterministic LM simulation produces the complete contract", {
  request <- list(
    schema_version = "1.0",
    model_id = "lm_2d",
    data_source = "simulation",
    simulation = list(
      n = 80L, seed = 12L, beta0 = 2, beta1 = 0.5,
      beta2 = -0.25, sigma = 1
    ),
    diagnostics = c("residuals_vs_fitted", "qq")
  )

  first <- run_mvp_analysis(request, root = release_root)
  second <- run_mvp_analysis(request, root = release_root)

  expect_identical(first$schema_version, "1.0")
  expect_identical(first$status, "ok")
  expect_identical(first$model_id, "lm_2d")
  expect_equal(first$row_count, 80L)
  expect_equal(first$coefficients, second$coefficients, tolerance = 1e-12)
  expect_identical(names(first$enriched), c("X", "Z", ".fitted", ".residual"))
  expect_length(first$diagnostics$residuals_vs_fitted, 80L)
  expect_length(first$diagnostics$qq, 80L)
})

test_that("each MVP real example selects its documented data", {
  expected_rows <- c(lm_2d = 151L, glm_binomial = 146L, glm_poisson = 4177L)
  for (model_id in names(expected_rows)) {
    result <- run_mvp_analysis(list(
      schema_version = "1.0",
      model_id = model_id,
      data_source = "real",
      diagnostics = c("residuals_vs_fitted", "qq")
    ), root = release_root)
    expect_equal(result$row_count, expected_rows[[model_id]], info = model_id)
    expect_true(nzchar(result$source$license_name), info = model_id)
  }
})
```

- [ ] **Step 2: Run the direct-engine test and confirm the missing-file failure**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_mvp_analysis.R', reporter='summary')"
```

Expected: failure because `R/mvp_analysis.R` does not exist.

- [ ] **Step 3: Extract UI-free deterministic simulation**

Move `simulate_data()` and `validate_simulation_data()` without behavior changes
from `R/mod_simulation.R` into `R/simulation_core.R`. Keep
`evaluate_expert_simulation()`, `simulation_code()`, `sim_ui()`, and
`sim_server()` in `R/mod_simulation.R`. At its top use:

```r
simulation_core_path <- if (file.exists(file.path("R", "simulation_core.R"))) {
  file.path("R", "simulation_core.R")
} else {
  file.path("..", "R", "simulation_core.R")
}
if (!exists("simulate_data", inherits = TRUE)) {
  source(simulation_core_path, local = TRUE)
}

Run `testthat::test_file('tests/test_simulation.R', reporter='summary')` with
R 4.6.0. Expected: all existing deterministic and domain tests pass unchanged.

- [ ] **Step 4: Add a closed R registry and strict request validation**

Set `APP_VERSION <- "1.0.0"` in `R/config.R`.

In `R/mvp_analysis.R`, define:

```r
MVP_MODEL_LINKS <- c(
  lm_2d = "identity",
  glm_binomial = "logit",
  glm_poisson = "log"
)

MVP_REAL_EXAMPLES <- c(
  lm_2d = "adelie_flipper_mass",
  glm_binomial = "adelie_sex",
  glm_poisson = "abalone_rings"
)

mvp_model_ids <- function() names(MVP_MODEL_LINKS)
```

`validate_mvp_request()` must:

- require a named list and `schema_version == "1.0"`;
- reject names outside `schema_version`, `model_id`, `data_source`,
  `simulation`, and `diagnostics`;
- require one allowed model and one source;
- reject `simulation` for real data and require it for simulation;
- derive the fixed link from `MVP_MODEL_LINKS` and reject a request `link` field;
- require diagnostics to equal the two allowed names;
- validate `n`, `seed`, `beta0`, `beta1`, `beta2`, and `sigma` against the
  global bounds before calling existing simulation code.

- [ ] **Step 5: Implement data selection, fitting, metrics, and provenance**

Implement these focused helpers:

```r
load_mvp_data <- function(request, root = ".")
capture_mvp_fit <- function(data, model_id, link)
coefficient_records <- function(fit)
metric_records <- function(fit)
diagnostic_records <- function(fit)
plot_payload <- function(data, fit, model_id, source = NULL)
source_metadata <- function(example)
run_mvp_analysis <- function(request, root = ".")
```

Use the existing engine through an analysis/export bundle:

```r
bundle <- if (request$data_source == "simulation") {
  analysis <- do.call(
    simulate_data,
    c(
      list(
        model_type = request$model_id,
        link = unname(MVP_MODEL_LINKS[[request$model_id]])
      ),
      request$simulation
    )
  )
  list(analysis = analysis, export = analysis, metadata = NULL)
} else {
  example_id <- unname(MVP_REAL_EXAMPLES[[request$model_id]])
  example <- load_real_example(example_id, root = root)
  export <- utils::read.csv(
    file.path(root, "data", "real", example_id, "model-data.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  list(
    analysis = example$analysis,
    export = export,
    metadata = example$metadata
  )
}
```

Capture and muffle fit warnings narrowly with `withCallingHandlers()`. Build
coefficients from `coef(summary(fit))` using its first four columns. Return LM
metrics `r_squared`, `adjusted_r_squared`, `sigma`, and `aic`; return GLM
metrics `deviance`, `null_deviance`, `dispersion`, and `aic`.

For diagnostics, use response residuals for residuals-versus-fitted and
`stats::residuals(fit, type = "deviance")` for GLM QQ points. Use
`stats::qqnorm(values, plot.it = FALSE)` and emit records shaped as
`list(x = ..., y = ...)`.

For plots, use `prediction_grid(data, fit, model_id, length_out = 30L)`. Emit
`line_2d` for `lm_2d`, `surface_3d` for the GLMs, and preserve the scientific
axis labels from the example metadata in real mode.

Fit only `bundle$analysis`. Build `enriched` from `bundle$export` by appending
fitted values and response residuals in the original row order.
`run_mvp_analysis()` must return `enriched` only as an internal field for the
runner to write. Every public field must match `AnalysisResult`, with
`csv_name = "enriched.csv"`.

- [ ] **Step 6: Run direct R tests and the existing model tests**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_mvp_analysis.R', reporter='summary'); testthat::test_file('tests/test_model.R', reporter='summary'); testthat::test_file('tests/test_simulation.R', reporter='summary')"
```

Expected: all tests pass with no unexpected warnings.

- [ ] **Step 7: Commit the R engine slice**

```powershell
git add R/config.R R/simulation_core.R R/mod_simulation.R R/mvp_analysis.R tests/test_mvp_analysis.R
git commit -m "feat: add closed R analysis engine"
```

---

### Task 3: Add the R Command Adapter and Safe Python Bridge

**Files:**
- Create: `scripts/run_analysis.R`
- Create: `lmplot/bridge.py`
- Create: `tests/test_mvp_runner.R`
- Create: `tests/python/test_bridge.py`
- Create: `tests/python/test_bridge_integration.py`
- Modify: `pyproject.toml`
- Modify: `uv.lock`
- Modify: `requirements.lock`

**Interfaces:**
- Consumes: `AnalysisRequest`, `AnalysisResult`, `AnalysisErrorDocument`, and
  `run_mvp_analysis()`.
- Produces: `BridgeResult`, `BridgeError`, `RAnalysisError`,
  `InvalidRResultError`, and
  `run_analysis(request, timeout_seconds=30, rscript=None, project_root=None)`.

- [ ] **Step 1: Write failing runner and bridge tests**

```r
test_that("runner writes a sanitized error document for an invalid request", {
  request <- tempfile(fileext = ".json")
  result <- tempfile(fileext = ".json")
  csv <- tempfile(fileext = ".csv")
  jsonlite::write_json(list(
    schema_version = "1.0",
    model_id = "glm_gamma",
    data_source = "real",
    diagnostics = c("residuals_vs_fitted", "qq")
  ), request, auto_unbox = TRUE)

  status <- system2(
    file.path(R.home("bin"), "Rscript"),
    c("scripts/run_analysis.R", request, result, csv, "."),
    stdout = TRUE,
    stderr = TRUE
  )
  document <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  expect_true(attr(status, "status") != 0L)
  expect_identical(document$status, "error")
  expect_identical(document$error$code, "invalid_request")
  expect_false(grepl(normalizePath("."), document$error$message, fixed = TRUE))
})
```

```python
# tests/python/test_bridge.py
import subprocess

import pytest

from lmplot.bridge import RAnalysisError, run_analysis
from lmplot.contracts import AnalysisRequest


def test_bridge_uses_argument_list_without_a_shell(monkeypatch, tmp_path):
    observed = {}

    def fake_run(command, **kwargs):
        observed["command"] = command
        observed.update(kwargs)
        result_path = command[3]
        csv_path = command[4]
        result_path.write_text(
            '{"schema_version":"1.0","status":"error",'
            '"error":{"code":"analysis_failed","message":"fit failed"}}',
            encoding="utf-8",
        )
        csv_path.write_text("X,Z,.fitted,.residual\n", encoding="utf-8")
        return subprocess.CompletedProcess(command, 3, "", "")

    monkeypatch.setattr(subprocess, "run", fake_run)
    with pytest.raises(RAnalysisError, match="fit failed"):
        run_analysis(
            AnalysisRequest(model_id="lm_2d", data_source="real"),
            project_root=tmp_path,
            rscript="Rscript",
        )

    assert observed["shell"] is False
    assert isinstance(observed["command"], list)
    assert observed["timeout"] == 30
```

```python
# tests/python/test_bridge_integration.py
import pytest

from lmplot.bridge import run_analysis
from lmplot.contracts import AnalysisRequest, SimulationParameters


@pytest.mark.integration
def test_real_r_round_trip_is_deterministic():
    request = AnalysisRequest(
        model_id="lm_2d",
        data_source="simulation",
        simulation=SimulationParameters(n=80, seed=12),
    )
    first = run_analysis(request)
    second = run_analysis(request)
    assert first.result.coefficients == second.result.coefficients
    assert list(first.enriched.columns) == ["X", "Z", ".fitted", ".residual"]
    assert len(first.csv_bytes) > 100
```

- [ ] **Step 2: Run the focused tests and confirm missing interfaces**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_mvp_runner.R', reporter='summary')"
py -3.12 -m uv run pytest tests/python/test_bridge.py tests/python/test_bridge_integration.py -q
```

Expected: R fails because `scripts/run_analysis.R` is absent and Python fails
because `lmplot.bridge` is absent.

- [ ] **Step 3: Implement the four-argument R runner**

`scripts/run_analysis.R` must accept exactly:

```text
request.json result.json enriched.csv project-root
```

Normalize the supplied project root, source `R/config.R`, `R/mod_model.R`,
`R/simulation_core.R`, `R/mod_visualization.R`, `R/mod_examples.R`, and
`R/mvp_analysis.R` by joining them to that root, and never treat a request
value as a path.

Use this top-level behavior:

```r
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) {
  cat("Usage: run_analysis.R REQUEST RESULT CSV PROJECT_ROOT\n", file = stderr())
  quit(status = 64L)
}
```

Write JSON with:

```r
jsonlite::write_json(
  document,
  path = result_path,
  auto_unbox = TRUE,
  null = "null",
  na = "null",
  digits = NA,
  pretty = FALSE
)
```

On success, remove the internal `enriched` field before writing the result JSON,
write the enriched CSV with `row.names = FALSE` and `na = ""`, and exit zero.

On failure, classify validation messages as `invalid_request` and other
conditions as `analysis_failed`; strip line breaks, truncate the public message
to 300 characters, write the error document, and exit with status 2 or 3. Raw
errors may go to server logs only when they contain no request rows, environment
values, or filesystem paths.

- [ ] **Step 4: Implement the safe Python bridge**

Define:

```python
@dataclass(frozen=True, slots=True)
class BridgeResult:
    result: AnalysisResult
    enriched: pd.DataFrame
    csv_bytes: bytes


class BridgeError(RuntimeError):
    pass


class RAnalysisError(BridgeError):
    pass


class InvalidRResultError(BridgeError):
    pass
```

`run_analysis()` must:

1. resolve the project root from the explicit argument or
   `Path(__file__).resolve().parents[1]`;
2. resolve `rscript` from the explicit argument, `LMPLOT_RSCRIPT`, or
   `shutil.which("Rscript")`;
3. create `TemporaryDirectory(prefix="lmplot-")`;
4. write `request.model_dump_json()` to `request.json`;
5. call
   `[rscript, runner, request_path, result_path, csv_path, project_root]`
   with `shell=False`, `cwd=project_root`, `timeout=30`, `capture_output=True`,
   `text=True`, and `check=False`;
6. map `TimeoutExpired` to `BridgeError("The R analysis timed out.")`;
7. parse a nonzero result only through `AnalysisErrorDocument`;
8. parse a zero result through `AnalysisResult`;
9. require `result.csv_name == "enriched.csv"` and require the CSV to remain
   inside the temporary directory;
10. load with pandas, require `.fitted` and `.residual`, copy the original CSV
    bytes, and return `BridgeResult` before temporary cleanup.

Do not include `stdout`, `stderr`, command arguments, or local paths in public
exception messages.

- [ ] **Step 5: Run R, Python unit, and real integration tests**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_mvp_runner.R', reporter='summary')"
py -3.12 -m uv run pytest tests/python/test_bridge.py -q
$env:LMPLOT_RSCRIPT = "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe"
py -3.12 -m uv run pytest tests/python/test_bridge_integration.py -m integration -q
```

Expected: every test passes; the integration test performs two real R fits.

- [ ] **Step 6: Commit the process-boundary slice**

```powershell
git add scripts/run_analysis.R lmplot/bridge.py tests/test_mvp_runner.R tests/python/test_bridge.py tests/python/test_bridge_integration.py pyproject.toml uv.lock requirements.lock
git commit -m "feat: connect Python to the R engine"
```

---

### Task 4: Build Plotly Presentation Helpers

**Files:**
- Create: `lmplot/plots.py`
- Create: `tests/python/test_plots.py`

**Interfaces:**
- Consumes: `AnalysisResult` and the enriched pandas `DataFrame`.
- Produces: `build_main_figure(result, enriched)` and
  `build_diagnostic_figures(result)`.

- [ ] **Step 1: Write failing figure-shape tests**

Build fixtures with validated `AnalysisResult.model_validate()` documents.

```python
def test_lm_figure_has_observations_and_sorted_fit_line(lm_result, lm_frame):
    figure = build_main_figure(lm_result, lm_frame)
    assert [trace.mode for trace in figure.data] == ["markers", "lines"]
    assert list(figure.data[1].x) == sorted(figure.data[1].x)
    assert figure.layout.xaxis.title.text == "X"


def test_glm_figure_has_points_and_one_surface(binomial_result, glm_frame):
    figure = build_main_figure(binomial_result, glm_frame)
    assert any(trace.type == "scatter3d" for trace in figure.data)
    assert sum(trace.type == "surface" for trace in figure.data) == 1


def test_diagnostics_are_two_named_figures(lm_result):
    figures = build_diagnostic_figures(lm_result)
    assert tuple(figures) == ("Residuals vs fitted", "Normal Q-Q")
    assert all(len(figure.data) == 1 for figure in figures.values())
```

- [ ] **Step 2: Run the focused tests and confirm the missing-module failure**

Run:

```powershell
py -3.12 -m uv run pytest tests/python/test_plots.py -q
```

Expected: collection fails with `ModuleNotFoundError: lmplot.plots`.

- [ ] **Step 3: Implement the 2D and 3D main figures**

`build_main_figure()` must reject missing `X`, `Z`, `.fitted`, or model-required
`Y` columns with `ValueError("Enriched data is missing: ...")`.

For `line_2d`, add an observation `go.Scatter(mode="markers")`, then add a
`go.Scatter(mode="lines")` from the result prediction points sorted by `x`.

For `surface_3d`, add one `go.Scatter3d(mode="markers")`. Reconstruct a regular
surface by sorting the distinct prediction `x` and `y` values and placing each
`fitted` value at `[y_index, x_index]`; add exactly one `go.Surface`.

Use result labels, a white template, responsive margins, and no Python-side
statistical transformation.

- [ ] **Step 4: Implement the two diagnostic figures**

Create one `go.Scatter(mode="markers")` for each payload. Add a horizontal zero
reference to residuals-versus-fitted and a 45-degree reference to QQ using the
finite joint range. Use only the R-returned points.

- [ ] **Step 5: Run plot and bridge tests**

Run:

```powershell
py -3.12 -m uv run pytest tests/python/test_plots.py tests/python/test_bridge.py -q
```

Expected: all tests pass.

- [ ] **Step 6: Commit the presentation slice**

```powershell
git add lmplot/plots.py tests/python/test_plots.py
git commit -m "feat: render validated R results with Plotly"
```

---

### Task 5: Build the Streamlit MVP

**Files:**
- Create: `streamlit_app.py`
- Create: `lmplot/ui.py`
- Create: `.streamlit/config.toml`
- Create: `tests/python/test_ui.py`
- Create: `tests/python/test_streamlit_smoke.py`

**Interfaces:**
- Consumes: `MVP_MODELS`, `AnalysisRequest`, `SimulationParameters`,
  `run_analysis()`, `build_main_figure()`, and
  `build_diagnostic_figures()`.
- Produces: `make_request(...)`, `render_result(BridgeResult)`, and `main()`.

- [ ] **Step 1: Write failing request-builder and Streamlit smoke tests**

```python
# tests/python/test_ui.py
from lmplot.ui import make_request


def test_ui_request_builder_omits_simulation_for_real_data():
    request = make_request(
        model_id="lm_2d",
        data_source="real",
        n=200,
        seed=123,
        beta0=2.0,
        beta1=0.5,
        beta2=-0.25,
        sigma=1.0,
    )
    assert request.simulation is None


def test_ui_request_builder_keeps_fixed_model_link_implicit():
    request = make_request(
        model_id="glm_poisson",
        data_source="simulation",
        n=80,
        seed=12,
        beta0=2.0,
        beta1=0.5,
        beta2=-0.25,
        sigma=1.0,
    )
    assert "link" not in request.model_dump()
```

```python
# tests/python/test_streamlit_smoke.py
from pathlib import Path

from streamlit.testing.v1 import AppTest


def test_streamlit_starts_without_running_r():
    app = AppTest.from_file(Path("streamlit_app.py")).run(timeout=15)
    assert not app.exception
    assert app.title[0].value == "LM Plot Explorer"
    assert app.button[0].label == "Fit model"
    assert "R statistical engine" in app.markdown[0].value
```

- [ ] **Step 2: Run the UI tests and confirm the missing-module failure**

Run:

```powershell
py -3.12 -m uv run pytest tests/python/test_ui.py tests/python/test_streamlit_smoke.py -q
```

Expected: failure because `lmplot.ui` and `streamlit_app.py` are absent.

- [ ] **Step 3: Implement request construction and form controls**

`make_request()` returns a real `AnalysisRequest`; it never returns a dict.
For real mode it sets `simulation=None`. For simulation it instantiates
`SimulationParameters` with the seven explicit values.

In `main()`:

```python
st.set_page_config(
    page_title="LM Plot Explorer",
    page_icon="📈",
    layout="wide",
)
st.title("LM Plot Explorer")
st.markdown(
    "**ELI5:** Streamlit provides the controls and charts; "
    "the R statistical engine performs every model fit."
)
```

Use one `st.form("analysis")`. Include a model selectbox from `MVP_MODELS`, a
simulation/real radio, and model-relevant bounded controls. Show `beta2` only
for GLMs and `sigma` only for `lm_2d`. Submit through
`st.form_submit_button("Fit model", type="primary")`.

No control change may call `run_analysis()`.

- [ ] **Step 4: Implement result, diagnostics, provenance, and export**

On submit, show `st.spinner("R is fitting the model…")`, call the bridge once,
and retain the last successful `BridgeResult` in
`st.session_state["analysis_result"]`. Map `BridgeError` to a concise
`st.error()` without a traceback.

Render:

- the main Plotly chart at container width;
- four model-appropriate `st.metric()` values;
- a coefficient dataframe;
- two diagnostic Plotly figures in columns;
- the first 100 enriched rows;
- provenance links and text for real mode;
- `st.download_button()` with `result.csv_bytes`,
  `file_name=f"{model_id}-enriched.csv"`, and `mime="text/csv"`;
- the visible caption `Statistical results computed by R 4.6.0.`

Do not call `st.cache_data` around model fitting. Static manifest and CSV reads
may be cached only inside a function that never receives user-controlled paths.

- [ ] **Step 5: Add public-safe Streamlit configuration**

Create `.streamlit/config.toml`:

```toml
[server]
headless = true
address = "0.0.0.0"
maxUploadSize = 1
enableXsrfProtection = true
enableCORS = true

[browser]
gatherUsageStats = false

[client]
showErrorDetails = false
toolbarMode = "minimal"
```

- [ ] **Step 6: Run the complete Python unit suite**

Run:

```powershell
py -3.12 -m uv run pytest tests/python -m "not integration and not container" -q
```

Expected: all unit and Streamlit smoke tests pass without invoking R.

- [ ] **Step 7: Commit the working dashboard slice**

```powershell
git add streamlit_app.py lmplot/ui.py .streamlit/config.toml tests/python/test_ui.py tests/python/test_streamlit_smoke.py
git commit -m "feat: add Streamlit teaching dashboard"
```

---

### Task 6: Preserve the Shiny Application Under `legacy/`

**Files:**
- Move: `app.R` to `legacy/app.R`
- Move: `www/style.css` to `legacy/www/style.css`
- Move: `run.bat` to `legacy/run.bat`
- Modify: `tests/test_app.R:108-194`
- Modify: `tests/test_server.R:1`
- Modify: `tests/test_release.R:10-72`
- Test: `tests/test_app_structure.R`
- Test: existing Shiny and R model suites

**Interfaces:**
- Consumes: the existing root `R/`, `data/`, `.Rprofile`, and `renv.lock`.
- Produces: a runnable `shiny::runApp("legacy")` parity reference without
  changing the new Streamlit entry point.

- [ ] **Step 1: Add failing legacy-location expectations**

Change the release test to require:

```r
expect_true(file.exists(file.path(release_root, "legacy", "app.R")))
expect_true(file.exists(file.path(release_root, "legacy", "www", "style.css")))
expect_match(
  read_release_file(file.path("legacy", "run.bat")),
  "shiny::runApp('legacy', launch.browser=TRUE)",
  fixed = TRUE
)
expect_false(file.exists(file.path(release_root, "app.R")))
```

Change the server test source to:

```r
source(file.path("..", "legacy", "app.R"), local = TRUE)
```

Change `AppDriver$new("..", ...)` to:

```r
shinytest2::AppDriver$new(
  file.path("..", "legacy"),
  name = "legacy-beta-smoke",
  seed = 123,
  load_timeout = 1e5,
  timeout = 1e5
)
```

- [ ] **Step 2: Run the focused legacy tests and confirm they fail**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_release.R', reporter='summary'); testthat::test_file('tests/test_server.R', reporter='summary')"
```

Expected: failure because `legacy/app.R` and `legacy/run.bat` do not exist.

- [ ] **Step 3: Move the Shiny entry point and static assets**

Run:

```powershell
New-Item -ItemType Directory -Path legacy
git mv app.R legacy/app.R
git mv www legacy/www
git mv run.bat legacy/run.bat
```

Keep the existing `app_root` detection in `legacy/app.R`; when Shiny changes
the working directory to `legacy/`, it resolves the shared root as `..`.

Update `legacy/run.bat` so it `pushd "%~dp0.."`, restores root `renv`, and
launches:

```bat
"%RSCRIPT%" -e "if (!requireNamespace('renv', quietly=TRUE)) install.packages('renv', repos='https://cloud.r-project.org'); renv::restore(prompt=FALSE); shiny::runApp('legacy', launch.browser=TRUE)"
```

- [ ] **Step 4: Run legacy, engine, and source-provenance tests**

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_release.R', reporter='summary'); testthat::test_file('tests/test_server.R', reporter='summary'); testthat::test_file('tests/test_model.R', reporter='summary'); testthat::test_file('tests/test_example_sources.R', reporter='summary')"
```

Expected: all focused tests pass. Run the existing browser smoke test when
Chrome is available; otherwise its existing environment guard must skip it
explicitly rather than silently pass.

- [ ] **Step 5: Commit the legacy-preservation slice**

```powershell
git add legacy tests/test_app.R tests/test_server.R tests/test_release.R
git commit -m "refactor: preserve Shiny app as legacy reference"
```

---

### Task 7: Package One Non-Root Docker Image and Render Blueprint

**Files:**
- Create: `Dockerfile`
- Create: `.dockerignore`
- Create: `render.yaml`
- Create: `renv-mvp.lock`
- Create: `scripts/container_smoke.py`
- Create: `tests/python/test_container_files.py`

**Interfaces:**
- Consumes: `streamlit_app.py`, `requirements.lock`, `renv-mvp.lock`,
  `scripts/run_analysis.R`, and the three data examples.
- Produces: image `lmplot-mvp:local`, health endpoint
  `/_stcore/health`, service name `lmplot-mvp-ktubi970`, and public URL
  `https://lmplot-mvp-ktubi970.onrender.com`.

- [ ] **Step 1: Write failing packaging-policy tests**

```python
def test_dockerfile_pins_r_and_runs_non_root():
    dockerfile = Path("Dockerfile").read_text(encoding="utf-8")
    assert dockerfile.startswith("FROM rocker/r-ver:4.6.0")
    assert "USER lmplot" in dockerfile
    assert "requirements.lock" in dockerfile
    assert "renv::restore(lockfile = 'renv-mvp.lock'" in dockerfile
    assert "_stcore/health" in dockerfile


def test_render_blueprint_uses_the_docker_health_check():
    blueprint = yaml.safe_load(Path("render.yaml").read_text(encoding="utf-8"))
    service = blueprint["services"][0]
    assert service["name"] == "lmplot-mvp-ktubi970"
    assert service["runtime"] == "docker"
    assert service["plan"] == "free"
    assert service["healthCheckPath"] == "/_stcore/health"
```

Add `PyYAML==6.0.2` to the development dependency group and regenerate both
Python lock outputs.

- [ ] **Step 2: Run packaging tests and confirm files are absent**

Run:

```powershell
py -3.12 -m uv run pytest tests/python/test_container_files.py -q
```

Expected: failures for missing `Dockerfile` and `render.yaml`.

- [ ] **Step 3: Add the production Dockerfile**

Start with:

```dockerfile
FROM rocker/r-ver:4.6.0

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    R_LIBS_USER=/opt/renv-mvp \
    PATH=/opt/venv/bin:$PATH \
    HOME=/tmp/lmplot
```

Install only `python3`, `python3-venv`, `python3-pip`, and `curl`. Remove
`/var/lib/apt/lists/*` in the same layer.

Generate a production-only R lock from the restored project:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "renv::snapshot(lockfile='renv-mvp.lock', packages=c('renv','jsonlite'), type='explicit', prompt=FALSE)"
```

Verify the lock declares R `4.6.0`, `renv` `1.2.3`, and `jsonlite` `2.0.0`,
and contains no Shiny, Plotly, or test packages.

Copy `renv.lock`, `renv-mvp.lock`, and `renv/activate.R` before application
source files. Use the vendored activation script to bootstrap locked `renv`,
then restore the production library:

```dockerfile
RUN R -s -e "source('renv/activate.R'); renv::restore(lockfile = 'renv-mvp.lock', library = '/opt/renv-mvp', prompt = FALSE)"
```

Do not copy `.Rprofile` into the image. Create `/opt/venv`, install
`requirements.lock`, then copy only the application, required R modules,
runner, manifest, and the three required real-data directories.

Create user `lmplot` with UID 10001, make only `/tmp/lmplot` writable, switch
with `USER lmplot`, and include:

```dockerfile
EXPOSE 8501
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl --fail http://127.0.0.1:${PORT:-8501}/_stcore/health || exit 1
CMD ["sh", "-c", "streamlit run streamlit_app.py --server.address=0.0.0.0 --server.port=${PORT:-8501}"]
```

- [ ] **Step 4: Add Docker context exclusions and Render Blueprint**

`.dockerignore` must exclude `.git`, `.Rproj.user`, `.worktrees`,
`.superpowers`, `.venv`, `__pycache__`, `.pytest_cache`, `artifacts`,
`legacy`, tests, raw source snapshots not used at runtime, and generated
screenshots. It must not exclude the three model-ready CSV files or manifest.

Create:

```yaml
services:
  - type: web
    name: lmplot-mvp-ktubi970
    runtime: docker
    plan: free
    dockerfilePath: ./Dockerfile
    dockerContext: .
    healthCheckPath: /_stcore/health
    autoDeploy: true
    envVars:
      - key: LMPLOT_RSCRIPT
        value: /usr/local/bin/Rscript
      - key: PYTHONUNBUFFERED
        value: "1"
```

- [ ] **Step 5: Add a cross-platform container smoke script**

`scripts/container_smoke.py` must expose:

```text
--image IMAGE       default: lmplot-mvp:local
--skip-build        use the supplied image without building
```

Its execution must:

1. build the selected image unless `--skip-build` is set;
2. start it as `lmplot-mvp-smoke` on host port 8765 with `--rm`;
3. poll `http://127.0.0.1:8765/_stcore/health` for at most 90 seconds;
4. inspect `.Config.User` and assert it is neither `0` nor empty;
5. stop the container in `finally`;
6. return nonzero on build, health, or non-root failure.

Use `subprocess.run([...], shell=False, check=True)` and
`urllib.request.urlopen()`; do not depend on Bash.

- [ ] **Step 6: Build and smoke-test the production image**

Run:

```powershell
py -3.12 -m uv run pytest tests/python/test_container_files.py -q
py -3.12 scripts/container_smoke.py
```

Expected: policy tests pass, the image builds, the health endpoint returns
`ok`, and the process UID is nonzero.

- [ ] **Step 7: Commit the deployable-container slice**

Stage only the files owned by this task; leave `.gitignore` untouched so the
user's pre-existing `.positai` change remains unstaged.

```powershell
git add Dockerfile .dockerignore render.yaml renv-mvp.lock scripts/container_smoke.py tests/python/test_container_files.py pyproject.toml uv.lock requirements.lock
git commit -m "build: package public Streamlit R service"
```

---

### Task 8: Add GitHub Actions Quality Gates

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `tests/python/test_ci_workflow.py`

**Interfaces:**
- Consumes: all R, Python, integration, and container commands established in
  Tasks 1–7.
- Produces: required jobs `r-tests`, `python-tests`, `integration`, and
  `container`.

- [ ] **Step 1: Write a failing workflow-structure test**

```python
def test_ci_has_all_release_gates():
    workflow = yaml.safe_load(Path(".github/workflows/ci.yml").read_text())
    jobs = workflow["jobs"]
    assert set(jobs) == {"r-tests", "python-tests", "integration", "container"}
    assert jobs["container"]["needs"] == ["r-tests", "python-tests", "integration"]
    assert jobs["integration"]["env"]["LMPLOT_RSCRIPT"] == "Rscript"
```

Normalize YAML's `on` key in the test if PyYAML loads it as a boolean under its
legacy resolver.

- [ ] **Step 2: Run the test and confirm the workflow is missing**

Run:

```powershell
py -3.12 -m uv run pytest tests/python/test_ci_workflow.py -q
```

Expected: `FileNotFoundError` for `.github/workflows/ci.yml`.

- [ ] **Step 3: Implement the four-job workflow**

Trigger on pull requests and pushes to `master`.

`r-tests` uses `r-lib/actions/setup-r@v2` with R `4.6.0`,
`r-lib/actions/setup-renv@v2`, then:

Install Chrome through `browser-actions/setup-chrome@v1` so the retained Shiny
browser smoke test runs, then execute:

```yaml
- run: Rscript -e "testthat::test_dir('tests', reporter='summary')"
```

`python-tests` uses `actions/setup-python@v5` with `3.12`, installs
`uv==0.8.4`, runs `uv sync --frozen`, then:

```yaml
- run: uv run pytest tests/python -m "not integration and not container" -q
```

`integration` installs both R 4.6.0 and Python 3.12, restores both locks, sets
`LMPLOT_RSCRIPT=Rscript`, and runs:

```yaml
- run: uv run pytest tests/python/test_bridge_integration.py -m integration -q
```

`container` needs all three earlier jobs and runs:

```yaml
- run: docker build --tag lmplot-mvp:${{ github.sha }} .
- run: python scripts/container_smoke.py --image lmplot-mvp:${{ github.sha }} --skip-build
```

Grant only `contents: read`. Use only the action major versions named here.

- [ ] **Step 4: Run workflow and local suites**

Run:

```powershell
py -3.12 -m uv run pytest tests/python/test_ci_workflow.py -q
py -3.12 -m uv run pytest tests/python -m "not container" -q
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_mvp_analysis.R', reporter='summary'); testthat::test_file('tests/test_mvp_runner.R', reporter='summary')"
```

Expected: workflow policy and local suites pass.

- [ ] **Step 5: Commit the CI slice**

```powershell
git add .github/workflows/ci.yml tests/python/test_ci_workflow.py
git commit -m "ci: verify Streamlit and R delivery"
```

---

### Task 9: Publish the README, License, Screenshot, and Release Assertions

**Files:**
- Rewrite: `README.md`
- Create: `LICENSE`
- Create: `docs/dashboard.png`
- Modify: `tests/test_release.R:10-105`
- Create: `tests/python/test_repository_docs.py`

**Interfaces:**
- Consumes: the public service name, supported registry, Docker commands, test
  commands, provenance metadata, and the Codex workflow requirement.
- Produces: public onboarding that starts with ELI5, an MIT code license, and
  machine-checked release claims.

- [ ] **Step 1: Write failing README and license assertions**

```python
from pathlib import Path


def test_readme_starts_with_eli5_before_technical_details():
    readme = Path("README.md").read_text(encoding="utf-8")
    assert readme.index("## ELI5") < readme.index("## Technical architecture")
    assert "Streamlit is the shop window" in readme
    assert "R is the statistician" in readme


def test_readme_prominently_requires_the_requested_codex_workflow():
    readme = Path("README.md").read_text(encoding="utf-8")
    assert "## Codex + Sol (Extra High)" in readme
    assert "Codex with Sol in Extra High reasoning mode" in readme
    assert "does not replace scientific review" in readme


def test_public_release_links_and_scope_are_exact():
    readme = Path("README.md").read_text(encoding="utf-8")
    assert "https://lmplot-mvp-ktubi970.onrender.com" in readme
    assert all(model in readme for model in ("lm_2d", "glm_binomial", "glm_poisson"))
    assert "docs/dashboard.png" in readme
    assert Path("LICENSE").read_text().startswith("MIT License\n")
```

Update R release assertions to expect application version `1.0.0`, R `4.6.0`,
the three-model table, Docker quick start, the separate legacy launcher, and
the distinction between the MIT code license and upstream data licenses.

- [ ] **Step 2: Run release-document tests and confirm they fail**

Run:

```powershell
py -3.12 -m uv run pytest tests/python/test_repository_docs.py -q
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_release.R', reporter='summary')"
```

Expected: failure against the old beta README and missing `LICENSE`.

- [ ] **Step 3: Rewrite the README in the approved order**

Use these exact top-level sections:

```markdown
# LM Plot Explorer
## ELI5
## Live dashboard
## Codex + Sol (Extra High)
## MVP models
## Quick start with Docker
## Native development
## Technical architecture
## Testing and reproducibility
## Scientific data and licenses
## Security boundary
## Legacy Shiny application
## Contributing
## License
```

Under `## Codex + Sol (Extra High)`, state:

> This repository is designed to be understood, verified, and extended with
> Codex with Sol in Extra High reasoning mode. Ask Codex to inspect the
> Python–R contract before editing, keep changes scoped, run both test suites,
> and review statistical code and scientific claims. Extra High reasoning
> supports careful engineering; it does not replace scientific review.

Document:

- `docker build -t lmplot-mvp .`;
- `docker run --rm -p 8501:8501 lmplot-mvp`;
- `uv sync --frozen` and `renv::restore()`;
- Python, R, integration, and container test commands;
- the subprocess JSON/CSV flow;
- the exact three models and examples;
- the no-upload/no-formula/no-code boundary;
- data-specific licenses and `data/real/NOTICE.md`;
- `shiny::runApp("legacy")` as parity-only.

- [ ] **Step 4: Add the MIT code license**

Create the standard MIT License text with:

```text
Copyright (c) 2026 LM Plot Explorer contributors
```

The README must explicitly say the MIT license covers application code and does
not override the licenses attached to bundled data and source snapshots.

- [ ] **Step 5: Capture the dashboard screenshot**

Start the local container:

```powershell
docker run --rm --name lmplot-docs -p 8501:8501 lmplot-mvp:local
```

In another terminal:

```powershell
py -3.12 -m uv run playwright install chromium
py -3.12 -m uv run playwright screenshot --device="Desktop Chrome" --wait-for-timeout=5000 http://127.0.0.1:8501 docs/dashboard.png
```

Verify the image is a PNG at least 1,200 pixels wide, at least 700 pixels high,
and larger than 50 KB. Stop the documentation container.

- [ ] **Step 6: Run documentation, release, and link checks**

Run:

```powershell
py -3.12 -m uv run pytest tests/python/test_repository_docs.py -q
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_release.R', reporter='summary')"
git diff --check
```

Expected: all documentation assertions pass and the diff has no whitespace
errors.

- [ ] **Step 7: Commit the public documentation slice**

```powershell
git add README.md LICENSE docs/dashboard.png tests/test_release.R tests/python/test_repository_docs.py
git commit -m "docs: publish Streamlit R MVP guide"
```

---

### Task 10: Perform Full Verification, Publish GitHub, and Deploy Render

**Files:**
- Verify only: all changed files
- Update only if deployment evidence differs: `README.md`

**Interfaces:**
- Consumes: every prior task, the existing
  `https://github.com/ktubi970/lmplot.git` remote, and Render authentication.
- Produces: a public GitHub repository, green required checks, and a healthy
  public service at `https://lmplot-mvp-ktubi970.onrender.com`.

- [ ] **Step 1: Run the complete local verification matrix**

Run:

```powershell
py -3.12 -m uv run pytest tests/python -m "not container" -q
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_dir('tests', reporter='summary')"
py -3.12 scripts/container_smoke.py
git diff --check
git status --short
```

Expected: Python and R suites pass, the container is healthy and non-root, no
whitespace errors exist, and only the user's unrelated pre-existing change may
remain unstaged.

- [ ] **Step 2: Verify repository visibility before changing it**

Run:

```powershell
gh repo view ktubi970/lmplot --json nameWithOwner,visibility,url,defaultBranchRef
```

Expected: `nameWithOwner` is `ktubi970/lmplot`. If visibility is `PRIVATE`, the
approved public-repository requirement authorizes this exact target change:

```powershell
gh repo edit ktubi970/lmplot --visibility public --accept-visibility-change-consequences
gh repo view ktubi970/lmplot --json visibility,url
```

Expected final visibility: `PUBLIC`. Do not change any other repository.

- [ ] **Step 3: Push, review, and merge the implementation**

Use the repository's `codex/` branch prefix and an exact delivery summary:

```powershell
git push -u origin codex/streamlit-r-mvp
gh pr create --draft --title "feat: publish Streamlit R MVP" --body "Adds the three-model Streamlit MVP with an Rscript boundary, enriched CSV export, retained legacy Shiny app, locked Docker image, Render Blueprint, and R/Python/integration/container checks. Render free tier may cold-start."
gh pr checks --watch
gh pr ready
gh pr merge --squash --delete-branch
gh pr view --json state,mergeCommit,url
```

Expected: all four checks pass and the PR state is `MERGED` before deployment.

- [ ] **Step 4: Deploy the reviewed revision through Render Blueprint**

In Render, create a Blueprint from
`https://github.com/ktubi970/lmplot`, select `render.yaml`, and deploy service
`lmplot-mvp-ktubi970` on the free plan. Do not add secrets; the service has no
runtime credentials.

Wait until Render reports `Live`, then verify:

```powershell
curl.exe --fail --retry 12 --retry-delay 10 https://lmplot-mvp-ktubi970.onrender.com/_stcore/health
```

Expected body: `ok`.

- [ ] **Step 5: Exercise one public end-to-end analysis**

Open the public URL, select `Simple linear model`, choose `Simulation`, set
sample size `80` and seed `12`, click `Fit model`, and verify:

- a two-trace Plotly chart appears;
- coefficients and four LM metrics appear;
- both diagnostic charts appear;
- the caption says R 4.6.0 computed the results;
- the downloaded file is named `lm_2d-enriched.csv`;
- it contains 80 rows and columns `X`, `Z`, `.fitted`, `.residual`;
- browser console and network logs contain no errors or local paths.

- [ ] **Step 6: Re-run release evidence against the public service**

The Render service name must produce the documented URL. If that exact name is
unavailable, stop before creating a differently named public service.

Run:

```powershell
py -3.12 -m uv run pytest tests/python/test_repository_docs.py -q
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_release.R', reporter='summary')"
curl.exe --fail https://lmplot-mvp-ktubi970.onrender.com/_stcore/health
git status --short
```

Expected: both release suites pass, health returns `ok`, and no delivery file changed after merge.

- [ ] **Step 7: Record final delivery evidence**

Post one final evidence comment on the merged PR containing:

- final commit SHA;
- GitHub visibility output;
- four green Actions job links;
- Render deployment revision and public URL;
- health response;
- public analysis/export evidence;
- the retained unstaged `.gitignore` change if it still belongs to the user.

Do not declare the MVP complete until all acceptance evidence is current.

---

## Plan Self-Review Checklist

- Every approved model, data source, chart, diagnostic, provenance block, and
  enriched export is covered by Tasks 1–5.
- Public-safety requirements are enforced independently in Python, R, the
  process boundary, Streamlit, and the container.
- Legacy Shiny parity is preserved and tested in Task 6.
- Dependency locks, non-root Docker execution, CI, Render, public GitHub
  visibility, README ordering, Codex guidance, code/data license separation,
  screenshot, and public end-to-end evidence each have an explicit task.
- Function and field names are consistent across the Python schemas, R result,
  bridge, Plotly helpers, and UI.
- No implementation step depends on an undefined interface from a later task.
