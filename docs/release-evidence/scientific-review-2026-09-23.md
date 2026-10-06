# Scientific copy review — 0.10.0-beta.1

> Historical review under the former human-only approval policy. The [2 October policy addendum and explicit agent decision](decision-0.10.0-beta.1-2026-10-02.md) supersede that approval requirement; the findings and observations below are preserved.

Date: 2026-09-23 (Europe/Berlin). Reviewed commit: `b5e9bdd99a6d313007d3d65e4133c13e497b4b8b` on the supplied master checkout.

Candidate continuity checked on 2026-10-01: current `master` and remote are `fdc7647bc73fc4e9574135895f119608ede4ae16` after an explicitly authorized push. `git diff --stat b5e9bdd99a6d313007d3d65e4133c13e497b4b8b..fdc7647bc73fc4e9574135895f119608ede4ae16` shows only CI/diagnostic/test changes plus the 11-line DT focus callback in `R/mod_data_provenance.R`; scientific calculations, wording, example data and research notes are unchanged. This preserves the scope of the findings below; it is not a new human scientific approval. The current full local suite passed 175 tests / 11,756 assertions with no failure/error/skip and the documented Shiny build-version warning. See [current decision](decision-0.10.0-beta.1-2026-10-01.md) for hosted CI and other gates.

## Gate status

**Preparatory agent review complete; human scientific approval remains OPEN.** No P0/P1 scientific misinterpretation was demonstrated in the reviewed public paths. One P2 presentation/documentation inconsistency and one P3 terminology error are documented below. Neither establishes a numerical-model failure.

This file is not the human signature required by `CHANGELOG.md:124`. It must not be used to check that release gate. The first broader targeted run exited 1 in an invalid non-UTF-8 locale and under concurrent load. The subsequent rerun of the three affected scientific-copy files under the system UTF-8 locale passed: **11 tests, 340 passing assertions, zero failures/errors/skips, one retained package-build warning**. Both runs and their distinct scope are recorded below; no full-suite or performance rerun is claimed by this reviewer.

## Scope and method

- Read-only review of public Shiny copy, README/release scientific notes, bundled-example methodology, LM/GLM/Gaussian mixed-model interpretations, diagnostics, confidence versus prediction intervals, causality and Model Brain presentation/decomposition.
- Read `AGENTS.md` and the honesty, working-agile, graphify, systematic-debugging and verification-before-completion skills. The dispatched-subagent exception in using-superpowers applies. No application files, tests, existing documentation, commits or tags were modified by this review.
- Consulted the existing graph in memory using its actual vocabulary (`scientific`, `diagnostics`). Relevant nodes pointed to older example research/design documents and the old diagnostics illustration; they contained no current Model Brain source locations. Current conclusions therefore use the actual source files, not inferred graph relationships. No graph rebuild, persistence or external transmission of private code occurred. No graph-generation token cost was incurred; host-agent token usage is not exposed by these tools.
- External checks used only public primary documentation. Firecrawl CLI was unavailable (`firecrawl` command not found); the available web reader fetched official R/lme4 documentation instead.
- This was not an independent audit of every scientific source paper, every preprocessing record or interval coverage. There was no human statistical sign-off or manual visual/browser review in this subtask.

## Findings requiring review

### SCI-01 — P2: extrapolation is silently presented as an ordinary fitted surface

Locations: `R/mod_visualization.R:113` (prediction grid), `R/mod_visualization.R:116` (`pad = 0.15`), `R/mod_visualization.R:121` and `:129` (extended coordinates), `R/mod_pipeline.R:190` (caller retains that default), `R/mod_overview.R:72` (public chart summary).

The public pipeline extends both predictor ranges by 15%. The summary explains unavailable predictions outside the fitted **link/response** domain, but does not identify extrapolation outside the observed **predictor** ranges. A finite log-link prediction is marked available even for negative shell dimensions. The displayed fitted surface and exported grid consequently contain unsupported physical predictor values without a corresponding extrapolation label.

Fresh reproduction:

| Example | Observed X range | Grid X range | Grid rows outside observed marginal X/Y ranges |
|---|---:|---:|---:|
| Adélie flipper/body mass | 172–210 mm | 166.3–215.7 mm | 46 / 200 |
| Abalone rings | 15–163 mm | -7.2–185.2 mm | 416 / 900 |

For Abalone, the grid Y range is -29.805 to 231.105 g; 60 rows have X < 0 and 120 have Y < 0. All 900 rows have `.available = TRUE`. These counts overlap and must not be summed as distinct rows.

