# LM Model Brain Implementation Plan

> **Partially superseded on 2026-09-22.** Do not execute the Streamlit/Python,
> dual-interface, or GLMM-fallback portions of this plan. Continue Model Brain
> work from `2026-09-22-lmplot-public-shiny-hardening.md`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter aux interfaces Shiny et Streamlit un graphe de calcul interactif, scientifiquement exact et accessible pour les 15 combinaisons LM/GLM/GLMM existantes, avec exploration locale observation par observation et vues globales.

**Architecture:** R demeure l'unique source des calculs scientifiques et produit un contrat sérialisable `ModelBrain` versionné. Shiny et le module Python `model_brain_viz.py` rendent exclusivement ce contrat avec Plotly; les changements de sélection filtrent les observations précalculées sans réajuster le modèle ni relancer `Rscript`.

**Tech Stack:** R, stats, lme4/nlme avec repli existant, Shiny, bslib, Plotly R, jsonlite, testthat, Python 3.10+, Pydantic 2, pandas, Plotly Python, Streamlit, unittest.

**Spec:** `docs/superpowers/specs/2026-08-15-lm-model-brain-design.md`

## Global Constraints

- Couvrir exactement les 15 combinaisons actuellement exposées par `MODEL_REGISTRY`; ne créer aucun nouveau modèle, lien, terme ou effet aléatoire.
- Représenter uniquement le graphe de calcul réel : biais, contributions observées, `eta`, lien inverse, prédiction et, pour le GLMM, intercept aléatoire.
- Ne jamais afficher de couche cachée fictive, réseau profond, rétropropagation, animation d'entraînement ou cerveau 3D décoratif.
- R est l'unique producteur de `eta`, des prédictions, contributions, effets aléatoires, intervalles, courbes de lien et résumés globaux.
- Les renderers R et Python ne recalculent aucune formule statistique; ils appliquent seulement des encodages visuels aux valeurs du contrat.
- Le contrat canonique porte `schema_version = "model-brain/1.0"` et conserve les doubles R à huit chiffres significatifs dans le pont JSON actuel.
- La tolérance scientifique est `max(1e-10, 1e-8 * abs(expected))` pour chaque valeur attendue.
- Une sélection d'observation ne réajuste jamais le modèle, ne reconstruit jamais le contrat et ne relance jamais `Rscript`.
- L'identifiant d'observation est l'identifiant métier lorsqu'il existe, sinon l'indice validé 1-based; il est transmis dans `customdata`.
- Les encodages restent accessibles sans couleur : formes de nœuds, styles de traits, texte et table exacte.
- Le Model Brain ne dépend d'aucun module `llm_audit` et ne modifie pas son runtime.
- Préserver toutes les modifications locales préexistantes; inspecter `git diff -- <file>` avant chaque fichier déjà modifié et ne mettre en index que les hunks du Model Brain.
- Les tests historiques qui réussissent au relevé initial doivent encore réussir à la vérification finale.

## File Map

- `R/mod_model_brain.R`: construction et validation scientifique du contrat canonique.
- `R/mod_model_brain_plot.R`: figures Plotly Shiny construites exclusivement depuis le contrat.
- `R/mod_visualization.R`: identifiants `customdata` dans les graphiques historiques liés.
- `app.R`: onglet Shiny, sélection réactive unique et état d'erreur isolé.
- `scripts/run_analysis.R`: ajout du contrat au résultat JSON Streamlit.
- `model_brain_viz.py`: modèles Pydantic et figures Plotly Python sans calcul scientifique.
- `streamlit_app.py`: onglet, état de sélection, interactions et exports Streamlit.
- `www/style.css`: disposition responsive, focus, contraste et mouvement réduit.
- `tests/test_model_brain*.R`: science, contrat, rendu, pont et serveur Shiny.
- `tests/python/test_model_brain*.py`: validation/rendu Python et absence de nouvelle exécution R.
- `scripts/benchmark_model_brain.R`: budget de construction et de sérialisation sur 5 000 observations.
- `docs/model-brain-verification.md`: matrice d'acceptation et preuves finales.

## Canonical Contract Shapes

- `topology.nodes`: data frame/list of records with `id`, `role`, `label`, `logical_x`, `logical_y`, and accessible `description`.
- `topology.edges`: data frame/list of records with `source`, `target`, `term`, and `coefficient`; local edge magnitude remains observation data.
- `coefficients`: records with `term`, `estimate`, `standard_error`, `lower_95`, and `upper_95`.
- `observations`: list of records with `observation_id`, `prediction_mode`, named `inputs`, contribution records (`term`, `input`, `coefficient`, `value`), `random_effect` (`group`, `value`, `available`, `active`), `eta`, `prediction`, `observed`, `residual`, and validity fields.
- `link_curve`: records with `eta`, `mu`, and `valid` authored by R.
- `global_summaries`: per-term contribution records and, for GLMM, random-effect records containing `minimum`, `q1`, `median`, `q3`, `maximum`, `missing_n`, `total_n`, and at most 1 000 deterministic plotted points.
- `warnings`: records with stable `code`, `scope`, and `message`.

