# Scientific Real-Data Examples Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one verified scientific real-data case for each of the six beta model modes, make every case selectable and fully interactive in Shiny, and export six reproducible static graphs.

**Architecture:** Complete the already-approved beta model pipeline first, then add an example registry beside the model registry. Versioned source snapshots are fetched with SHA-256 guards, transformed deterministically into model-ready snapshots, and passed through the same validation, fit, prediction, residual, diagnostic, table, and Plotly code as simulations; `app.R` only orchestrates source selection.

**Tech Stack:** R 4.6.x, Shiny, bslib, Plotly, ggplot2, DT, lme4, readxl, digest, htmlwidgets, webshot2, testthat, shinytest2, base R download/archive tools.

## Global Constraints

- Work only on branch `codex/real-data-examples`.
- Use `C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe` for Windows verification.
- First execute `docs/superpowers/plans/2026-07-18-lmplot-beta.md` through its final acceptance task; the real-data tasks below consume its six-model registry and common model/plot pipeline.
- Keep exactly these beta model IDs: `lm_2d`, `lm_3d`, `glm_binomial`, `glm_poisson`, `glm_gamma`, `glmm`.
- Normal Shiny sessions perform no network access; they read committed model-ready snapshots.
- All GLM plots use response-scale predictions from `predict(..., type = "response")`.
- GLMM population surfaces exclude random effects; observed fitted values and residuals include school effects.
- Every source checksum mismatch stops a rebuild before replacing a reviewed snapshot.
- Preserve original scientific labels and units in axes, tooltips, tables, downloads, and provenance copy.
- Label all six fits descriptive or pedagogical; do not make causal claims.
- Treat alternative GLM links as exploratory; select the literature-backed link by default.
- Do not commit temporary downloads, rendered browser state, Graphify output, or server logs.

---

### Task 0: Beta Pipeline Prerequisite

**Files:**
- Follow: `docs/superpowers/plans/2026-07-18-lmplot-beta.md`
- Verify: `R/config.R`
- Verify: `R/mod_model.R`
- Verify: `R/mod_simulation.R`
- Verify: `R/mod_visualization.R`
- Verify: `tests/test_acceptance.R`

**Interfaces:**
- Consumes: current alpha `app.R`, `R/mod_simulation.R`, and existing tests.
- Produces: `MODEL_REGISTRY`, `model_ids()`, `model_config()`, `valid_links()`, `fit_model()`, `predict_response()`, `fitted_response()`, `response_residuals()`, `validate_simulation_data()`, `prediction_grid()`, `build_main_plot()`, and `enrich_data()`.

- [ ] **Step 1: Execute the beta plan task-by-task**

Use `superpowers:subagent-driven-development` and complete every checkbox in `docs/superpowers/plans/2026-07-18-lmplot-beta.md`. Review each task before moving to the next one.

- [ ] **Step 2: Run the beta acceptance matrix**

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_acceptance.R')"
```

Expected: 12 model/link combinations pass end to end.

- [ ] **Step 3: Confirm the real-data prerequisite interfaces**

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "source('R/config.R'); source('R/mod_model.R'); stopifnot(identical(model_ids(), c('lm_2d','lm_3d','glm_binomial','glm_poisson','glm_gamma','glmm')))"
```

Expected: exit 0.

---

### Task 1: Example Manifest and Provenance Contract

**Files:**
- Create: `data/real/manifest.csv`
- Create: `data/real/NOTICE.md`
- Create: `tests/test_example_manifest.R`

**Interfaces:**
- Consumes: `model_ids()` from `R/mod_model.R`.
- Produces: one manifest row per model, exact source/checksum metadata, display labels, expected prepared row counts, and the provenance contract used by all later tasks.

- [ ] **Step 1: Write the failing manifest test**

```r
# tests/test_example_manifest.R
source(file.path("..", "R", "mod_model.R"))

test_that("real-data manifest covers the six beta models exactly", {
  manifest <- utils::read.csv(
    file.path("..", "data", "real", "manifest.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_equal(nrow(manifest), 6L)
  expect_setequal(manifest$model_type, model_ids())
  expect_false(anyDuplicated(manifest$example_id))
  expect_false(anyDuplicated(manifest$model_type))
  required <- c(
    "example_id", "model_type", "title", "source_file", "source_url",
    "source_sha256", "source_doi", "publication_url", "publication_doi",
    "license_name", "license_url", "default_link", "response_source",
    "predictor_x_source", "predictor_y_source", "group_source",
    "response_label", "predictor_x_label", "predictor_y_label",
    "expected_rows", "adaptation_note"
  )
  expect_setequal(names(manifest), required)
  expect_true(all(nzchar(manifest$source_url)))
  expect_true(all(grepl("^[0-9a-f]{64}$", manifest$source_sha256)))
  expect_true(all(nzchar(manifest$license_name)))
  expect_true(all(nzchar(manifest$publication_url)))
  expect_identical(
    stats::setNames(manifest$expected_rows, manifest$model_type),
    c(lm_2d = 151L, lm_3d = 425L, glm_binomial = 146L,
      glm_poisson = 4177L, glm_gamma = 270L, glmm = 4059L)
  )
})
```