This conflicts with the example advice at `data/real/adelie_flipper_mass/README.md:48`, `data/real/abalone_rings/README.md:62`, and `data/real/inner_london_exam/README.md:152`, which discourage extrapolation or prescribe the observed ranges. The specific omission is that the displayed “fit” is not distinguished from its extrapolated extension; the underlying evaluation of the fitted equation is not itself arithmetically wrong.

Severity rationale: P2 for an exploratory teaching application, not a demonstrated P0/P1 blocker. A human reviewer should decide whether an explicit visible extrapolation qualification is sufficient or whether the displayed grid should respect observed ranges. Merely restricting marginal ranges would still not prove support for sparse joint X/Y combinations.

### SCI-02 — P3: Gamma fitting is incorrectly described as OLS

Locations: `data/real/forest_fire_positive_area/README.md:48` and `docs/research-real-example-glm-gamma.md:48`.

Both copies call the calculation an “OLS-estimated Gamma GLM”. The implemented `fit_glm_strategy()` calls `stats::glm` (`R/model_registry.R:82`); the reproduced fitted object reports `method = glm.fit`. R's primary documentation identifies that method as iteratively reweighted least squares (IWLS), not ordinary least squares. A precise description would name a Gamma GLM fitted by `stats::glm` using IWLS. [Official R glm documentation](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/glm.html)

Fresh default Gamma/log fit produced coefficients `2.722033`, `0.04934841`, `-0.01309398`, close to the documentation's rounded reference. The demonstrated defect concerns the estimator's name, not evidence of incorrect coefficients.

## Formulations found to be appropriately qualified

| Topic | Source evidence and assessment |
|---|---|
| Association and causality | `R/mod_eli5.R:19` holds included covariates fixed; `:41` explicitly says association, not causation. The mixed-model fixed-effect comparison states a common random-effect value. |
| Link-specific coefficients | `R/mod_eli5.R:2` distinguishes additive identity effects, multiplicative log effects, logit odds ratios and the other link scales. Baseline-dependent probability changes are not equated to coefficient magnitudes. |
| P-values | `R/mod_eli5.R:22` conditions interpretation on the fitted model and assumptions; `README.md:202` denies effect-importance/model-validity interpretations. |
| Mean CI versus future observation | `R/model_metrics.R:86` requests `interval = "confidence"`; `R/model_brain_plots.R:9` explicitly names mean-response intervals; `R/mod_eli5.R:43` distinguishes them from future-observation spread. The grid is labelled point estimates only at `R/mod_visualization.R:45`. R documents prediction intervals as referring to future observations, consistent with that distinction. [Official predict.lm documentation](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/predict.lm.html) |
| GLM interval method | `R/model_metrics.R:71` uses labelled approximate Wald coefficient intervals; `:108` labels response intervals as transformed link-scale Wald intervals. Inverse/sqrt branch crossing is explicitly guarded. This is not a claim of finite-sample exact coverage. |
| Gaussian mixed model | `README.md:194` explicitly defines Gaussian GLMM as the random-intercept `lmer` model. `data/real/inner_london_exam/README.md:3` additionally calls it a Gaussian linear mixed model. No generalized mixed-family support is promised. |
| Conditional versus population predictions | `R/mod_model.R:4` uses random effects for conditional predictions and `re.form = NA` for population predictions. `R/mod_overview.R:75` identifies the population surface. Model Brain supplies both decompositions. This matches the package's documented `re.form` semantics. [Official predict.merMod documentation](https://lme4.github.io/lme4/reference/predict.merMod.html) |
| Unavailable uncertainty | GLMM coefficient intervals/p-values and response intervals are explicitly unavailable; no p-value or interval is fabricated. `R/model_brain_plots.R:162` also identifies random-effect intervals as unavailable. |
| Diagnostics | `R/model_diagnostics.R:26` marks LM checks exploratory; `:50` does not demand normal Bernoulli residuals; `:70` denies that absence of optimizer warnings establishes validity. |
| Model Brain magnitudes | `R/model_brain_plots.R:139` rejects interpreting raw coefficient magnitudes as an importance ranking. The contribution view states that contribution uncertainty is not estimated. |
| Real outcomes and teaching scope | Scientific copy separates observed binary/count outcomes from predicted probabilities/means. The positive-fire example explicitly conditions on area > 0. Simulation provenance says synthetic observations are not empirical evidence. |