---

### Task 1: Établir la référence de régression et la matrice des 15 combinaisons

**Files:**
- Create: `docs/model-brain-verification.md`
- Create: `tests/helper-model-brain.R`

**Interfaces:**
- Produces: `model_brain_cases() -> data.frame` and `fit_model_brain_case(case, n = 80L, seed = 42L) -> list` for deterministic tests only.

- [ ] **Step 1: Capture the baseline before changing application code**

Run: `git status --short`
Run: `Rscript -e "testthat::test_dir('tests', reporter='summary')"`
Run: `python -m py_compile streamlit_app.py`
Expected: record the exact passing/failing historical tests and current dirty files under `## Baseline` in `docs/model-brain-verification.md`; do not repair or stage unrelated failures.

- [ ] **Step 2: Write the failing registry-matrix helper test**

Make the helper resolve the repository root both under `testthat::test_dir()` and direct `Rscript` execution. Add a table derived from `MODEL_REGISTRY`, then add this temporary assertion at the bottom while test-driving the helper:

```r
stopifnot(nrow(model_brain_cases()) == 15L)
stopifnot(setequal(
  paste(model_brain_cases()$model_type, model_brain_cases()$link),
  unlist(lapply(names(MODEL_REGISTRY), function(id) {
    paste(id, MODEL_REGISTRY[[id]]$links)
  }))
))
```

- [ ] **Step 3: Run the helper and verify the expected failure**

Run: `Rscript -e "source('R/config.R'); source('R/mod_model.R'); source('R/mod_simulation.R'); source('tests/helper-model-brain.R')"`
Expected: FAIL because `model_brain_cases()` is not defined yet.

- [ ] **Step 4: Implement deterministic case helpers and remove the temporary bottom assertions**

Implement `model_brain_cases()` by expanding each registry entry's `links`, and implement `fit_model_brain_case()` with the existing `simulate_data()` and `fit_model()` paths. Preserve the fixed seed, ensure at least five groups for GLMM, and return `model_type`, `link`, `data`, and `fit`.

- [ ] **Step 5: Verify the helper matrix independently**

Run: `Rscript -e "source('R/config.R'); source('R/mod_model.R'); source('R/mod_simulation.R'); source('tests/helper-model-brain.R'); stopifnot(nrow(model_brain_cases()) == 15L)"`
Expected: PASS and exactly 15 rows.

- [ ] **Step 6: Commit only the baseline and helper**

```bash
git add docs/model-brain-verification.md tests/helper-model-brain.R
git commit -m "test: establish model brain baseline"
```

---

### Task 2: Construire le contrat scientifique observation par observation

**Files:**
- Create: `R/mod_model_brain.R`
- Create: `tests/test_model_brain.R`

**Interfaces:**
- Produces: `build_model_brain(fit, df, model_type, link, labels = NULL) -> list`.
- Produces: `model_brain_observation_ids(df) -> character`, `model_brain_tolerance(expected) -> numeric`, and prediction modes `conditional`/`population`.
- Consumes: fitted objects produced by existing `fit_model()` and the validated data snapshot used for that fit.

- [ ] **Step 1: Write failing scientific-equivalence tests for every registry case**