- [ ] **Step 2: Run the test and confirm the manifest is missing**

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_example_manifest.R')"
```

Expected: FAIL because `data/real/manifest.csv` does not exist.

- [ ] **Step 3: Create the exact manifest**

Create `data/real/manifest.csv` with these six records. Quote every field so embedded commas remain valid CSV.

```csv
"example_id","model_type","title","source_file","source_url","source_sha256","source_doi","publication_url","publication_doi","license_name","license_url","default_link","response_source","predictor_x_source","predictor_y_source","group_source","response_label","predictor_x_label","predictor_y_label","expected_rows","adaptation_note"
"adelie_flipper_mass","lm_2d","Adélie penguin body mass","adelie.csv","https://pasta.lternet.edu/package/data/eml/knb-lter-pal/219/5/002f3893385f710df69eeebe893144ff","76a2b8eeadc052b31753e525115698785a68299d07a827d63867446579cb9138","10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f","https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0090081","10.1371/journal.pone.0090081","CC0 1.0","https://creativecommons.org/publicdomain/zero/1.0/","identity","Body Mass (g)","Flipper Length (mm)","","","Body mass (g)","Flipper length (mm)","","151","Descriptive within-species association; sex, island, and year are omitted."
"concrete_28d","lm_3d","28-day concrete compressive strength","concrete-compressive-strength.zip","https://archive.ics.uci.edu/static/public/165/concrete+compressive+strength.zip","dad85d14de8aee4e07479daa774e6b569a313715b71a3b92c95a07cf91c2c9a7","10.24432/C5PK67","https://doi.org/10.1016/S0008-8846(98)00165-3","10.1016/S0008-8846(98)00165-3","CC BY 4.0","https://creativecommons.org/licenses/by/4.0/","identity","Concrete compressive strength(MPa, megapascals) ","Cement (component 1)(kg in a m^3 mixture)","Water  (component 4)(kg in a m^3 mixture)","","Compressive strength (MPa)","Cement (kg/m³)","Water (kg/m³)","425","Educational additive plane at fixed age 28 days; the published engineering relationship is nonlinear and uses more ingredients."
"adelie_sex","glm_binomial","Adélie penguin sex from morphology","adelie.csv","https://pasta.lternet.edu/package/data/eml/knb-lter-pal/219/5/002f3893385f710df69eeebe893144ff","76a2b8eeadc052b31753e525115698785a68299d07a827d63867446579cb9138","10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f","https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0090081","10.1371/journal.pone.0090081","CC0 1.0","https://creativecommons.org/publicdomain/zero/1.0/","logit","Sex","Culmen Length (mm)","Body Mass (g)","","Probability molecular sex is female","Bill length (mm)","Body mass (g)","146","Full-data pedagogical fit of a paper-supported two-predictor model; the paper used splitting and model averaging."
"abalone_rings","glm_poisson","Abalone shell-ring count","abalone.data","https://archive.ics.uci.edu/ml/machine-learning-databases/abalone/abalone.data","de37cdcdcaaa50c309d514f248f7c2302a5f1f88c168905eba23fe2fbc78449f","10.24432/C55C7W","https://doi.org/10.1071/MF9880167","10.1071/MF9880167","CC BY 4.0","https://creativecommons.org/licenses/by/4.0/","log","Rings","Length","Shell_weight","","Expected ring count","Shell length (mm)","Dried shell weight (g)","4177","Associative Poisson mean model with moderate underdispersion and correlated size predictors."
"forest_fire_positive_area","glm_gamma","Positive forest-fire burned area","forestfires.csv","https://archive.ics.uci.edu/ml/machine-learning-databases/forest-fires/forestfires.csv","0d6586a1fa52f55bef48578aef14eb97273f1e9330e1a53423df497a77065253","10.24432/C5D88D","https://hdl.handle.net/1822/8039","","CC BY 4.0","https://creativecommons.org/licenses/by/4.0/","log","area","temp","RH","","Expected burned area given area > 0 (ha)","Temperature (°C)","Relative humidity (%)","270","Conditional severity model after excluding 247 zero-area records; not an occurrence model."
"inner_london_exam","glmm","Inner London examination achievement","mlmRev_1.0-8.tar.gz","https://cran.r-project.org/src/contrib/Archive/mlmRev/mlmRev_1.0-8.tar.gz","d57f3ff5d49e5f0079d4367cdbc1a273f48d8ce8f03bb82bb5f90606bfb2c452","10.32614/CRAN.package.mlmRev","https://doi.org/10.1080/0305498930190401","10.1080/0305498930190401","GPL-2-or-later","https://www.r-project.org/Licenses/GPL-2","identity","normexam","standLRT","schavg","school","Normalized examination achievement","Standardized London Reading Test","School mean intake score","4059","Two-continuous-predictor teaching specification of a richer published multilevel analysis."
```

- [ ] **Step 4: Add the provenance notice**

Create `data/real/NOTICE.md` listing the six example titles, publication and dataset DOIs, license links, the six research reports in `docs/`, and this explicit GLMM notice:

```markdown
The `inner_london_exam` source is distributed in `mlmRev` under GPL-2-or-later.
Its derived model-ready table remains identified as GPL-2-or-later data and is
distributed with source URL, archive checksum, and license link. This notice
does not relicense unrelated project code.
```

- [ ] **Step 5: Run and commit the contract**

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_example_manifest.R')"
git add data/real/manifest.csv data/real/NOTICE.md tests/test_example_manifest.R
git commit -m "feat: define scientific example manifest"
```

Expected: manifest test PASS; commit contains only manifest, notice, and test.

---

### Task 2: Guarded Source Retrieval

**Files:**
- Create: `scripts/fetch_real_examples.R`
- Create: `tests/test_example_sources.R`
- Create by script: `data/real/sources/adelie.csv`
- Create by script: `data/real/sources/concrete-compressive-strength.zip`
- Create by script: `data/real/sources/abalone.data`
- Create by script: `data/real/sources/forestfires.csv`
- Create by script: `data/real/sources/mlmRev_1.0-8.tar.gz`

