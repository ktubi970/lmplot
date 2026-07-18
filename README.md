# LM Plot Explorer 0.9.0-beta.1

Interactive local exploration of linear, generalized linear, and Gaussian mixed models.

## Quick start

Requires R 4.6.x. From the project root:

```r
renv::restore()
shiny::runApp(".")
```

Starting R in the project root loads the committed `.Rprofile`, which activates
the project library and bootstraps the locked `renv` version when necessary.
`renv::restore()` then installs the exact runtime and test dependencies recorded
in `renv.lock` into that isolated project library.

On Windows, `run.bat` first changes to its own directory so the same activation
takes effect, then performs the restore and launches the app with R 4.6.0.

Run tests from the project root with:

```r
testthat::test_dir("tests", reporter = "summary")
```

## Supported models

The beta supports exactly 12 model/link combinations.

| Model ID | UI label | Fit | Predictors | Link |
|---|---|---|---|---|
| `lm_2d` | Simple LM (2D) | `lm` | `X` | `identity` |
| `lm_3d` | Multiple LM (3D) | `lm` | `X + Y` | `identity` |
| `glm_binomial` | Binomial GLM | `glm(binomial)` | `X + Y` | `logit` |
| `glm_binomial` | Binomial GLM | `glm(binomial)` | `X + Y` | `probit` |
| `glm_binomial` | Binomial GLM | `glm(binomial)` | `X + Y` | `cloglog` |
| `glm_poisson` | Poisson GLM | `glm(poisson)` | `X + Y` | `log` |
| `glm_poisson` | Poisson GLM | `glm(poisson)` | `X + Y` | `identity` |
| `glm_poisson` | Poisson GLM | `glm(poisson)` | `X + Y` | `sqrt` |
| `glm_gamma` | Gamma GLM | `glm(Gamma)` | `X + Y` | `inverse` |
| `glm_gamma` | Gamma GLM | `glm(Gamma)` | `X + Y` | `log` |
| `glm_gamma` | Gamma GLM | `glm(Gamma)` | `X + Y` | `identity` |
| `glmm` | Gaussian GLMM | `lmer` | `X + Y + (1 | Group)` | `identity` |

## Security and beta scope

Expert mode evaluates R code and is restricted to trusted local use. Do not
expose it to untrusted or remote users.

This beta does not provide hosted-user isolation, arbitrary formulas, uploaded
datasets, random slopes, or generalized mixed models.