Additional human-review question, not a demonstrated blocker: `R/mod_data_provenance.R:74` uniformly says “Literature-backed default link”. The Gamma research note (`data/real/forest_fire_positive_area/README.md:46`) calls the Gamma analysis a proposed alternative to the paper's non-Gamma modelling. Consider whether “Default link for this teaching example” would more accurately convey the degree of literature support. This review did not re-audit every original article and does not assert that all default links lack literature support.

## Fresh command evidence

### Targeted suite

Executed from `D:/projet/lmplot`:

```powershell
& 'C:/Program Files/R/R-4.6.0/bin/x64/Rscript.exe' --vanilla -e '.libPaths("renv/library/windows/R-4.6/x86_64-w64-mingw32", include.site=FALSE); cat(R.version.string, "\n"); testthat::test_dir("tests", filter="^(eli5|scientific_copy|scientific_copy_tables|scientific_metadata|model_diagnostics|model_brain|model_brain_contract)$", reporter="summary")'
```

Result: **exit 1**, R version 4.6.0 (2026-04-24 ucrt). The test reporter displayed ten detailed failures and “15 more”; its maximum-failure output was truncated. Do not treat the following list as a complete inventory of every failed assertion.

1. `tests/test_model_brain_contract.R:281`: `elapsed = 2.160` seconds versus required `< 2`. Object size was `33,598,128` bytes, below the 40 MiB condition. Other agents were running a full suite, Docker build and application checks concurrently. This timing does not isolate a product performance regression. It was not retried by this reviewer.
2. `tests/test_scientific_copy.R:17`, `:21`, `:22`: concrete units differ as byte strings `kg/m\302\263` versus `kg/m<U+00B3>`; fire units differ as `\302\260C` versus `<U+00B0>C`.
3. `tests/test_scientific_copy_tables.R:8`, `:12`, `:13`: corresponding HTML/export unit mismatches. The displayed failing HTML contains `MPa per kg/mB3`.
4. `tests/test_scientific_metadata.R:120`: concrete hover label comparison for the superscript-three unit fails; additional failures were omitted by the reporter's limit.

The `eli5`, `model_brain`, and `model_diagnostics` sections showed only passing assertion markers. No skip marker was printed. This first targeted run nevertheless failed and must not be relabelled green; the later clean-locale result has its own command and evidence.

Warnings retained:

- Startup: setting `LC_COLLATE`, `LC_CTYPE`, `LC_MONETARY`, `LC_TIME` to `C.UTF-8` failed.
- `shiny` was built under R 4.6.1 (reported at `test_scientific_copy.R:69`).
- `testthat` was built under R 4.6.1 (final warning).

### Locale investigation without persistent changes

```r
cat(Sys.getlocale(), l10n_info()[["UTF-8"]])
Sys.setlocale("LC_CTYPE", ".UTF-8")
cat(l10n_info()[["UTF-8"]])
```

Separate fresh R process: initial locale `C`, UTF-8 `FALSE`; after the process-local call, locale `English_United Kingdom.utf8`, UTF-8 `TRUE`. Reading the concrete manifest unit initially yielded bytes `6b 67 2f 6d c2 b3`; reading after the change printed `kg/m³`. This supported an encoding-related explanation for the detailed text failures, subsequently tested by the clean-locale rerun below. No application fix was made.

Follow-up requested by the coordinator: an escalated, standard Rscript child process was launched from the project after removing only its inherited `LC_ALL`, `LC_CTYPE` and `LANG` environment variables:

```powershell
Remove-Item Env:LC_ALL,Env:LC_CTYPE,Env:LANG -ErrorAction SilentlyContinue
& 'C:/Program Files/R/R-4.6.0/bin/x64/Rscript.exe' -e 'cat("LOCALE:", Sys.getlocale(), "\n"); print(l10n_info()); source("app.R"); for (id in c("concrete_28d", "forest_fire_positive_area")) { m <- example_config(id); cat("EXAMPLE:",id,"\n"); dput(m$predictor_x_unit); print(charToRaw(m$predictor_x_unit)); cat("ENCODING:",Encoding(m$predictor_x_unit),"\n") }; cat("WARNINGS:\n"); print(warnings())'
```

Result: **exit 0**, with no startup locale warnings. All locale categories reported `English_United Kingdom.utf8` except `LC_NUMERIC=C`; `l10n_info()` reported UTF-8 `TRUE`, `codepage=65001`, `system.codepage=65001`. After sourcing the application, `dput()` returned the exact units `"kg/m³"` and `"°C"`; byte sequences were `6b 67 2f 6d c2 b3` and `c2 b0 43`. `warnings()` printed no warning entries. Thus removal of the injected invalid locale restores the system UTF-8 environment. This small probe was not a scientific-suite rerun.