**Interfaces:**
- Consumes: manifest columns `source_file`, `source_url`, and `source_sha256`.
- Produces: `sha256_file(path)`, `source_specs()`, `verify_source_file(path, expected)`, and `fetch_real_sources()` plus five reviewed offline source snapshots.

- [ ] **Step 1: Write failing checksum and source tests**

```r
# tests/test_example_sources.R
fetch_path <- file.path("..", "scripts", "fetch_real_examples.R")
if (file.exists(fetch_path)) source(fetch_path)

test_that("SHA-256 helper hashes file bytes", {
  file <- tempfile()
  on.exit(unlink(file), add = TRUE)
  writeBin(charToRaw("abc"), file)
  expect_identical(
    sha256_file(file),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
})

test_that("all reviewed sources exist and match the manifest", {
  specs <- source_specs("..")
  expect_equal(nrow(specs), 5L) # Adélie is shared by two examples.
  for (row in seq_len(nrow(specs))) {
    path <- file.path("..", "data", "real", "sources", specs$source_file[[row]])
    expect_true(file.exists(path), info = specs$source_file[[row]])
    expect_silent(verify_source_file(path, specs$source_sha256[[row]]))
  }
})
```

- [ ] **Step 2: Run red**

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_example_sources.R')"
```

Expected: FAIL because retrieval helpers and source files do not exist.

- [ ] **Step 3: Implement guarded retrieval**

```r
# scripts/fetch_real_examples.R
sha256_file <- function(path) {
  paste(as.character(digest::digest(path, algo = "sha256", file = TRUE)), collapse = "")
}

manifest_path <- function(root = ".") file.path(root, "data", "real", "manifest.csv")

source_specs <- function(root = ".") {
  manifest <- utils::read.csv(manifest_path(root), stringsAsFactors = FALSE,
                              check.names = FALSE)
  specs <- unique(manifest[c("source_file", "source_url", "source_sha256")])
  specs[order(specs$source_file), , drop = FALSE]
}

verify_source_file <- function(path, expected) {
  if (!file.exists(path)) stop("Missing reviewed source: ", path, call. = FALSE)
  actual <- sha256_file(path)
  if (!identical(tolower(actual), tolower(expected))) {
    stop("SHA-256 mismatch for ", basename(path), ": expected ", expected,
         ", got ", actual, call. = FALSE)
  }
  invisible(path)
}

fetch_real_sources <- function(destination = file.path("data", "real", "sources"),
                               root = ".") {
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  specs <- source_specs(root)
  for (row in seq_len(nrow(specs))) {
    target <- file.path(destination, specs$source_file[[row]])
    temporary <- tempfile(pattern = paste0(specs$source_file[[row]], "."))
    on.exit(unlink(temporary), add = TRUE)
    utils::download.file(specs$source_url[[row]], temporary,
                         mode = "wb", method = "libcurl", quiet = FALSE)
    verify_source_file(temporary, specs$source_sha256[[row]])
    if (!file.copy(temporary, target, overwrite = TRUE)) {
      stop("Could not install reviewed source: ", target, call. = FALSE)
    }
    verify_source_file(target, specs$source_sha256[[row]])
  }
  invisible(specs$source_file)
}

if (sys.nframe() == 0L) fetch_real_sources()
```

- [ ] **Step 4: Fetch, verify, and test**

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" scripts/fetch_real_examples.R
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_example_sources.R')"
```

Expected: five files downloaded; every SHA-256 assertion passes.

- [ ] **Step 5: Commit the reviewed snapshots**

```powershell
git add scripts/fetch_real_examples.R tests/test_example_sources.R data/real/sources
git commit -m "data: add verified scientific source snapshots"
```

---

### Task 3: Deterministic Preparation and Example Loader

**Files:**
- Create: `R/mod_examples.R`
- Create: `scripts/build_real_examples.R`
- Create: `tests/test_examples.R`
- Create by script: `data/real/<example-id>/model-data.csv` for six example IDs

**Interfaces:**
- Consumes: source snapshots, `model_config()`, `validate_simulation_data()`, and `fit_model()`.
- Produces: `read_example_manifest()`, `example_ids()`, `example_config()`, six `prepare_*()` functions, `build_real_examples()`, `load_real_example()`, and `example_for_model()`.

- [ ] **Step 1: Write the failing six-example contract**

```r
# tests/test_examples.R
source(file.path("..", "R", "mod_model.R"))
source(file.path("..", "R", "mod_simulation.R"))
examples_path <- file.path("..", "R", "mod_examples.R")
if (file.exists(examples_path)) source(examples_path)

test_that("six prepared examples load, validate, and fit", {
  expect_equal(length(example_ids()), 6L)
  for (id in example_ids()) {
    example <- load_real_example(id, root = "..")
    config <- example_config(id, root = "..")
    expect_equal(nrow(example$analysis), config$expected_rows)
    expect_silent(validate_simulation_data(example$analysis, config$model_type))
    fit <- fit_model(example$analysis, config$model_type, config$default_link)
    expect_equal(length(fitted_response(fit)), config$expected_rows)
    expect_true(all(is.finite(fitted_response(fit))))
    expect_true(all(is.finite(response_residuals(fit))))
  }
})

test_that("prepared examples satisfy their exact domains", {
  binomial <- load_real_example("adelie_sex", root = "..")$analysis
  poisson <- load_real_example("abalone_rings", root = "..")$analysis
  gamma <- load_real_example("forest_fire_positive_area", root = "..")$analysis
  mixed <- load_real_example("inner_london_exam", root = "..")$analysis
  expect_true(all(binomial$Z %in% c(0, 1)))
  expect_equal(table(binomial$Z), c(`0` = 73L, `1` = 73L))
  expect_true(all(poisson$Z == floor(poisson$Z) & poisson$Z >= 0))
  expect_true(all(gamma$Z > 0))
  expect_equal(nlevels(mixed$Group), 65L)
})
```

