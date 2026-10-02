# LM Plot Explorer 0.10.0-beta.1

An English educational Shiny application for anonymous exploration of linear,
generalized linear, and Gaussian random-intercept models. The public workflow
uses bundled scientific examples and deterministic simulation. This is a beta
release candidate; publication remains subject to the gates in
[CHANGELOG.md](CHANGELOG.md).

Selecting a model, source, link or simulation setting automatically updates the
analysis. Rapid changes are coalesced, and the last successful result remains
available if a setting fails. Plots are shown first; explanations, coefficient
tables, chart data and provenance can be expanded when needed.

## Run locally

Requires R 4.6.0. From the project root, run the explicit network-enabled
bootstrap once, then start Shiny on loopback in a new R process:

```sh
Rscript --vanilla scripts/bootstrap.R
Rscript -e "shiny::runApp('.', host = '127.0.0.1', port = 3838)"
```

Open [the local application](http://127.0.0.1:3838/). Starting R in the project
root loads `.Rprofile` and activates only an already-restored project library.
If its locked `renv` is absent, normal Shiny startup stops and the CLI returns
a dependency error; neither downloads packages nor creates a replacement
library. The separate bootstrap command restores `renv.lock` and requires
package-repository access. Docker build and CI restoration explicitly opt in to
that step; application runtime does not. On Windows, bootstrap first. Then
`run.bat` changes to the project directory, uses R 4.6.0 with `--vanilla` to
bypass startup-profile processing, checks the standard Windows
project library against the lock, and opens a local Shiny session on an
automatically selected port. Missing or inconsistent packages stop the launcher
with an explicit-restore instruction; it never installs or restores on launch.
The launcher expects `renv/library/windows/R-4.6/x86_64-w64-mingw32`; custom library
layouts can set `RENV_PATHS_LIBRARY` for the bootstrap and runtime commands.

## Docker and public deployment

The image targets Linux/AMD64 and pins
`rocker/shiny:4.6.0@sha256:95a0d826be0bfc9bd41300385b35cf0ec074fc6b82cfaa92fddd7c6f6f2fd0dd`.
Build and start the isolated application service with:

```sh
docker compose config --quiet
docker compose up --build -d
docker compose ps
docker compose down
```

Compose exposes port 3838 **only inside an internal Docker network** and does not publish
a host port. Running `docker compose up` alone does not make the application
available at localhost:3838. The image's healthcheck probes its own root URL at
`http://127.0.0.1:3838/`; a healthy container confirms internal application
startup, not public reachability.

A deployment-owned external ingress or reverse proxy, maintained outside this
repository, must join the application's internal network and publish its own
listener. Determine that network's actual project-prefixed name with
`docker compose config` or `docker network ls`. Keep the app attached only to
its internal network. The deployment owner supplies TLS, proxy configuration,
WebSocket forwarding, timeouts, access controls where needed, rate limits,
monitoring, and a staging smoke through the real ingress URL. No proxy, TLS,
authentication, or multi-tenant isolation is provided here.

Shiny runs as the non-root `shiny` user. Compose makes the root filesystem
read-only, drops all capabilities, prevents privilege escalation, and limits
CPU, memory, and processes. Writable tmpfs mounts are restricted to `/tmp`,
`/var/log/shiny-server`, `/var/lib/shiny-server`,
`/var/run/shiny-server`, and `/var/shiny-server/sockets`. CI additionally
runs the image with `--network none` and these write/resource constraints,
then requires both a healthy status and actual LM Plot Explorer root content.
That smoke does not verify ingress or interactive WebSocket sessions.

For rollback, keep the previously reviewed image digest and its matching
deployment configuration, switch the deployment-owned image reference back to
that digest, recreate the service, and repeat the ingress/WebSocket smoke.
Preserve release evidence before rollout; this repository does not automate
publication or rollback.

## Security and beta scope

Expert mode evaluates arbitrary local R code. It is omitted from the public UI
unless the process environment is exactly `LMPLOT_TRUSTED_LOCAL=1`, and request
validation enforces the same trusted boundary. Use that opt-in only for trusted local use.
It is not a sandbox: never set it for a public service or an untrusted user.
Public Compose and Docker CI leave it unset.

Public inputs are limited to bundled examples and bounded deterministic
simulation. Uploaded datasets, arbitrary formulas, hosted code execution,
random slopes, and generalized mixed families are outside this beta.
User-facing errors are sanitized; server and CLI stderr diagnostics can contain
technical details and should remain private to the operator. Failed analyses
retain the last valid result and allow a later request to recover.

## Headless CLI

After the explicit restore, run from the project root:

```sh
Rscript scripts/run_analysis.R request.json output.json
```

The adapter requires exactly two paths. The output directory must already
exist; successful JSON goes to the second path, stdout stays empty, and
diagnostics go to stderr. Unknown request fields and incompatible model/link
pairs are rejected.

A valid simulation `request.json` uses `lmplot-analysis-request/1.0`:

```json
{
  "schema_version": "lmplot-analysis-request/1.0",
  "data_source": "simulation",
  "model_type": "lm_2d",
  "link": "identity",
  "simulation": {"n": 30, "seed": 11}
}
```

The accepted bundled-data alternative is:

```json
{
  "schema_version": "lmplot-analysis-request/1.0",
  "data_source": "real",
  "model_type": "lm_2d",
  "example_id": "adelie_flipper_mass"
}
```

A real-data request must omit `simulation` and `expert`, even when null;
a simulation request must omit `example_id`. Omitted simulation parameters
receive validated defaults. Sample size is 10–2000 and prediction-grid length
(`grid_length_out`) is 2–200. The example must belong to the selected model.

Success uses `lmplot-analysis-result/1.0`. This abbreviated JSON excerpt shows
the identity fields; the actual result also includes labels, row-oriented data,
fitted values, response residuals, metrics, coefficients, diagnostics, warnings,
a prediction grid, and the validated `model-brain/1.0` object:

```json
{
  "schema_version": "lmplot-analysis-result/1.0",
  "model": {"model_type": "lm_2d", "link": "identity"},
  "source": {"data_source": "simulation", "example_id": null}
}
```

Errors use the complete `lmplot-error/1.0` envelope, for example:

```json
{
  "schema_version": "lmplot-error/1.0",
  "error": {
    "code": "invalid_request",
    "message": "The analysis request is invalid."
  }
}
```

| Exit code | Meaning |
|---|---|
| 0 | Analysis completed and result JSON was written. |
| 2 | Invalid usage/request, unsupported schema/fields, or untrusted Expert request. |
| 3 | Analysis or required-dependency failure. |
| 4 | Serialization or output-write failure. |

An error envelope is written when the second path is identifiable and usable.
An unusable output path results in exit 4 and stderr diagnostics; no parent
directory is created. JSON numeric values that are unavailable or non-finite
are `null`, never `NaN` or `Inf`. Arrays retain their positions, including
one-item arrays. See [CLI contract tests](tests/test_cli_contract.R) for executable
success and failure examples.

## Supported models and scientific interpretation

The beta supports exactly 15 model/link combinations.

| Model ID | UI label | Fit | Predictors | Link |
|---|---|---|---|---|
| `lm_2d` | Simple LM (2D) | `lm` | `X` | `identity` |
| `lm_3d` | Multiple LM (3D) | `lm` | `X + Y` | `identity` |
| `glm_binomial_2d` | Simple Binomial GLM (2D) | `glm(binomial)` | `X` | `logit` |
| `glm_binomial_2d` | Simple Binomial GLM (2D) | `glm(binomial)` | `X` | `probit` |
| `glm_binomial_2d` | Simple Binomial GLM (2D) | `glm(binomial)` | `X` | `cloglog` |
| `glm_binomial` | Binomial GLM | `glm(binomial)` | `X + Y` | `logit` |
| `glm_binomial` | Binomial GLM | `glm(binomial)` | `X + Y` | `probit` |
| `glm_binomial` | Binomial GLM | `glm(binomial)` | `X + Y` | `cloglog` |
| `glm_poisson` | Poisson GLM | `glm(poisson)` | `X + Y` | `log` |
| `glm_poisson` | Poisson GLM | `glm(poisson)` | `X + Y` | `identity` |
| `glm_poisson` | Poisson GLM | `glm(poisson)` | `X + Y` | `sqrt` |
| `glm_gamma` | Gamma GLM | `glm(Gamma)` | `X + Y` | `inverse` |
| `glm_gamma` | Gamma GLM | `glm(Gamma)` | `X + Y` | `log` |
| `glm_gamma` | Gamma GLM | `glm(Gamma)` | `X + Y` | `identity` |
| `glmm` | Gaussian GLMM | `lmer` | `X + Y + (1 \| Group)` | `identity` |

Gaussian GLMM here means a Gaussian random-intercept model fitted by
`lme4::lmer`; unsupported mixed-model behavior never silently falls back to LM.
The fixed/random contributions, inverse-link predictions, observation selection,
and conditional versus population views are described by the Model Brain
contract. Selecting a different observation reuses the fitted model.

AIC and BIC are relative comparison values for compatible fits on the same
response and observations, not stand-alone quality scores. P-values express
conditional evidence under the fitted model and its assumptions; they do not
measure effect importance or prove model validity. Diagnostics are exploratory
and family-specific. Convergence flags and absence of warnings are not positive
evidence of scientific validity. GLMM coefficient confidence intervals and
p-values, and response intervals not implemented for GLMM, are explicitly
unavailable rather than fabricated.

Real-data charts and Model Brain summaries distinguish observed outcomes from
predicted means or probabilities. Known physical units are carried from example
metadata; unknown units remain unspecified. Guided interpretation is
deterministic educational text, not automated scientific endorsement.

## Scientific real-data examples

Each supported model has one bundled, reproducible teaching example. The
prepared CSV, provenance metadata, example-specific README, and static preview
are committed so normal app sessions remain fully offline. External provenance
links are opened only when a user chooses them; the app does not download data
at runtime.

| Example | Model family | Default link | Rows | Publication identifier | Dataset identifier | License |
|---|---|---:|---:|---|---|---|
| [Adélie penguin body mass](data/real/adelie_flipper_mass/README.md) | Linear model (2D) | `identity` | 151 | [10.1371/journal.pone.0090081](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0090081) | [10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f](https://doi.org/10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| [28-day concrete compressive strength](data/real/concrete_28d/README.md) | Linear model (3D) | `identity` | 425 | [10.1016/S0008-8846(98)00165-3](https://doi.org/10.1016/S0008-8846(98)00165-3) | [10.24432/C5PK67](https://doi.org/10.24432/C5PK67) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| [Adélie penguin sex from morphology](data/real/adelie_sex/README.md) | Binomial GLM | `logit` | 146 | [10.1371/journal.pone.0090081](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0090081) | [10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f](https://doi.org/10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| [Adélie penguin sex from bill length](data/real/adelie_sex_2d/README.md) | Binomial GLM (2D) | `logit` | 146 | [10.1371/journal.pone.0090081](https://doi.org/10.1371/journal.pone.0090081) | [10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f](https://doi.org/10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| [Abalone shell-ring count](data/real/abalone_rings/README.md) | Poisson GLM | `log` | 4,177 | [10.1071/MF9880167](https://doi.org/10.1071/MF9880167) | [10.24432/C55C7W](https://doi.org/10.24432/C55C7W) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| [Positive forest-fire burned area](data/real/forest_fire_positive_area/README.md) | Gamma GLM | `log` | 270 | [hdl:1822/8039](https://hdl.handle.net/1822/8039) | [10.24432/C5D88D](https://doi.org/10.24432/C5D88D) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| [Inner London examination achievement](data/real/inner_london_exam/README.md) | Gaussian GLMM | `identity` | 4,059 | [10.1080/0305498930190401](https://doi.org/10.1080/0305498930190401) | [10.32614/CRAN.package.mlmRev](https://doi.org/10.32614/CRAN.package.mlmRev) | [GPL-2-or-later](https://www.r-project.org/Licenses/GPL-2) |

The source snapshots are already bundled. Rebuild the model-ready CSV files
and static plots offline with R 4.6.0:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" scripts/build_real_examples.R
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" scripts/export_real_example_plots.R
```

To refresh the reviewed source snapshots, run the fetch step separately while
online, then rebuild offline:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" scripts/fetch_real_examples.R
```

Restore the exact package set before reproducing artifacts with
`Rscript --vanilla scripts/bootstrap.R`. The fetch script verifies the recorded checksums; the build
scripts preserve source row order and enforce each example's declared schema,
exclusions, units, row count, and statistical domain.

Dataset licenses and attribution remain separate from the application's MIT
license; see [data/real/NOTICE.md](data/real/NOTICE.md). Provenance includes
recorded source checksums, exclusions, variable definitions, and units.

## Accessibility and verification

The UI supplies landmarks, a skip link, labeled controls, visible keyboard
focus, and status text. Overview, Diagnostics, and Model Brain charts include
text summaries and table/CSV alternatives; large tables identify previews and
offer all rows by download. Observation controls support keyboard navigation.
System/local fonts and application assets avoid remote font dependencies.

Automated tests cover keyboard interaction, chart alternatives, selected
contrast pairs, CLI contracts, scientific invariants, and failure recovery.
These checks do not establish WCAG 2.2 AA conformance. Manual screen-reader,
zoom/reflow, focus, and contrast reviews remain in the release checklist.

Run the complete suite with a real Chrome installation discoverable by chromote
(or set `CHROMOTE_CHROME` to its executable); missing browser/package dependencies
are failures, not grounds for skipping tests:

```sh
Rscript -e "testthat::test_dir('tests', reporter='summary')"
docker compose config --quiet
docker build -t lmplot:0.10.0-beta.1 .
git diff --check
```

[CI](.github/workflows/ci.yml) restores `renv.lock` on Windows and Ubuntu with
exact R 4.6.0, checks synchronization and required packages, reports installed
package build versions, and runs the full suite with real Chrome and no skips.
The Linux Docker job runs only after both R jobs pass. Hosted CI execution,
human scientific review, manual assistive-technology checks, and external
ingress/WebSocket staging are release gates, not implied by local tests.

## Architecture

`app.R` composes namespaced Configuration, Overview, Diagnostics, Model Brain,
and Data & provenance workflows. `R/mod_pipeline.R` validates analysis requests
and coordinates pure R services through `create_analysis_services()` and
`run_analysis_usecase()`. The CLI and Shiny use the same analysis boundary.

Named fit and diagnostic registries centralize the supported scientific
algorithms. The JSON contract and Plotly/Shiny rendering code adapt actual
external boundaries, while model, metric, and diagnostic functions exchange
ordinary R values. This keeps headless scientific tests independent of UI
state. Existing functions provide the needed boundaries; a new library or a
long file alone does not justify another abstraction. Agent conventions live
in [AGENTS.md](AGENTS.md).

## License

Application code is licensed under the [MIT License](LICENSE), copyright 2026
lmplot contributors. Bundled datasets retain their own licenses and notices.