```r
test_that("all 15 model/link cases reproduce R predictions", {
  cases <- model_brain_cases()
  expect_equal(nrow(cases), 15L)
  for (i in seq_len(nrow(cases))) {
    fixture <- fit_model_brain_case(cases[i, ])
    brain <- build_model_brain(
      fixture$fit, fixture$data, fixture$model_type, fixture$link
    )
    conditional <- Filter(
      function(observation) observation$prediction_mode == "conditional",
      brain$observations
    )
    expected <- as.numeric(predict_response(fixture$fit, fixture$data))
    tolerance <- pmax(1e-10, 1e-8 * abs(expected))
    actual <- vapply(conditional, `[[`, numeric(1), "prediction")
    reconstructed_eta <- vapply(conditional, function(observation) {
      sum(vapply(observation$contributions, `[[`, numeric(1), "value")) +
        if (isTRUE(observation$random_effect$active)) observation$random_effect$value else 0
    }, numeric(1))
    eta <- vapply(conditional, `[[`, numeric(1), "eta")
    expect_true(all(abs(actual - expected) <= tolerance))
    expect_true(all(abs(eta - reconstructed_eta) <= tolerance))
  }
})
```

Add focused assertions that response residuals equal the current `response_residuals()` convention, observation IDs are unique/stable, and `input * coefficient == contribution` for each non-bias term.

- [ ] **Step 2: Run the tests and verify the missing-module failure**

Run: `Rscript -e "testthat::test_file('tests/test_model_brain.R')"`
Expected: FAIL because `R/mod_model_brain.R` and `build_model_brain()` do not exist.

- [ ] **Step 3: Implement the minimal scientific producer**

Implement extraction from the fitted model object, not from renderer-side formulas:

- use the fitted model matrix and fixed-effect coefficients for the bias and predictor contributions;
- use the fitted family object's `linkfun`/`linkinv` or the existing prediction methods for `eta` and response-scale prediction;
- emit conditional observations for all models;
- emit population observations only for GLMM;
- extract each GLMM group intercept when the engine exposes it;
- set `random_effect_available = FALSE`, `random_effect = NA_real_` and a stable warning for the documented fallback when no exact random intercept exists;
- keep observed response and response residual as comparison fields, never as active input nodes;
- use a source business ID column only when it is unique and non-missing, otherwise use character row numbers `"1"`, `"2"`, ...;
- normalize `labels` without inventing units.

- [ ] **Step 4: Add explicit GLMM mode tests**

Assert that population mode has an inactive zero random branch, conditional mode uses the exact group intercept when available, and both match `predict_response(..., population = TRUE/FALSE)` within tolerance. Parameterize expectations for `lme4`, `nlme`, and the existing fixed-factor fallback.

- [ ] **Step 5: Run all scientific tests**

Run: `Rscript -e "testthat::test_file('tests/test_model_brain.R')"`
Expected: PASS for all 15 model/link cases; fallback-specific tests SKIP only when their engine is unavailable.

- [ ] **Step 6: Commit the scientific core**

```bash
git add R/mod_model_brain.R tests/test_model_brain.R
git commit -m "feat: build canonical model brain observations"
```

---

### Task 3: Valider la topologie, les incertitudes, le lien et les résumés globaux

**Files:**
- Modify: `R/mod_model_brain.R`
- Create: `tests/test_model_brain_contract.R`

**Interfaces:**
- Produces: `validate_model_brain(brain) -> invisible(brain)`, `default_model_brain_observation(brain, mode = "conditional") -> character`, and `sanitize_model_brain_for_json(brain) -> list`.
- Contract: `schema_version`, model metadata, `prediction_modes`, `labels`, `topology`, `coefficients`, `observations`, `link_curve`, `global_summaries`, and `warnings`.

- [ ] **Step 1: Write failing schema, topology and default-selection tests**

```r
test_that("the canonical contract is complete and acyclic", {
  fixture <- fit_model_brain_case(model_brain_cases()[1, ])
  brain <- build_model_brain(fixture$fit, fixture$data, fixture$model_type, fixture$link)
  expect_identical(brain$schema_version, "model-brain/1.0")
  expect_silent(validate_model_brain(brain))
  expect_error(validate_model_brain(within(brain, topology$nodes$id[2] <- topology$nodes$id[1])), "duplicate")
  expect_error(validate_model_brain(within(brain, topology$edges$source[1] <- "orphan")), "orphan")
})
```

Add tests that the default observation has the median fitted value with lexical-ID tie-break, each coefficient interval equals `estimate +/- qnorm(0.975) * standard_error`, and no hidden-layer role can validate.

- [ ] **Step 2: Write failing link-curve, domain-warning and summary tests**

Assert that:

- every link-curve `mu` comes from the fitted R family's `linkinv` over a deterministic `eta` grid;
- the current observation's exact `eta` and prediction lie on the same coordinate system;
- invalid/non-finite response-domain values become `NA` only through `sanitize_model_brain_for_json()` and create stable warnings;
- every contribution and random-effect summary contains min, Q1, median, Q3, max, missing N and at most 1 000 deterministically sampled points;
- the full observation table remains unsampled.

- [ ] **Step 3: Run the focused contract tests and verify failures**

Run: `Rscript -e "testthat::test_file('tests/test_model_brain_contract.R')"`
Expected: FAIL on missing validation, topology, link-curve and summary behavior.

- [ ] **Step 4: Implement contract completion and validation**

Build a left-to-right directed acyclic topology from the exact fitted terms. Give each node a stable ID, role and logical column/row position; edges carry term and coefficient but local thickness data remains in observations. Reject duplicate IDs, orphan edges, cycles, unsupported roles and unknown prediction modes.

Compute Wald intervals, the R-authored link curve, domain validity, deterministic global summaries, and default observation. Convert non-finite JSON values to missing values with warnings instead of clipping them.

- [ ] **Step 5: Verify the complete R contract suite**

Run: `Rscript -e "testthat::test_file('tests/test_model_brain.R'); testthat::test_file('tests/test_model_brain_contract.R')"`
Expected: PASS; every case validates as `model-brain/1.0`.

- [ ] **Step 6: Commit the contract validation**

```bash
git add R/mod_model_brain.R tests/test_model_brain_contract.R
git commit -m "feat: validate model brain contract and summaries"
```

---

### Task 4: Rendre le cerveau et les vues explicatives dans Plotly R

**Files:**
- Create: `R/mod_model_brain_plot.R`
- Create: `tests/test_model_brain_visualization.R`

**Interfaces:**
- Produces: `model_brain_network_plot(brain, observation_id, mode)`, `model_brain_waterfall_plot(...)`, `model_brain_link_plot(...)`, `model_brain_forest_plot(brain)`, `model_brain_contribution_plot(brain, mode)`, and `model_brain_random_effect_plot(brain)`.
- Consumes only fields already present in a validated `ModelBrain` contract.

- [ ] **Step 1: Write failing visual-contract tests**

Use `plotly::plotly_build()` to assert:

- network traces progress left-to-right and contain no hidden-layer or 3D trace;
- positive, negative and negligible contributions use distinct line dash/text encodings as well as color;
- edge width is monotone in `abs(local contribution)` within the selected observation and never based on `abs(coefficient)` alone;
- every hover contains input, coefficient and contribution where applicable;
- the waterfall terminates at contract `eta`, then shows the separate inverse-link result from the contract;
- link, waterfall and network expose the same `eta` and prediction;
- the forest plot uses contract lower/upper Wald bounds and a zero reference;
- plots expose N, prediction mode, missing counts and units or `unité non fournie`.

- [ ] **Step 2: Run the tests and verify missing-renderer failures**

Run: `Rscript -e "testthat::test_file('tests/test_model_brain_visualization.R')"`
Expected: FAIL because `R/mod_model_brain_plot.R` does not exist.

- [ ] **Step 3: Implement presentation-only Plotly builders**

Render node roles with different marker symbols, signs with color plus line dash, local magnitudes with observation-local edge-width normalization, and arrow annotations for calculation direction. Add an explicit legend stating that widths are not comparable between observations. Read every numeric label from the contract and display at least six significant digits.

Use the contract's deterministic sample for global point overlays; keep quartiles/extrema from `global_summaries`. Never call `predict()`, `coef()`, `family()`, `linkinv`, `qnorm()` or model fitting functions in this file.

- [ ] **Step 4: Add a renderer purity guard**

```r
test_that("renderers contain no scientific recomputation", {
  source_text <- paste(readLines(file.path("..", "R", "mod_model_brain_plot.R")), collapse = "\n")
  expect_false(grepl("predict\\s*\\(|coef\\s*\\(|linkinv|qnorm\\s*\\(|lm\\s*\\(|glm\\s*\\(", source_text))
})
```

- [ ] **Step 5: Verify all R visualizations**

Run: `Rscript -e "testthat::test_file('tests/test_model_brain_visualization.R')"`
Expected: PASS, including accessible redundant encodings and renderer purity.

- [ ] **Step 6: Commit the R renderer**

```bash
git add R/mod_model_brain_plot.R tests/test_model_brain_visualization.R
git commit -m "feat: render model brain plots in R"
```

---

### Task 5: Relier les identifiants aux graphiques historiques

**Files:**
- Modify: `R/mod_visualization.R`
- Modify: `R/mod_examples.R`
- Modify: `tests/test_visualization.R`
- Modify: `tests/test_examples.R`

**Interfaces:**
- Changes: `enrich_data(df, fit, observation_ids = NULL)` adds `.observation_id`.
- Changes: `build_main_plot(..., observation_ids = NULL)` and the real-example path attach observation IDs as Plotly `customdata` to observed-point traces.

- [ ] **Step 1: Inspect and preserve local edits before patching**

Run: `git diff -- R/mod_visualization.R R/mod_examples.R tests/test_visualization.R tests/test_examples.R`
Expected: review every preexisting hunk; plan Model Brain changes around them and do not normalize unrelated formatting.

- [ ] **Step 2: Write failing linked-ID tests**

Assert for 2D, 3D, GLMM and one real example that observed-point traces contain one stable `customdata` ID per row, fitted curves/surfaces do not masquerade as selectable observations, and duplicate or length-mismatched provided IDs are rejected.

- [ ] **Step 3: Run the focused visualization tests**

Run: `Rscript -e "testthat::test_file('tests/test_visualization.R'); testthat::test_file('tests/test_examples.R')"`
Expected: new assertions FAIL because observed traces lack `customdata`.

- [ ] **Step 4: Add observation IDs without changing historical geometry**

Accept contract-derived IDs from `app.R`; when the optional argument is absent, use validated character row numbers without depending on `R/mod_model_brain.R`. Attach IDs to marker traces and include the exact ID in hover text. Preserve existing curve, surface, axis, palette and camera behavior. Set the observed plot source to `main_plot` so Shiny can read selection events.

- [ ] **Step 5: Verify linked IDs and historical plots**

Run: `Rscript -e "testthat::test_file('tests/test_visualization.R'); testthat::test_file('tests/test_examples.R'); testthat::test_file('tests/test_acceptance.R')"`
Expected: PASS with the same trace types and geometry plus marker `customdata`.

- [ ] **Step 6: Stage only Model Brain hunks and commit**

Run: `git diff --check -- R/mod_visualization.R R/mod_examples.R tests/test_visualization.R tests/test_examples.R`
Then interactively stage only the intended hunks if those files contained preexisting changes.

```bash
git add -p R/mod_visualization.R R/mod_examples.R tests/test_visualization.R tests/test_examples.R
git commit -m "feat: link model observations across R plots"
```

---

### Task 6: Intégrer l'onglet Model Brain dans Shiny sans réajustement

**Files:**
- Modify: `app.R`
- Modify: `www/style.css`
- Create: `tests/test_model_brain_server.R`
- Modify: `tests/test_app_structure.R`

**Interfaces:**
- Adds: `last_result()$model_brain`, `selected_observation_id <- reactiveVal(NULL)`, and one `Model Brain` navigation panel.
- Selection sources: `event_data("plotly_click", source = "main_plot")`, explicit select input, previous/next actions and row selection.
- Selection effect: filters `last_result()$model_brain$observations` only.

- [ ] **Step 1: Inspect local app changes before editing**

Run: `git diff -- app.R www/style.css tests/test_server.R tests/test_app_structure.R`
Expected: identify and preserve all existing user hunks.

- [ ] **Step 2: Write failing server and structure tests**

Test with `shiny::testServer()` that:

- a successful generation stores a valid `model_brain` alongside the existing fit;
- default selection follows the median-fitted contract rule;
- plot click, selector, table row and previous/next converge on the same ID;
- changing selection leaves `last_result()$fit` and `last_result()$model_brain` identical by object identity/content;
- an unknown ID falls back to the default after a new fit;
- a contract-construction error preserves the existing successful main plot result and emits a recoverable Model Brain error;
- the UI contains context, selector, network, equation, waterfall, link curve, global views, exact table and JSON download outputs.

- [ ] **Step 3: Run the focused Shiny tests and verify failures**

Run: `Rscript -e "testthat::test_file('tests/test_model_brain_server.R'); testthat::test_file('tests/test_app_structure.R')"`
Expected: FAIL because the sources, navigation panel and reactive selection do not exist.

- [ ] **Step 4: Add sources, contract construction and isolated error state**

Source `R/mod_model_brain.R` before `R/mod_model_brain_plot.R`. Build the contract once inside the existing successful generate path. Store either a validated contract or a typed Model Brain error without discarding the fitted result. Never place contract construction inside an observation-selection reactive.

- [ ] **Step 5: Build the ordered Shiny composition**

Add the spec-defined order: sticky context, keyboard selector and previous/next, 2D graph plus exact equation, waterfall, link curve, forest/contributions/residuals/random effects, exact table and JSON download. Use `plotlyProxy` or render from the already stored contract on selection; do not call `fit_model()` or `build_model_brain()` from selection observers.

Add focus-visible styles, responsive stacking and `prefers-reduced-motion` handling to `www/style.css`; retain WCAG AA token values and ensure every color encoding has a textual or line/shape equivalent.

- [ ] **Step 6: Run Shiny integration and regression tests**

Run: `Rscript -e "testthat::test_file('tests/test_model_brain_server.R'); testthat::test_file('tests/test_app_structure.R'); testthat::test_file('tests/test_server.R'); testthat::test_file('tests/test_app.R')"`
Expected: PASS; changing observation never invokes the fit or brain producer spies.

- [ ] **Step 7: Stage only intended hunks and commit**

```bash
git add R/mod_model_brain.R R/mod_model_brain_plot.R tests/test_model_brain_server.R
git add -p app.R www/style.css tests/test_app_structure.R
git commit -m "feat: add interactive model brain to Shiny"
```

---

### Task 7: Publier le contrat dans le pont JSON R

**Files:**
- Modify: `scripts/run_analysis.R`
- Create: `tests/test_model_brain_bridge.R`

**Interfaces:**
- Adds: `result$model_brain` containing `sanitize_model_brain_for_json(build_model_brain(...))`.
- Preserves: all existing top-level JSON fields and `jsonlite::write_json(..., digits = 8)` behavior.

- [ ] **Step 1: Inspect the preexisting bridge diff**

Run: `git diff -- scripts/run_analysis.R`
Expected: preserve all unrelated local changes and the current CLI argument contract.

- [ ] **Step 2: Write failing end-to-end bridge tests**

Invoke `Rscript scripts/run_analysis.R request.json output.json` for a simple LM, a non-identity GLM and GLMM. Assert the old keys remain, `model_brain.schema_version == "model-brain/1.0"`, observations retain eight-significant-digit-compatible values, and `jsonlite::validate()` accepts the output without `NaN`/`Inf` literals.

- [ ] **Step 3: Run and verify the missing-field failure**

Run: `Rscript -e "testthat::test_file('tests/test_model_brain_bridge.R')"`
Expected: FAIL because `model_brain` is absent from the result.

- [ ] **Step 4: Source the producer and append the sanitized contract**

Source `R/mod_model_brain.R`, call the producer once after the existing fit, and add the result without changing existing coefficients, grid, diagnostics or labels. Do not add R package installation or network behavior.

- [ ] **Step 5: Verify bridge and historical script behavior**

Run: `Rscript -e "testthat::test_file('tests/test_model_brain_bridge.R'); testthat::test_file('tests/test_release.R')"`
Expected: PASS; the output is valid JSON and old keys are byte-structure compatible apart from the new field.

- [ ] **Step 6: Stage the precise bridge hunk and commit**

```bash
git add tests/test_model_brain_bridge.R
git add -p scripts/run_analysis.R
git commit -m "feat: expose model brain through R bridge"
```

---

### Task 8: Valider et rendre le contrat dans Plotly Python

**Files:**
- Create: `model_brain_viz.py`
- Create: `tests/python/test_model_brain_viz.py`

**Interfaces:**
- Produces: Pydantic DTOs `ModelBrainContract`, `BrainObservation`, `BrainWarning`.
- Produces: `validate_model_brain(payload)`, `default_observation_id(contract, mode)`, `build_network_figure(...)`, `build_waterfall_figure(...)`, `build_link_figure(...)`, `build_forest_figure(...)`, `build_contribution_figure(...)`, and `build_random_effect_figure(...)`.
- Consumes only canonical R-produced numeric fields; rejects unsupported schema versions.

- [ ] **Step 1: Write failing validation and renderer tests**

Create compact JSON fixtures that exercise LM, GLM and GLMM topologies. Assert duplicate/orphan/cyclic nodes, unknown roles, bad modes and duplicate observation IDs fail validation; warnings and missing numeric values remain explicit; the default ID matches the contract rule.

For each Plotly figure assert redundant sign encodings, exact hover values, 2D-only network traces, local edge-width behavior, contract-provided confidence bounds, N/missing/mode/unit captions and a table-ready exact observation record.

- [ ] **Step 2: Run the tests and verify the missing-module failure**

Run: `python -m unittest discover -s tests/python -p "test_model_brain_viz.py" -v`
Expected: FAIL because `model_brain_viz` does not exist.

- [ ] **Step 3: Implement Pydantic validation and presentation-only renderers**

Keep Pydantic in strict validation mode for IDs, topology and enum-like roles. Construct Plotly traces exclusively from validated contract coordinates and values. Format hover labels with at least six significant digits while preserving raw doubles in `customdata` and downloads.

- [ ] **Step 4: Add a Python purity test**

Use `ast` from a `unittest.TestCase` to reject imports of statsmodels/scipy model modules and calls named `predict`, `fit`, `linkinv`, `expit`, `norm.cdf`, or coefficient-interval calculations in `model_brain_viz.py`. Plot layout arithmetic and visual edge-width normalization remain allowed.

- [ ] **Step 5: Verify the independent standard-library test suite**

Use the standard-library `unittest` runner so this plan remains executable before or after the independent LLM Audit plan. Reuse the existing Pydantic and Plotly runtime requirements; do not import or depend on `llm_audit`.

Run: `python -m unittest discover -s tests/python -p "test_model_brain_viz.py" -v`
Run: `python -m py_compile model_brain_viz.py`
Expected: PASS with no import from `llm_audit`.

- [ ] **Step 6: Commit the Python presentation layer**

```bash
git add model_brain_viz.py tests/python/test_model_brain_viz.py
git commit -m "feat: render model brain contract in Python"
```

---

### Task 9: Intégrer l'exploration liée dans Streamlit sans relancer R

**Files:**
- Modify: `streamlit_app.py`
- Create: `tests/python/test_model_brain_streamlit.py`

**Interfaces:**
- Adds: `st.session_state["model_brain_observation_id"]` and `st.session_state["model_brain_prediction_mode"]`.
- Adds: `render_model_brain_tab(contract, df_data, selected_id, mode)` using `model_brain_viz.py` only.
- Preserves: `_cached_run_r_analysis(payload_str)` as the sole R execution boundary.

- [ ] **Step 1: Inspect and preserve local Streamlit edits**

Run: `git diff -- streamlit_app.py`
Expected: review the current user-owned Streamlit changes and avoid whole-file rewrites or encoding normalization.

- [ ] **Step 2: Write failing state and no-rerun tests**

With `unittest.mock` around `_cached_run_r_analysis`/`subprocess.run`, assert that:

- fitting invokes the cached R boundary once for a payload;
- changing observation, previous/next, table selection or prediction mode reuses the loaded contract and invokes R zero additional times;
- a main-plot Plotly selection reads its observation ID from `customdata`;
- an ID absent after a new fit falls back to the contract default;
- invalid contracts display an isolated tab error while historical tabs retain their analysis;
- JSON and filtered observation downloads preserve exact contract values.

- [ ] **Step 3: Run and verify the failing Streamlit tests**

Run: `python -m unittest discover -s tests/python -p "test_model_brain_streamlit.py" -v`
Expected: FAIL because Model Brain state and rendering integration are absent.

- [ ] **Step 4: Add linked IDs to existing Streamlit figures**

Attach observation IDs as `customdata` to observed 2D/3D main traces and residual points. Use Streamlit Plotly selection events where supported, but keep the explicit selectbox and previous/next controls as the accessible authoritative fallback. Do not make fitted lines or surfaces selectable observations.

- [ ] **Step 5: Add the ordered Model Brain tab**

Validate `analysis["model_brain"]` once, place the tab alongside the existing four tabs, and render context, selector, graph/equation, waterfall, link curve, global figures, exact table and downloads. Show conditional/population controls only when present in `prediction_modes`. Preserve the last valid analysis when the Model Brain portion is invalid.

- [ ] **Step 6: Run Streamlit and Python presentation tests**

Run: `python -m unittest discover -s tests/python -p "test_model_brain*.py" -v`
Run: `python -m py_compile streamlit_app.py model_brain_viz.py`
Expected: PASS; selection-only tests report one initial R call and zero subsequent calls.

- [ ] **Step 7: Stage only intended Streamlit hunks and commit**

```bash
git add tests/python/test_model_brain_streamlit.py
git add -p streamlit_app.py
git commit -m "feat: add interactive model brain to Streamlit"
```

---

### Task 10: Vérifier accessibilité, budgets de performance et robustesse

**Files:**
- Create: `scripts/benchmark_model_brain.R`
- Create: `tests/test_model_brain_accessibility.R`
- Create: `tests/test_model_brain_performance.R`
- Create: `tests/python/test_model_brain_accessibility.py`
- Modify: `README.md`

**Interfaces:**
- Benchmark CLI: `Rscript scripts/benchmark_model_brain.R --rows 5000 --max-seconds 2 --max-json-mib 25`.
- Selection benchmark: ten deterministic, already-loaded observation changes with p95 `< 1.0 s` in each renderer harness.

- [ ] **Step 1: Write failing accessibility checks**

Assert in R and Python that controls have accessible labels, focus order follows the calculation, graph nodes/edges expose textual descriptions, exact tables are present, color is never the only sign channel, and reduced-motion CSS removes transitions. Check the selected state and warnings meet WCAG 2.2 AA contrast targets (4.5:1 text, 3:1 graphic elements) from actual CSS/Plotly colors.

- [ ] **Step 2: Write the deterministic 5 000-row benchmark**

Fit the most complex supported case, time only `build_model_brain()` plus sanitization, serialize with the production `jsonlite::write_json(..., digits = 8)` path, measure file bytes, and exit non-zero if elapsed time is `>= 2.0` seconds or JSON is `>= 25 MiB`. The script prints engine, CPU count, R version, elapsed seconds and byte count.

In renderer tests, preload the contract, perform ten seeded selection updates, calculate p95, and fail at `>= 1.0` second. Do not include fit, bridge launch or contract construction in selection timing.

- [ ] **Step 3: Run the new checks and record initial failures**

Run: `Rscript -e "testthat::test_file('tests/test_model_brain_accessibility.R'); testthat::test_file('tests/test_model_brain_performance.R')"`
Run: `python -m unittest discover -s tests/python -p "test_model_brain_accessibility.py" -v`
Run: `Rscript scripts/benchmark_model_brain.R --rows 5000 --max-seconds 2 --max-json-mib 25`
Expected: any unmet labels, contrast, reduced-motion or budget produces a precise failing assertion.

- [ ] **Step 4: Optimize contract size and rendering without changing science**

Keep every observation's exact scientific fields, but remove duplicated labels/topology from per-observation records, cap only plotted samples at 1 000 deterministically, vectorize R extraction, and reuse precomputed renderer lookups. Do not weaken thresholds, tolerance, warnings or the full exact table.

- [ ] **Step 5: Document user workflow and scientific meaning**

Update `README.md` with the functional-neuron interpretation, the 15 combinations, local/global views, conditional/population GLMM distinction, selection controls, exports, limitations, and commands for Shiny and Streamlit. State explicitly that no neural network is trained and no hidden layer is inferred.

- [ ] **Step 6: Verify budgets and accessibility**

Run: `Rscript scripts/benchmark_model_brain.R --rows 5000 --max-seconds 2 --max-json-mib 25`
Run: `Rscript -e "testthat::test_file('tests/test_model_brain_accessibility.R'); testthat::test_file('tests/test_model_brain_performance.R')"`
Run: `python -m unittest discover -s tests/python -p "test_model_brain*.py" -v`
Expected: PASS; printed build time `<2.0 s`, JSON `<25 MiB`, and selection p95 `<1.0 s`.

- [ ] **Step 7: Commit quality gates and documentation**

```bash
git add scripts/benchmark_model_brain.R tests/test_model_brain_accessibility.R tests/test_model_brain_performance.R tests/python/test_model_brain_accessibility.py
git add -p README.md
git commit -m "test: enforce model brain quality budgets"
```

---

### Task 11: Fermer la matrice d'acceptation et la régression complète

**Files:**
- Modify: `docs/model-brain-verification.md`
- Modify: `docs/superpowers/specs/2026-08-15-lm-model-brain-design.md`

**Interfaces:**
- Produces: one evidence row for each of the 15 acceptance criteria in the specification.

- [ ] **Step 1: Run scientific, contract and renderer suites**

Run: `Rscript -e "testthat::test_file('tests/test_model_brain.R'); testthat::test_file('tests/test_model_brain_contract.R'); testthat::test_file('tests/test_model_brain_visualization.R'); testthat::test_file('tests/test_model_brain_bridge.R'); testthat::test_file('tests/test_model_brain_server.R')"`
Expected: PASS for all installed engines; optional-engine skips are explicit and fallback coverage passes.

- [ ] **Step 2: Run the complete regression suites**

Run: `Rscript -e "testthat::test_dir('tests', reporter='summary')"`
Run: `python -m unittest discover -s tests/python -p "test_model_brain*.py" -v`
Run: `python -m py_compile streamlit_app.py model_brain_viz.py`
Run: `docker compose config`
Expected: every baseline-green historical test remains green; Model Brain tests PASS; Python compiles; Compose remains valid.

- [ ] **Step 3: Re-run acceptance performance**

Run: `Rscript scripts/benchmark_model_brain.R --rows 5000 --max-seconds 2 --max-json-mib 25`
Expected: PASS on the documented 4-core, 8-GiB, SSD profile; record elapsed, bytes and selection p95 in the verification document.

- [ ] **Step 4: Audit forbidden scope and placeholder text**

Run: `rg -n -i "TODO|TBD|FIXME|XXX|hidden layer|deep network|backprop|llm_audit" R/mod_model_brain.R R/mod_model_brain_plot.R model_brain_viz.py app.R streamlit_app.py tests/test_model_brain*.R tests/python/test_model_brain*.py`
Expected: no placeholders; forbidden concepts appear only in explicit rejection/purity tests; production Model Brain modules contain no `llm_audit` dependency.

Run: `rg -n "predict\\s*\\(|coef\\s*\\(|linkinv|qnorm\\s*\\(|lm\\s*\\(|glm\\s*\\(" R/mod_model_brain_plot.R model_brain_viz.py`
Expected: no scientific recomputation in either renderer.

- [ ] **Step 5: Complete traceability and mark implementation verified**

For each acceptance criterion, record the test name/command and observed outcome in `docs/model-brain-verification.md`. Change the specification status to `implémentée et vérifiée` only after every criterion has evidence; otherwise leave the status unchanged and record the exact blocker.

- [ ] **Step 6: Inspect final scope and commit verification only**

Run: `git diff --check`
Run: `git status --short`
Expected: no whitespace errors introduced by Model Brain; unrelated preexisting files remain unstaged.

```bash
git add docs/model-brain-verification.md docs/superpowers/specs/2026-08-15-lm-model-brain-design.md
git commit -m "docs: verify model brain acceptance"
```