- [ ] **Step 2: Run red**

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_examples.R')"
```

Expected: FAIL because `example_ids()` and prepared snapshots do not exist.

- [ ] **Step 3: Implement manifest access and common helpers**

```r
# R/mod_examples.R
read_example_manifest <- function(root = ".") {
  manifest <- utils::read.csv(file.path(root, "data", "real", "manifest.csv"),
                              stringsAsFactors = FALSE, check.names = FALSE)
  manifest$expected_rows <- as.integer(manifest$expected_rows)
  manifest
}

example_ids <- function(root = ".") read_example_manifest(root)$example_id

example_config <- function(example_id, root = ".") {
  manifest <- read_example_manifest(root)
  match <- manifest[manifest$example_id == example_id, , drop = FALSE]
  if (nrow(match) != 1L) stop("Unknown real-data example: ", example_id,
                              call. = FALSE)
  as.list(match[1L, , drop = FALSE])
}

example_for_model <- function(model_type, root = ".") {
  manifest <- read_example_manifest(root)
  match <- manifest$example_id[manifest$model_type == model_type]
  if (length(match) != 1L) stop("No unique real-data example for model: ",
                                model_type, call. = FALSE)
  match[[1L]]
}

assert_source <- function(data, rows, columns, name) {
  if (!is.data.frame(data) || nrow(data) != rows ||
      !all(columns %in% names(data))) {
    stop("Unexpected ", name, " source schema", call. = FALSE)
  }
  invisible(data)
}

example_sha256_file <- function(path) {
  paste(as.character(digest::digest(path, algo = "sha256", file = TRUE)),
        collapse = "")
}

canonical_columns <- function(model_type) {
  config <- model_config(model_type)
  c("X", if (config$dimensions == 3L) "Y", "Z",
    if (config$requires_group) "Group")
}
```

- [ ] **Step 4: Implement the six exact preparations**

Add these functions to `R/mod_examples.R`. Each returned data frame retains source-role columns plus canonical columns.

```r
prepare_adelie_lm_2d <- function(path) {
  source <- utils::read.csv(path, check.names = FALSE, na.strings = "",
                            stringsAsFactors = FALSE)
  assert_source(source, 152L, c("Sample Number", "Flipper Length (mm)",
                                "Body Mass (g)"), "Adélie")
  keep <- is.finite(source[["Flipper Length (mm)"]]) &
    is.finite(source[["Body Mass (g)"]])
  out <- source[keep, c("Sample Number", "Flipper Length (mm)",
                        "Body Mass (g)"), drop = FALSE]
  out$X <- out[["Flipper Length (mm)"]]
  out$Z <- out[["Body Mass (g)"]]
  stopifnot(nrow(out) == 151L)
  out
}

prepare_adelie_binomial <- function(path) {
  source <- utils::read.csv(path, check.names = FALSE, na.strings = "",
                            stringsAsFactors = FALSE)
  assert_source(source, 152L, c("Sample Number", "Culmen Length (mm)",
                                "Body Mass (g)", "Sex"), "Adélie")
  keep <- is.finite(source[["Culmen Length (mm)"]]) &
    is.finite(source[["Body Mass (g)"]]) & source$Sex %in% c("FEMALE", "MALE")
  out <- source[keep, c("Sample Number", "Culmen Length (mm)",
                        "Body Mass (g)", "Sex"), drop = FALSE]
  out <- out[order(as.numeric(out[["Sample Number"]])), , drop = FALSE]
  out$X <- out[["Culmen Length (mm)"]]
  out$Y <- out[["Body Mass (g)"]]
  out$Z <- as.integer(out$Sex == "FEMALE")
  stopifnot(nrow(out) == 146L, identical(table(out$Z), c(`0` = 73L, `1` = 73L)))
  out
}

prepare_concrete_28d <- function(path) {
  extract <- tempfile("concrete-")
  dir.create(extract)
  on.exit(unlink(extract, recursive = TRUE), add = TRUE)
  utils::unzip(path, files = "Concrete_Data.xls", exdir = extract)
  workbook <- file.path(extract, "Concrete_Data.xls")
  if (!identical(example_sha256_file(workbook),
                 "710076c66b9ca3f8050e7942f3dcbdbe04013534daeb0077ffd3079a52d8e0c4")) {
    stop("Unexpected Concrete_Data.xls checksum", call. = FALSE)
  }
  source <- as.data.frame(readxl::read_excel(
    workbook, .name_repair = "minimal"
  ), check.names = FALSE)
  if (nrow(source) != 1030L || ncol(source) != 9L) {
    stop("Unexpected concrete source schema", call. = FALSE)
  }
  source <- source[source[[8L]] == 28, , drop = FALSE]
  out <- data.frame(
    source_row = as.integer(rownames(source)), cement_kg_m3 = source[[1L]],
    water_kg_m3 = source[[4L]], strength_mpa = source[[9L]],
    X = source[[1L]], Y = source[[4L]], Z = source[[9L]],
    check.names = FALSE
  )
  stopifnot(nrow(out) == 425L, all(is.finite(as.matrix(out[c("X", "Y", "Z")]))))
  out
}