The coordinator separately reported that the same Model Brain performance check passed in its full-suite run at **1.400 s**. That is relayed coordination evidence, not this reviewer's own rerun, and supports treating the concurrent 2.160 s observation as insufficient proof of a regression. Consult the coordinator's retained full-suite log for its complete result.

### Final UTF-8 rerun of the three scientific-copy files

At the coordinator's explicit request, a standard Rscript child process was run with the three injected locale variables removed. Only these files were selected: `test_scientific_copy.R`, `test_scientific_copy_tables.R`, `test_scientific_metadata.R`. No performance tests or other files were rerun.

```powershell
Remove-Item Env:LC_ALL,Env:LC_CTYPE,Env:LANG -ErrorAction SilentlyContinue
& 'C:/Program Files/R/R-4.6.0/bin/x64/Rscript.exe' -e 'cat(R.version.string,"\n"); cat("LOCALE:",Sys.getlocale(),"\n"); print(l10n_info()); results <- testthat::test_dir("tests", filter="^(scientific_copy|scientific_copy_tables|scientific_metadata)$", reporter="summary", stop_on_failure=FALSE); evidence <- as.data.frame(results); columns <- c("file","test","failed","error","warning","skipped","passed"); print(evidence[columns]); write.csv(evidence[columns], "docs/release-evidence/scientific-utf8-tests.csv", row.names=FALSE); stopifnot(!any(evidence$failed > 0L | evidence$error | evidence$skipped))' *> docs/release-evidence/scientific-utf8-tests.log
exit $LASTEXITCODE
```

Result: **exit 0**, **11 tests / 340 passing assertions / 0 failures / 0 errors / 0 skips**. One warning is counted in the test results: `shiny` was built under R 4.6.1, emitted from `test_scientific_copy.R:69`. The complete log also retains a separate final warning that `testthat` was built under R 4.6.1; it is not included in the CSV's per-test warning count. The first-run unit/label failures did not reproduce under the valid system UTF-8 environment. The CSV's per-test rows confirm the zero-failure/error/skip assertion, rather than relying solely on summary markers.

Artifacts: [complete clean-locale log](scientific-utf8-tests.log), [per-test CSV](scientific-utf8-tests.csv). These two additional new evidence files were explicitly requested by the coordinator after the original report-only scope.

### Grid and Gamma reproduction

After the same explicit `.libPaths()` and `source("app.R")`:

```r
for (id in c("adelie_flipper_mass", "abalone_rings")) {
  e <- load_real_example(id)
  f <- fit_model(e$analysis, e$metadata$model_type, e$metadata$default_link)
  g <- prediction_grid(e$analysis, f, e$metadata$model_type)
  inside <- g$X >= min(e$analysis$X) & g$X <= max(e$analysis$X)
  if ("Y" %in% names(g))
    inside <- inside & g$Y >= min(e$analysis$Y) & g$Y <= max(e$analysis$Y)
  print(list(id=id, observed_x=range(e$analysis$X), grid_x=range(g$X),
    outside=sum(!inside), rows=nrow(g)))
}
e <- load_real_example("abalone_rings")
f <- fit_model(e$analysis, "glm_poisson", "log")
g <- prediction_grid(e$analysis, f, "glm_poisson")
print(c(rows=nrow(g), negative_x=sum(g$X < 0), negative_y=sum(g$Y < 0)))
print(all(g$.available)); print(range(g$Y))
e <- load_real_example("forest_fire_positive_area")
f <- fit_model(e$analysis, "glm_gamma", "log")
print(coef(f)); print(f$method)
```

The separate Abalone/Gamma diagnostic command completed with **exit 0** and outputs recorded in SCI-01/SCI-02. These calculations do not certify future-observation performance or the scientific adequacy of the model families.

## Limits and required follow-through

- The release owner must obtain an actual human scientific review and approval of public UI/documentation. This preparatory review does not satisfy `CHANGELOG.md:124`.
- The three affected scientific-copy files now pass under the valid system UTF-8 locale. Retain the initial failed execution as environment evidence and the package-build warning. Full-suite/hosted results and performance acceptance belong to the coordinator's separately retained evidence.
- P2/P3 items were documented only. No fix, refactor, feature, commit, push or tag was performed by this subtask.
- Docker, hosted CI, staging, ingress/WebSocket behavior and accessibility are separate reviews. No conclusion about them is implied here.
