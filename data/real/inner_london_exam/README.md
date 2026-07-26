# Real-data research report: `glmm`

**Recommendation:** use the `mlmRev::Exam` Inner London schools data to model normalized examination achievement from a student's standardized London Reading Test score and the school's average intake score, with a random intercept for school. In the beta registry this mode is called `glmm`, but the implemented model is specifically a **Gaussian linear mixed model**.

## 1. Preferred scientific case

Goldstein, Rasbash, Yang, Woodhouse, Pan, Nuttall, and Thomas (1993), *A Multilevel Analysis of School Examination Results*, Oxford Review of Education 19(4): 425–433, is the primary peer-reviewed publication ([University of Bristol publication record](https://research-information.bris.ac.uk/en/publications/a-multilevel-analysis-of-school-examination-results/); [DOI: 10.1080/0305498930190401](https://doi.org/10.1080/0305498930190401)). The paper analyzes examination results from Inner London schools in relation to intake achievement, pupil gender, and school type; explicitly fits multilevel models so that between-school variation can be studied; and cautions against fine school rankings because school-effect uncertainty is substantial ([publisher abstract](https://www.tandfonline.com/doi/abs/10.1080/0305498930190401)).

The archived `mlmRev` package connects its `Exam` object directly to that paper and documents 4,059 students in 65 schools ([official CRAN package manual, `Exam`](https://stat.ethz.ch/CRAN/web/packages/mlmRev/mlmRev.pdf)). Its accompanying multilevel-software review describes the response as continuous, motivates normal observation noise and normal random effects, and fits a school random-intercept model to these data ([official package vignette](https://stat.ethz.ch/CRAN/web/packages/mlmRev/vignettes/MlmSoftRev.pdf)). Thus the case is substantive evidence for the response, hierarchy, Gaussian mixed-model family, and school grouping—not merely a thematically similar dataset.

## 2. Authoritative data, direct download, and license

`mlmRev` version 1.0-8 is archived by CRAN. Use the versioned source bundle, not an `Rdatasets`/GitHub mirror:

| Item | Exact location |
|---|---|
| Dataset/package page | [`mlmRev` CRAN record](https://cran.r-project.org/package=mlmRev) |
| Stable archive index | [CRAN `mlmRev` archive](https://cran.r-project.org/src/contrib/Archive/mlmRev/) |
| Direct machine-readable download | [`mlmRev_1.0-8.tar.gz`](https://cran.r-project.org/src/contrib/Archive/mlmRev/mlmRev_1.0-8.tar.gz) |
| Data object within bundle | `mlmRev/data/Exam.rda` |
| Package DOI | [10.32614/CRAN.package.mlmRev](https://doi.org/10.32614/CRAN.package.mlmRev) |
| Dataset documentation | [`Exam` entry in the official manual](https://stat.ethz.ch/CRAN/web/packages/mlmRev/mlmRev.pdf) |
| Declared license | `GPL (>= 2)` in the archived bundle's `DESCRIPTION`; [GPL-2 text](https://www.r-project.org/Licenses/GPL-2) |

The archived source bundle declares `License: GPL (>= 2)` and does not declare a separate license for `Exam.rda`. Conservatively, redistribute the source or derived model-ready data as **GPL-2-or-later**, preserve the copyright/license notice, and provide corresponding source/provenance. This is open-source-compatible and permits bundling in a GPL-compatible open-source distribution, but it is copyleft rather than permissive; the project owner should confirm repository-level license compatibility before merging the data asset.

The direct archive download was retrieved during this review:

- tarball: 1,490,419 bytes; SHA-256 `d57f3ff5d49e5f0079d4367cdbc1a273f48d8ce8f03bb82bb5f90606bfb2c452`;
- embedded `mlmRev/data/Exam.rda`: 17,548 bytes; SHA-256 `2b373e72be15b68bafd7ba8515e408b75404a61db44a5d5b4b3474b3b11e01e9`.

Record both hashes. A mismatch must stop rebuilding rather than silently replacing the reviewed dataset.

## 3. Inspected schema, ranges, groups, and missingness

The actual archived R object was loaded with R 4.6.0 and inspected directly.

- Shape: **4,059 rows × 10 columns**.
- Source columns: `school`, `normexam`, `schgend`, `schavg`, `vr`, `intake`, `standLRT`, `sex`, `type`, `student`.
- Missingness: **zero missing values in every column**; all three selected numeric columns are finite.
- Grouping: `school` is a factor with **65 observed levels**. Group sizes range from **2 to 198** students.

The manual's prose says "9 variables" while listing ten; the archived object and official vignette both show ten. Integration should assert the real ten-column schema rather than reproduce that documentation typo.

| Model role | Source field | Definition / unit | Observed range | Missing |
|---|---|---|---:|---:|
| Z | `normexam` | normalized examination achievement; source-defined standard-score scale, no physical unit | -3.666072 to 3.666091 | 0 |
| X | `standLRT` | standardized London Reading Test score at intake; standard-score scale | -2.934953 to 3.015952 | 0 |
| Y | `schavg` | school average intake score; source-derived centered/standard-score scale | -0.755961 to 0.637656 | 0 |
| Group | `school` | school identifier | 65 levels | 0 |

`schavg` is constant within a school and varies between schools, whereas `standLRT` varies primarily between students. The two axes therefore have a useful multilevel interpretation: individual prior attainment and school intake context.

## 4. Exact beta-compatible model

Canonical mapping:

```text
X     = standLRT
Y     = schavg
Z     = normexam
Group = school
```

Fit exactly:

```r
lme4::lmer(
  Z ~ X + Y + (1 | Group),
  data = model_data,
  REML = TRUE
)
```

or, on the source names:

```r
lme4::lmer(
  normexam ~ standLRT + schavg + (1 | school),
  data = Exam,
  REML = TRUE
)
```

The statistical model is

\[
Z_{ij}=\beta_0+\beta_1 X_{ij}+\beta_2 Y_j+b_{0j}+\epsilon_{ij},
\qquad b_{0j}\sim N(0,\sigma_b^2),\quad
\epsilon_{ij}\sim N(0,\sigma^2),
\]

where student `i` is nested in school `j`. The school random intercept accounts for residual similarity among students sharing a school and estimates between-school heterogeneity after the two fixed effects. This matches the publication's reason for multilevel modeling: separating student-level relationships from variation between schools.

The 3D population surface must exclude school effects:

```r
predict(fit, newdata = grid, re.form = NA)
```

so its height is `beta_0 + beta_1 * X + beta_2 * Y`. Fitted values and residuals for observed rows should retain `b_0j`; observed points can be colored by `Group`.

As a QA calculation, the reviewed model used all 4,059 rows, was nonsingular, and estimated fixed effects approximately `(Intercept) = 0.01195`, `standLRT = 0.55948`, and `schavg = 0.35766`. Estimated school-intercept variance was `0.07899` and residual variance `0.56604`. These are rebuild checks, not published coefficients.

## 5. Published model versus pedagogical adaptation

This is a scientifically grounded **pedagogical adaptation**, not an exact reproduction of Goldstein et al. The paper and the package vignette consider richer specifications involving intake achievement, pupil sex, school gender/type, heteroscedasticity, subject-specific outcomes, and other multilevel structures. The package vignette's first worked fit is `normexam ~ standLRT + sex + schgend + (1 | school)`, not the explorer formula.

The explorer intentionally substitutes the continuous school-context variable `schavg` for categorical covariates so that the beta's fixed `X + Y` contract yields a meaningful 3D plane. It preserves the published continuous response, prior-achievement predictor, school hierarchy, Gaussian mixed-model logic, and random-intercept interpretation. UI copy and the example README must call it a two-predictor teaching specification and must not claim reproduction of the paper's estimates or school effects.

## 6. Deterministic preparation to X, Y, Z, Group

1. Download the exact CRAN archive tarball and verify SHA-256 `d57f3ff5d49e5f0079d4367cdbc1a273f48d8ce8f03bb82bb5f90606bfb2c452`.
2. Extract only `mlmRev/data/Exam.rda`; verify SHA-256 `2b373e72be15b68bafd7ba8515e408b75404a61db44a5d5b4b3474b3b11e01e9`.
3. Load the object in a clean R environment and assert it is a 4,059-row, 10-column data frame with the exact ordered column names listed above.
4. Select `standLRT`, `schavg`, `normexam`, and `school` in source-row order. Do not filter on unused variables.
5. Assert the three numeric values are finite and non-missing. No row should be dropped; assert 4,059 output rows.
6. Convert `school` to a character label without interpreting it numerically, then to a factor with deterministic levels ordered by numeric school ID. Rename it `Group`.
7. Rename `standLRT` to `X`, `schavg` to `Y`, and `normexam` to `Z`. Retain the original variable labels and scale descriptions in metadata.
8. Assert 65 observed groups, group sizes 2–198, nonzero variance in X/Y/Z, and no missing canonical values. Fit the exact formula above and fail the build if the fit is singular or nonconvergent.

No person-level identifiers are needed in the bundled model-ready file. In particular, omit `student`: the official vignette notes that it is not globally unique and has four duplicated school/student combinations. This anomaly does not affect the school-random-intercept model, but it is a reason not to expose or use that field.

## 7. Fully verified fallback

If the `Exam` case is rejected, use `mlmRev::Hsb82` from the same versioned archive. It supplies a classic contextual-effects model of mathematics achievement with student-centered and school-mean socioeconomic predictors.

Scientific source: Lee and Bryk (1989), *A Multilevel Model of the Social Distribution of High School Achievement*, Sociology of Education 62(3): 172–192 ([ERIC record](https://eric.ed.gov/?id=EJ397167); [DOI: 10.2307/2112866](https://doi.org/10.2307/2112866)). The peer-reviewed article uses High School and Beyond data and hierarchical linear modeling to study mathematics achievement across students and schools.

| Item | Verified fallback detail |
|---|---|
| Data object | `mlmRev/data/Hsb82.rda` in the same [versioned CRAN tarball](https://cran.r-project.org/src/contrib/Archive/mlmRev/mlmRev_1.0-8.tar.gz) |
| Object checksum | SHA-256 `27d83e57ae094eb50b89e0a1b60faa69476c991723f69e5fa6153d4e1e3892bb` |
| License | Same package-level `GPL (>= 2)`; [GPL-2 text](https://www.r-project.org/Licenses/GPL-2) |
| Schema | 7,185 rows × 8 columns: `school`, `minrty`, `sx`, `ses`, `mAch`, `meanses`, `sector`, `cses` |
| Missingness | 0 in all fields |
| Groups | 160 schools; 14–67 students per school |
| Mapping | X=`cses` (-3.650741 to 2.856078); Y=`meanses` (-1.193946 to 0.824983); Z=`mAch` (-2.832 to 24.993); Group=`school` |
| Formula | `lmer(Z ~ X + Y + (1 | Group), REML = TRUE)` |

The fallback fit used all rows, was nonsingular, and estimated nonzero school-intercept variance (`2.6925`). It is not preferred because 160 group colors are even harder to read, and the packaged 7,185-row teaching subset is smaller than the samples described in the historical papers; provenance to the exact published analysis is therefore less direct than for `Exam`.

## 8. Risks and integration cautions

1. **Copyleft license:** the data are distributed in a GPL-2-or-later package, not under CC0/CC-BY. Bundling is suitable for a GPL-compatible open-source release but requires retaining GPL terms and source/provenance; resolve repository-license compatibility first.
2. **Pedagogical simplification:** `standLRT + schavg + (1|school)` is not the paper's full published model. Label it explicitly as an explorer adaptation.
3. **Standard-score axes:** all three plotted variables are normalized/standardized or source-derived score scales, not physical measurements. Axis labels must say so.
4. **Dense grouping:** 65 school colors can overwhelm a legend. Preserve group color and tooltips as required, but suppress or scroll the full legend in static/interactive presentation rather than pretending colors are individually memorable.
5. **Small group:** school 48 has only two observations; the package vignette flags it for unreliable within-school graphical estimates but retains it in comprehensive models. Keep it for deterministic parity and avoid school-specific inference.
6. **Known ID anomalies:** `student` is not globally unique and four school/student combinations are duplicated. It is unused and must be omitted from the model-ready snapshot.
7. **No causal or ranking claim:** associations with intake achievement and school context are observational. The paper itself warns that fine school ranking is unreliable.
8. **Prediction support:** render the population plane only over observed X/Y ranges. Because `schavg` is group-level, combinations at sparse corners may have little empirical support even within the rectangular grid.

## Final selection

Select **Inner London normalized exam achievement: `standLRT + schavg + (1 | school)`**. It provides a continuous Gaussian response, two quantitative and scientifically interpretable predictors at student and school levels, 65 genuine clusters, no missingness, a stable nonsingular random-intercept fit, an authoritative versioned machine-readable source, and direct peer-reviewed justification for multilevel modeling of between-school variation. Use `Hsb82` only as the fully verified fallback.