prepare_abalone_poisson <- function(path) {
  names <- c("Sex", "Length", "Diameter", "Height", "Whole_weight",
             "Shucked_weight", "Viscera_weight", "Shell_weight", "Rings")
  source <- utils::read.csv(path, header = FALSE, col.names = names,
                            stringsAsFactors = FALSE)
  assert_source(source, 4177L, names, "abalone")
  out <- data.frame(
    source_row = seq_len(nrow(source)), length_mm = 200 * source$Length,
    shell_weight_g = 200 * source$Shell_weight, rings = source$Rings,
    X = 200 * source$Length, Y = 200 * source$Shell_weight, Z = source$Rings
  )
  stopifnot(all(out$Z == floor(out$Z)), all(out$Z >= 0))
  out
}

prepare_forest_fire_gamma <- function(path) {
  source <- utils::read.csv(path, stringsAsFactors = FALSE)
  assert_source(source, 517L, c("temp", "RH", "area"), "forest fire")
  source <- source[source$area > 0, , drop = FALSE]
  out <- data.frame(
    source_row = as.integer(rownames(source)), temp_c = source$temp,
    rh_pct = source$RH, area_ha = source$area,
    X = source$temp, Y = source$RH, Z = source$area
  )
  stopifnot(nrow(out) == 270L, all(out$Z > 0))
  out
}

prepare_inner_london_glmm <- function(path) {
  extract <- tempfile("mlmRev-")
  dir.create(extract)
  on.exit(unlink(extract, recursive = TRUE), add = TRUE)
  utils::untar(path, files = "mlmRev/data/Exam.rda", exdir = extract)
  exam_path <- file.path(extract, "mlmRev", "data", "Exam.rda")
  if (!identical(example_sha256_file(exam_path),
                 "2b373e72be15b68bafd7ba8515e408b75404a61db44a5d5b4b3474b3b11e01e9")) {
    stop("Unexpected Exam.rda checksum", call. = FALSE)
  }
  environment <- new.env(parent = emptyenv())
  load(exam_path, envir = environment)
  source <- get("Exam", envir = environment)
  expected <- c("school", "normexam", "schgend", "schavg", "vr", "intake",
                "standLRT", "sex", "type", "student")
  assert_source(source, 4059L, expected, "mlmRev Exam")
  group <- factor(as.character(source$school),
                  levels = as.character(sort(as.numeric(levels(source$school)))))
  out <- data.frame(
    source_row = seq_len(nrow(source)), standLRT = source$standLRT,
    schavg = source$schavg, normexam = source$normexam,
    school = as.character(source$school), X = source$standLRT,
    Y = source$schavg, Z = source$normexam, Group = group
  )
  stopifnot(nrow(out) == 4059L, nlevels(out$Group) == 65L)
  out
}
```

- [ ] **Step 5: Implement building and loading**

```r
build_real_examples <- function(root = ".") {
  sources <- file.path(root, "data", "real", "sources")
  builders <- list(
    adelie_flipper_mass = function() prepare_adelie_lm_2d(file.path(sources, "adelie.csv")),
    concrete_28d = function() prepare_concrete_28d(file.path(sources, "concrete-compressive-strength.zip")),
    adelie_sex = function() prepare_adelie_binomial(file.path(sources, "adelie.csv")),
    abalone_rings = function() prepare_abalone_poisson(file.path(sources, "abalone.data")),
    forest_fire_positive_area = function() prepare_forest_fire_gamma(file.path(sources, "forestfires.csv")),
    inner_london_exam = function() prepare_inner_london_glmm(file.path(sources, "mlmRev_1.0-8.tar.gz"))
  )
  for (id in names(builders)) {
    data <- builders[[id]]()
    config <- example_config(id, root)
    analysis <- data[canonical_columns(config$model_type)]
    if ("Group" %in% names(analysis)) analysis$Group <- factor(analysis$Group)
    validate_simulation_data(analysis, config$model_type)
    stopifnot(nrow(data) == config$expected_rows)
    output <- file.path(root, "data", "real", id)
    dir.create(output, recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(data, file.path(output, "model-data.csv"), row.names = FALSE)
  }
  invisible(names(builders))
}

load_real_example <- function(example_id, root = ".") {
  config <- example_config(example_id, root)
  path <- file.path(root, "data", "real", example_id, "model-data.csv")
  data <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  analysis <- data[canonical_columns(config$model_type)]
  if ("Group" %in% names(analysis)) analysis$Group <- factor(analysis$Group)
  validate_simulation_data(analysis, config$model_type)
  if (nrow(data) != config$expected_rows) stop("Unexpected prepared row count", call. = FALSE)
  list(
    id = example_id,
    analysis = analysis,
    display = data[setdiff(names(data), c("X", "Y", "Z", "Group")), drop = FALSE],
    metadata = config
  )
}
```

Create `scripts/build_real_examples.R`:

```r
source("R/mod_model.R")
source("R/mod_simulation.R")
source("R/mod_examples.R")
build_real_examples(".")
```

- [ ] **Step 6: Build, test, and commit**

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" scripts/build_real_examples.R
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_examples.R')"
git add R/mod_examples.R scripts/build_real_examples.R tests/test_examples.R data/real/*/model-data.csv
git commit -m "feat: prepare six scientific example datasets"
```

Expected: six examples validate and fit; prepared row counts are 151, 425, 146, 4177, 270, and 4059.

---

### Task 4: Scientific Plot Labels, Enriched Data, and Static Exports

**Files:**
- Modify: `R/mod_examples.R`
- Create: `scripts/export_real_example_plots.R`
- Modify: `tests/test_examples.R`
- Create by script: `artifacts/real-examples/*.png`

**Interfaces:**
- Consumes: `load_real_example()`, `fit_model()`, `build_main_plot()`, `fitted_response()`, and `response_residuals()`.
- Produces: `example_plot()`, `enrich_real_example()`, and `export_real_example_png()`.

- [ ] **Step 1: Add failing plot and enrichment tests**

```r
source(file.path("..", "R", "mod_visualization.R"))

test_that("every real example has scientific labels and enriched rows", {
  for (id in example_ids("..")) {
    example <- load_real_example(id, "..")
    fit <- fit_model(example$analysis, example$metadata$model_type,
                     example$metadata$default_link)
    plot <- example_plot(example, fit)
    expect_s3_class(plot, "plotly")
    expect_match(plot$x$layout$title$text, example$metadata$title, fixed = TRUE)
    enriched <- enrich_real_example(example, fit)
    expect_equal(nrow(enriched), nrow(example$analysis))
    expect_true(all(c(".fitted", ".residual") %in% names(enriched)))
    expect_true(all(is.finite(enriched$.fitted)))
  }
})
```

- [ ] **Step 2: Run red**

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_examples.R')"
```

Expected: FAIL because `example_plot()` is missing.

- [ ] **Step 3: Implement the common wrappers**

```r
enrich_real_example <- function(example, fit) {
  enriched <- example$display
  enriched$.fitted <- fitted_response(fit)
  enriched$.residual <- response_residuals(fit)
  enriched
}

example_plot <- function(example, fit, show_surface = TRUE) {
  metadata <- example$metadata
  plot <- build_main_plot(example$analysis, fit, metadata$model_type,
                          show_surface = show_surface)
  citation <- if (nzchar(metadata$publication_doi)) {
    paste0("Publication DOI: ", metadata$publication_doi)
  } else {
    paste0("Publication: ", metadata$publication_url)
  }
  if (model_config(metadata$model_type)$dimensions == 2L) {
    plotly::layout(
      plot,
      title = list(text = paste0(metadata$title, "<br><sup>", citation, "</sup>")),
      xaxis = list(title = metadata$predictor_x_label),
      yaxis = list(title = metadata$response_label)
    )
  } else {
    plotly::layout(
      plot,
      title = list(text = paste0(metadata$title, "<br><sup>", citation, "</sup>")),
      scene = list(
        xaxis = list(title = metadata$predictor_x_label),
        yaxis = list(title = metadata$predictor_y_label),
        zaxis = list(title = metadata$response_label)
      )
    )
  }
}

export_real_example_png <- function(example, fit, file, width = 1200L,
                                    height = 800L) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  html <- tempfile(fileext = ".html")
  on.exit(unlink(html), add = TRUE)
  htmlwidgets::saveWidget(example_plot(example, fit), html,
                          selfcontained = TRUE)
  webshot2::webshot(html, file = file, vwidth = width, vheight = height,
                    delay = 0.5)
  if (!file.exists(file) || file.info(file)$size == 0) {
    stop("Static plot export failed: ", file, call. = FALSE)
  }
  invisible(file)
}
```

- [ ] **Step 4: Create and run the export script**

```r
# scripts/export_real_example_plots.R
source("R/mod_model.R")
source("R/mod_simulation.R")
source("R/mod_visualization.R")
source("R/mod_examples.R")

