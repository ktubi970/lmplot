# Contributing to LM Plot Explorer

Thank you for your interest in contributing to **LM Plot Explorer**! This project is an open-source educational Shiny application designed for anonymous, reproducible exploration of linear models (LM), generalized linear models (GLM), and Gaussian random-intercept mixed models (GLMM).

Before submitting code, please review the architecture principles, environment requirements, testing guidelines, and pull request workflow outlined below.

---

## 1. Code of Conduct

All contributors and participants are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md). By contributing, you agree to promote a welcoming, inclusive, and harassment-free environment.

---

## 2. Prerequisites and Environment Setup

### Required Toolchain
- **R 4.6.0** (locked exact version)
- **Git**
- **Google Chrome** (required for browser-driven end-to-end tests via `chromote` / `shinytest2`)
- **Docker & Docker Compose** (for containerized deployment validation)

### Bootstrapping the Project Library
LM Plot Explorer relies on `renv` to pin exact dependency versions. Normal application runtime intentionally does **not** auto-restore or download packages. You must bootstrap dependencies explicitly once:

```bash
Rscript --vanilla scripts/bootstrap.R
```

On Windows with PowerShell:
```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" --vanilla scripts/bootstrap.R
```

### Running the Application Locally
After restoring dependencies, start the Shiny application on loopback:

```bash
Rscript -e "shiny::runApp('.', host = '127.0.0.1', port = 3838)"
```

Or on Windows, launch the provided batch script:
```cmd
run.bat
```

The app will be available at [http://127.0.0.1:3838](http://127.0.0.1:3838).

---

## 3. Architecture & Design Principles

LM Plot Explorer follows modular monolith principles detailed in [AGENTS.md](AGENTS.md):

1. **Strategy Pattern for Fitting and Diagnostics**:
   - `FIT_STRATEGIES` in `R/model_registry.R` dispatches LM, GLM, and GLMM fitting.
   - `DIAGNOSTIC_STRATEGIES` in `R/model_diagnostics.R` selects family-specific diagnostic routines.
   - Any new model family requires a named registry entry and behavioral tests demonstrating model/link validation without silent fallbacks.

2. **Dependency Injection at the Analysis Boundary**:
   - `create_analysis_services()` supplies collaborator functions to `run_analysis_usecase()` in `R/mod_pipeline.R`.
   - Calculations and services must be unit-testable without Shiny reactives or globals.

3. **Adapters at Real Boundaries**:
   - The headless CLI (`scripts/run_analysis.R`, `R/json_contract.R`) and Plotly/Shiny UI renderers adapt external data contracts.
   - Core model fitting, metric evaluation, and diagnostic calculations exchange pure R objects and must remain decoupled from UI or CLI JSON representations.

4. **Shiny Modules**:
   - Each distinct workflow (Configuration, Overview, Diagnostics, Model Brain, Data & provenance) lives in its own namespaced module.
   - Modules exchange validated reactives or result contracts, never private UI IDs of other modules.

5. **Security & Trusted Local Scope**:
   - Arbitrary R code evaluation (Expert mode) is strictly guarded behind `LMPLOT_TRUSTED_LOCAL=1`.
   - Never expose `LMPLOT_TRUSTED_LOCAL` in public deployments or untrusted environments.
   - All user-facing error messages must be sanitized; server diagnostics remain private to stderr.

---

## 4. Testing & Verification

Every pull request must pass the complete test suite with **zero failures, zero errors, and zero skipped tests**.

### Running Local Tests
Run all unit, integration, and browser tests:

```bash
Rscript -e "testthat::test_dir('tests', reporter = 'summary')"
```

Make sure Chrome is installed and discoverable by `chromote`, or set the `CHROMOTE_CHROME` environment variable pointing to the Chrome executable.

### Validating Docker & Compose Isolation
Verify the container configuration and build:

```bash
docker compose config --quiet
docker build -t lmplot:0.10.0-beta.1 .
```

### Checking Git Diffs & Line Endings
```bash
git diff --check
```

---

## 5. Development Workflow

1. **Fork and Branch**:
   - Fork the repository on GitHub.
   - Create a feature or fix branch from `master`:
     ```bash
     git checkout -b feature/my-improvement
     ```
2. **Follow Commit Conventions**:
   - Write clear, conventional commit messages:
     - `feat: ...` for new capabilities
     - `fix: ...` for bug fixes
     - `docs: ...` for documentation changes
     - `test: ...` for test additions or adjustments
     - `chore: ...` for maintenance
3. **Evidence Before Assertions**:
   - Always run the full test suite locally before pushing.
   - Include test output or verification evidence in your PR description.
4. **Submit a Pull Request**:
   - Fill out the PR template completely.
   - Ensure all automated GitHub Actions CI matrix checks (Windows and Ubuntu R 4.6.0, Docker health) pass.

---

## 6. Release Gates & Scientific Review

Releases are subject to formal release gates outlined in [CHANGELOG.md](CHANGELOG.md):
- CI pass across both OS targets and Docker egress-isolated health checks.
- Documented scientific copy review approving educational text, formulas, and statistical explanations.
- Manual accessibility audit (keyboard navigation, screen reader checks, zoom/reflow).
- Deployment-owned staging and WebSocket ingress validation.

---

Thank you for helping make LM Plot Explorer a reliable, accessible, and scientifically sound tool!