for (id in example_ids()) {
  example <- load_real_example(id)
  fit <- fit_model(example$analysis, example$metadata$model_type,
                   example$metadata$default_link)
  export_real_example_png(
    example, fit,
    file.path("artifacts", "real-examples", paste0(id, ".png"))
  )
}
```

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_examples.R')"
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" scripts/export_real_example_plots.R
```

Expected: tests PASS and six non-empty PNG files are created.

- [ ] **Step 5: Visually inspect and commit all six plots**

Open each PNG and verify title, axes, units, point/surface readability, clipping, and citation. Fix shared plotting code and regenerate all six after any defect.

```powershell
git add R/mod_examples.R scripts/export_real_example_plots.R tests/test_examples.R artifacts/real-examples
git commit -m "feat: plot scientific real-data examples"
```

---

### Task 5: Shiny Real-Data Mode

**Files:**
- Modify: `app.R`
- Modify: `www/style.css`
- Modify: `tests/test_server.R`
- Modify: `tests/test_app.R`

**Interfaces:**
- Consumes: `example_for_model()`, `load_real_example()`, `example_plot()`, and `enrich_real_example()`.
- Produces: source selector, provenance card, literature-backed link labels, shared Generate & Fit flow, and offline real-data downloads.

- [ ] **Step 1: Add failing UI/server assertions**

Add to `tests/test_server.R`:

```r
test_that("UI exposes simulation and real-data sources", {
  rendered <- htmltools::renderTags(ui)
  html <- paste(rendered$head, rendered$html, collapse = "\n")
  expect_match(html, "data_source", fixed = TRUE)
  expect_match(html, "Real data", fixed = TRUE)
  expect_match(html, "example_info", fixed = TRUE)
})

test_that("server fits every real-data example", {
  shiny::testServer(server, {
    for (model_type in model_ids()) {
      session$setInputs(model_type = model_type, data_source = "real")
      session$setInputs(generate = isolate(input$generate %||% 0L) + 1L)
      session$flushReact()
      expect_false(is.null(output$main_plot), info = model_type)
      info <- paste(as.character(output$example_info), collapse = "\n")
      expect_match(info, "License", fixed = TRUE,
                   info = model_type)
      expect_false(is.null(output$data_table), info = model_type)
    }
  })
})
```

- [ ] **Step 2: Run red**

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_server.R')"
```

Expected: FAIL because source selector and provenance output are absent.

- [ ] **Step 3: Add source controls and provenance card**

In the sidebar after the model selector, add:

```r
shiny::radioButtons(
  "data_source", "Data source",
  choices = c("Simulation" = "simulation", "Real data" = "real"),
  selected = "simulation", inline = TRUE
),
shiny::uiOutput("example_info")
```

Wrap `sim_ui("simulation")` in:

```r
shiny::conditionalPanel("input.data_source === 'simulation'", sim_ui("simulation"))
```

Source `R/mod_examples.R` in `app.R`.

- [ ] **Step 4: Implement model-aware links and provenance**

Replace the link UI renderer with:

```r
output$link_ui <- renderUI({
  config <- model_config(input$model_type)
  real <- identical(input$data_source, "real")
  default <- config$default_link
  choices <- config$links
  if (real) {
    example <- example_config(example_for_model(input$model_type))
    default <- example$default_link
    choices <- stats::setNames(
      config$links,
      ifelse(config$links == default,
             paste0(config$links, " (literature-backed)"),
             paste0(config$links, " (exploratory)"))
    )
  }
  if (length(config$links) == 1L) {
    return(tags$input(id = "link_sel", type = "hidden", value = default))
  }
  selectInput("link_sel", "Link", choices = choices, selected = default)
})

output$example_info <- renderUI({
  req(identical(input$data_source, "real"))
  metadata <- example_config(example_for_model(input$model_type))
  publication_label <- if (nzchar(metadata$publication_doi)) {
    metadata$publication_doi
  } else {
    metadata$publication_url
  }
  bslib::card(
    class = "example-provenance",
    bslib::card_header(metadata$title),
    tags$p(metadata$adaptation_note),
    tags$dl(
      tags$dt("Publication"), tags$dd(tags$a(href = metadata$publication_url,
                                                target = "_blank", publication_label)),
      tags$dt("Dataset"), tags$dd(tags$a(href = metadata$source_url,
                                            target = "_blank", metadata$source_doi)),
      tags$dt("License"), tags$dd(tags$a(href = metadata$license_url,
                                            target = "_blank", metadata$license_name)),
      tags$dt("Rows"), tags$dd(format(metadata$expected_rows, big.mark = ","))
    )
  )
})
```

- [ ] **Step 5: Route Generate & Fit through the common pipeline**

Replace the beta plan's `observeEvent(simulation(), ...)` with
`observeEvent(input$generate, ...)`. The simulation event-reactive remains lazy,
so real-data mode does not generate simulated data. Choose the source before
calling `fit_model()`:

```r
if (identical(input$data_source, "real")) {
  example <- load_real_example(example_for_model(input$model_type))
  generated <- list(
    data = example$analysis,
    display = example$display,
    example = example,
    code = paste0(
      "example <- load_real_example(\"", example$id, "\")\n",
      "fit <- fit_model(example$analysis, \"", input$model_type,
      "\", \"", selected_link(), "\")"
    )
  )
} else {
  simulated <- simulation()
  generated <- list(data = simulated$data, display = simulated$data,
                    example = NULL, code = simulated$code)
}
fit <- fit_model(generated$data, input$model_type, selected_link())
last_result(list(
  data = generated$data, display = generated$display,
  example = generated$example, fit = fit,
  model_type = input$model_type, link = selected_link(),
  code = generated$code
))
```

Render the plot and table with:

```r
output$main_plot <- plotly::renderPlotly({
  result <- last_result(); req(result)
  if (!is.null(result$example)) {
    example_plot(result$example, result$fit, input$show_surface)
  } else {
    build_main_plot(result$data, result$fit, result$model_type,
                    input$show_surface)
  }
})

display_result <- function(result) {
  if (!is.null(result$example)) enrich_real_example(result$example, result$fit)
  else enrich_data(result$data, result$fit)
}

output$data_table <- DT::renderDT({
  result <- last_result(); req(result)
  DT::datatable(display_result(result), options = list(pageLength = 8))
})
```

Use `display_result(result)` in the CSV download handler as well.

- [ ] **Step 6: Style and test all six real modes**

Add to `www/style.css`:

```css
.example-provenance { font-size: .9rem; }
.example-provenance dl { display: grid; grid-template-columns: 5.5rem 1fr; gap: .2rem .6rem; }
.example-provenance dt { color: #475569; }
.example-provenance dd { margin: 0; overflow-wrap: anywhere; }
```

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_server.R'); testthat::test_file('tests/test_examples.R')"
```

Expected: all six real-data modes fit, plot, display provenance, and provide enriched rows.

- [ ] **Step 7: Extend and run the browser smoke test**

In `tests/test_app.R`, loop over all six model IDs, set `data_source = "real"`, click `generate`, wait for idle, and assert non-null `main_plot`, `model_summary`, and `data_table` plus zero Shiny/JavaScript error logs.

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_app.R')"
```

Expected: PASS without skip.

- [ ] **Step 8: Commit Shiny integration**

```powershell
git add app.R www/style.css tests/test_server.R tests/test_app.R
git commit -m "feat: integrate scientific data into Shiny"
```

---

### Task 6: Per-Example Documentation and Offline Acceptance

**Files:**
- Create: `data/real/<example-id>/README.md` for all six IDs
- Modify: `README.md`
- Modify: `renv.lock`
- Create: `tests/test_real_data_acceptance.R`

**Interfaces:**
- Consumes: manifest, prepared data, source snapshots, real-data Shiny mode, and static graphs.
- Produces: complete citations/license/transformation documentation and final offline acceptance evidence.

- [ ] **Step 1: Write the failing documentation and acceptance test**

```r
# tests/test_real_data_acceptance.R
source(file.path("..", "R", "mod_model.R"))
source(file.path("..", "R", "mod_simulation.R"))
source(file.path("..", "R", "mod_visualization.R"))
source(file.path("..", "R", "mod_examples.R"))

test_that("all six examples have complete offline artifacts", {
  for (id in example_ids("..")) {
    example <- load_real_example(id, "..")
    metadata <- example$metadata
    readme <- file.path("..", "data", "real", id, "README.md")
    png <- file.path("..", "artifacts", "real-examples", paste0(id, ".png"))
    expect_true(file.exists(readme), info = id)
    text <- paste(readLines(readme, warn = FALSE), collapse = "\n")
    expect_match(text, metadata$publication_url, fixed = TRUE)
    expect_match(text, metadata$source_url, fixed = TRUE)
    expect_match(text, metadata$license_url, fixed = TRUE)
    expect_true(file.exists(png), info = id)
    expect_gt(file.info(png)$size, 10000, info = id)
    fit <- fit_model(example$analysis, metadata$model_type,
                     metadata$default_link)
    expect_s3_class(example_plot(example, fit), "plotly")
  }
})
```

- [ ] **Step 2: Run red**

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_file('tests/test_real_data_acceptance.R')"
```

Expected: FAIL because per-example README files are absent.

- [ ] **Step 3: Write the six evidence README files**

For each example, copy the complete verified research report, which already contains the publication, dataset, license, schema, deterministic mapping, formula/link, row exclusions, units, adaptation statement, and interpretation limits:

```powershell
Copy-Item -LiteralPath 'docs\research-real-example-lm-2d.md' -Destination 'data\real\adelie_flipper_mass\README.md'
Copy-Item -LiteralPath 'docs\research-real-example-lm-3d.md' -Destination 'data\real\concrete_28d\README.md'
Copy-Item -LiteralPath 'docs\research-real-example-glm-binomial.md' -Destination 'data\real\adelie_sex\README.md'
Copy-Item -LiteralPath 'docs\research-real-example-glm-poisson.md' -Destination 'data\real\abalone_rings\README.md'
Copy-Item -LiteralPath 'docs\research-real-example-glm-gamma.md' -Destination 'data\real\forest_fire_positive_area\README.md'
Copy-Item -LiteralPath 'docs\research-real-example-glmm.md' -Destination 'data\real\inner_london_exam\README.md'
```

Each README must contain the exact manifest `publication_url`, `source_url`, and `license_url` verbatim so the acceptance test verifies them.

- [ ] **Step 4: Document the feature and snapshot dependencies**

Add a `Scientific real-data examples` section to `README.md` with the six titles, model family, default link, rows, publication DOI/URL, dataset DOI, and license. Document that the app runs offline and that `scripts/fetch_real_examples.R`, `scripts/build_real_examples.R`, and `scripts/export_real_example_plots.R` rebuild all artifacts.

Run:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "renv::snapshot(prompt=FALSE, type='all')"
```

Expected: `renv.lock` records `digest`, `readxl`, `htmlwidgets`, and `webshot2` in addition to beta dependencies.

- [ ] **Step 5: Run complete automated verification**

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "testthat::test_dir('tests', reporter='summary')"
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" scripts/build_real_examples.R
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" scripts/export_real_example_plots.R
git diff --exit-code -- data/real/*/model-data.csv artifacts/real-examples
```

Expected: zero failures/errors/skips; deterministic rebuild produces no diff.

- [ ] **Step 6: Run an offline Shiny smoke test**

Temporarily disable network access for the child Shiny process or run with an invalid HTTP proxy, launch `shiny::runApp('.', host='127.0.0.1', port=48761, launch.browser=FALSE)`, exercise all six real-data models with `shinytest2`, and confirm HTTP 200 with no download attempt in logs. Always terminate only the spawned process.

Expected: all six real examples work with no network access.

- [ ] **Step 7: Final visual and repository audit**

Inspect all six freshly generated PNGs and the six browser cases. Confirm scientific titles/units, response-scale surfaces, readable group presentation, visible citations, correct default-link labels, and no misleading causal copy.

```powershell
git status --short
git diff --check master...HEAD
```

Expected: no Graphify output, temporary downloads, browser screenshots, server logs, or unrelated changes are staged for the feature.

- [ ] **Step 8: Commit final documentation and acceptance evidence**

```powershell
git add data/real/*/README.md README.md renv.lock tests/test_real_data_acceptance.R
git commit -m "docs: verify reproducible scientific examples"
```

---

## Execution Order and Review Gates

1. Complete the beta prerequisite and require its 12-combination acceptance test.
2. Review the manifest and license decisions before downloading or bundling data.
3. Review source checksums before preparing derived snapshots.
4. Review each preprocessing function against its committed research report.
5. Review all six fits and plots before exposing them in Shiny.
6. Review Shiny behavior in unit and real-browser tests.
7. Regenerate all artifacts and require a clean deterministic diff before completion.

Each task receives a specification review followed by a code-quality review before the next task begins.
