# Real-data research report: `glm_binomial`

**Recommendation:** use the Palmer Station LTER **Adélie penguin sex-from-morphology** case. Fit a logit-binomial GLM to the probability that a molecularly sexed adult is female, using bill (culmen) length and body mass as the two continuous predictors. This is an unusually close match to the explorer: the primary paper used logistic regression with female coded 1 and male coded 0, evaluated species separately, and reports the exact two-predictor Adélie specification as a supported model.

## 1. Preferred case and scientific evidence

Gorman, Williams, and Fraser (2014), *Ecological Sexual Dimorphism and Environmental Variability within a Community of Antarctic Penguins (Genus Pygoscelis)*, PLOS ONE 9(3): e90081, is the primary peer-reviewed publication ([article](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0090081); [DOI: 10.1371/journal.pone.0090081](https://doi.org/10.1371/journal.pone.0090081)).

The paper is substantive evidence for this particular model, rather than merely a topical citation:

- its Methods use logistic regression via an R GLM with `family = binomial`, explicitly code males as 0 and females as 1, and consider four continuous structural measurements, including culmen length and body mass ([Methods in the primary article](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0090081#sec012));
- it evaluates the candidate model set separately for each species;
- for Adélie penguins, the paper reports three models within 2 AICc units of the leader, with the second supported model containing **culmen length and body mass only**; both variables had very strong parameter support, and all supported Adélie models had McFadden pseudo-R² above 70% ([Results and Table 1](https://doi.org/10.1371/journal.pone.0090081.t001)); and
- the supported Adélie models predicted 39 of 44 held-out penguins correctly at a 0.5 probability threshold in the paper's own split-sample analysis ([primary article](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0090081#sec014)).

The later peer-reviewed R Journal data paper documents the curated `palmerpenguins` package, measurements, EDI origins, and CC0 status: Horst, Hill, and Gorman (2022), *Palmer Archipelago Penguins Data in the palmerpenguins R Package — An Alternative to Anderson's Irises* ([article](https://journal.r-project.org/articles/RJ-2022-020/); [DOI: 10.32614/RJ-2022-020](https://doi.org/10.32614/RJ-2022-020)). It is useful provenance and schema evidence, but the 2014 PLOS ONE paper remains the primary scientific source.

## 2. Authoritative data, download, and redistribution rights

Use the original, versioned Environmental Data Initiative (EDI) package rather than an unattributed mirror:

| Item | Exact location |
|---|---|
| Dataset citation | Palmer Station Antarctica LTER and K. B. Gorman (2020), *Structural size measurements and isotopic signatures of foraging among adult male and female Adélie penguins ... 2007–2009*, version 5 |
| Stable dataset DOI | [10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f](https://doi.org/10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f) |
| EDI landing page | [knb-lter-pal.219.5](https://portal.edirepository.org/nis/mapbrowse?packageid=knb-lter-pal.219.5) |
| Direct machine-readable data | [version-5 `table_219.csv`](https://pasta.lternet.edu/package/data/eml/knb-lter-pal/219/5/002f3893385f710df69eeebe893144ff) |
| Dataset-specific metadata and terms | [version-5 EML](https://pasta.lternet.edu/package/metadata/eml/knb-lter-pal/219/5) |
| License text | [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/legalcode) |

The EDI EML `intellectualRights` element states that this package is released to the public domain under **Creative Commons CC0 1.0 No Rights Reserved**, while requesting attribution as professional etiquette. CC0 permits bundling the source or a derived model-ready snapshot in an open-source repository. The package-authors' documentation independently gives the same CC0 status ([package license page](https://allisonhorst.github.io/palmerpenguins/LICENSE.html)) and identifies the EDI packages and variable definitions ([authoritative package documentation](https://allisonhorst.github.io/palmerpenguins/reference/penguins.html)). Attribution should still cite both the dataset DOI and the primary paper.

The direct EDI CSV was successfully retrieved during this review. Its observed size was 23,755 bytes and its SHA-256 was `76a2b8eeadc052b31753e525115698785a68299d07a827d63867446579cb9138`. Record this checksum in the real-data manifest; a future mismatch should stop the rebuild for review.

## 3. Inspected source schema and model-ready population

Inspection was performed on the direct version-5 EDI CSV above, not on a rendered table or secondary description.

- Source shape: **152 rows × 17 columns**.
- Columns, in source order: `studyName`, `Sample Number`, `Species`, `Region`, `Island`, `Stage`, `Individual ID`, `Clutch Completion`, `Date Egg`, `Culmen Length (mm)`, `Culmen Depth (mm)`, `Flipper Length (mm)`, `Body Mass (g)`, `Sex`, `Delta 15 N (o/oo)`, `Delta 13 C (o/oo)`, and `Comments`.
- All records are adult Adélie penguins; the package spans 2007–2009 and three Palmer Archipelago islands.
- Empty strings, rather than the literal `NA`, represent missing values in the original CSV.

Relevant fields after deterministic complete-case filtering are:

| Model role | Source field | Definition / unit | Source missing | Analysis range or coding |
|---|---|---|---:|---|
| X | `Culmen Length (mm)` | dorsal bill/culmen length, millimetres | 1 | 32.1–46.0 mm |
| Y | `Body Mass (g)` | body mass, grams | 1 | 2,850–4,775 g |
| Z | `Sex` | molecularly determined sex | 6 | `FEMALE` → 1; `MALE` → 0 |

The one record missing both selected measurements is also missing sex. Five additional records have the measurements but lack sex. Dropping rows missing any of X, Y, or Z therefore removes **6 rows**, leaving **146 model-ready observations**, balanced as **73 female (Z=1)** and **73 male (Z=0)**. The selected-field ranges above are calculated after this filter.

For completeness, other source missingness does not affect this model: `Culmen Depth (mm)` and `Flipper Length (mm)` each have one missing value; both isotope fields have 11; `Comments` has 126. Those fields must not enter the analysis-frame complete-case rule.

## 4. Exact model and link

Canonical mapping:

```text
X = Culmen Length (mm)
Y = Body Mass (g)
Z = 1 if Sex == "FEMALE", 0 if Sex == "MALE"
```

Fit:

```r
glm(Z ~ X + Y, data = model_data,
    family = binomial(link = "logit"))
```

Equivalently,

\[
\log\!\left(\frac{P(Z=1)}{1-P(Z=1)}\right)
= \beta_0 + \beta_1\,\text{bill length (mm)}
+ \beta_2\,\text{body mass (g)}.
\]

`logit` is the literature-aligned/default link. The primary paper calls the analysis logistic regression and specifies an R binomial GLM; R's official family documentation defines `binomial(link = "logit")` as the default ([R `family` documentation](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/family.html)). It is also the beta registry's default supported link. `probit` and `cloglog` can remain selectable but should be labelled exploratory for this example.

The plotted surface is `P(molecular sex = female | bill length, body mass)` on the response scale. The binary points remain at Z=0 and Z=1. Larger Adélie penguins are generally male in these data, so the expected surface falls as either structural measurement increases.

## 5. Deterministic preparation to X, Y, Z

1. Retrieve the exact version-5 EDI CSV URL and verify SHA-256 `76a2b8eeadc052b31753e525115698785a68299d07a827d63867446579cb9138`.
2. Parse as UTF-8 CSV with headers; treat empty strings as missing. Assert 152 source rows and the 17 expected column names before transformation.
3. Assert every non-missing `Species` value is `Adelie Penguin (Pygoscelis adeliae)`; do not pool species.
4. Select `Sample Number`, `Culmen Length (mm)`, `Body Mass (g)`, and `Sex`. Preserve the original field labels separately for display/download metadata.
5. Parse culmen length and body mass as finite numeric values. Reject nonnumeric non-missing text rather than coercing it silently.
6. Retain only rows complete on the two selected measurements and `Sex`. Assert that this leaves 146 rows.
7. Reject any non-missing sex value outside `FEMALE` and `MALE`; encode `FEMALE` as integer 1 and `MALE` as integer 0.
8. Sort by numeric `Sample Number` for a stable output order, then emit `X`, `Y`, `Z` (optionally retaining `Sample Number` only as a non-model provenance key). Assert X and Y are finite, Z is in `{0,1}`, and both response classes are present.

This integrated model is a **pedagogical adaptation**, not an exact reproduction of every analysis in Gorman et al. The paper used a random two-thirds training subset, AICc model selection/model averaging, and a held-out third; the explorer should instead fit the paper-supported two-predictor specification to all 146 complete Adélie cases for a deterministic full-data surface. Do not claim that explorer coefficients reproduce Table 2.

## 6. Visual and pedagogical suitability

- Both predictors are continuous, scientifically interpretable structural measurements with explicit units.
- The paper directly supports using morphology to estimate the probability of female sex, so the probability surface has a real biological interpretation.
- The post-filter sample is balanced and large enough for a stable teaching display.
- A numerical check of the recommended all-complete-case logit fit converged without separation; fitted probabilities spanned approximately `2.7e-6` to `0.99997`, with 89.7% in-sample classification at 0.5. These numbers are QA evidence only and need not appear in the UI.
- The two predictors use very different numeric scales. Axis titles must retain units, and implementation may center/scale internally only if predictions and displayed values are transformed back to the original units.

## 7. Fully verified fallback

If the Adélie case is rejected, use the **Chinstrap penguin** EDI package from the same primary study. This is a separate, versioned dataset with a different exact two-predictor specification, not an unverified suggestion.

| Item | Verified fallback detail |
|---|---|
| Scientific support | Gorman et al. report `culmen length + culmen depth` as the single Chinstrap model within 2 AICc units, with 70% McFadden pseudo-R² and 94.44% held-out classification ([primary article](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0090081#sec014)) |
| Dataset DOI | [10.6073/pasta/c14dfcfada8ea13a17536e73eb6fbe9e](https://doi.org/10.6073/pasta/c14dfcfada8ea13a17536e73eb6fbe9e) |
| Landing page | [knb-lter-pal.221.6](https://portal.edirepository.org/nis/mapbrowse?packageid=knb-lter-pal.221.6) |
| Direct CSV | [version-6 `table_221.csv`](https://pasta.lternet.edu/package/data/eml/knb-lter-pal/221/6/fe853aa8f7a59aa84cdd3197619ef462) |
| License / metadata | [version-6 EML](https://pasta.lternet.edu/package/metadata/eml/knb-lter-pal/221/6), which states CC0 1.0 No Rights Reserved; [CC0 legal code](https://creativecommons.org/publicdomain/zero/1.0/legalcode) |
| Inspected schema | 68 rows × the same 17 columns; 0 missing among culmen length, culmen depth, and sex |
| Mapping | X = `Culmen Length (mm)` (40.9–58.0); Y = `Culmen Depth (mm)` (16.4–20.8); Z = `FEMALE` 1 / `MALE` 0 |
| Classes | 34 female and 34 male |
| Formula | `glm(Z ~ X + Y, family = binomial(link = "logit"))` |
| Retrieved checksum | SHA-256 `fa9afb847942840371e698003eec0518c12d727403b975dfc67b9dba79700ea3` |

The fallback has no selected-field exclusions and is the paper's best-supported two-predictor Chinstrap model, but it has fewer than half as many observations as the preferred Adélie case and both visual axes are millimetre-scale bill measurements. Adélie therefore offers the clearer contrast between two kinds of morphology and the stronger 3D teaching surface.

## 8. Risks and integration cautions

1. **Species specificity:** the paper analyzed species separately. Pooling Adélie, Chinstrap, and Gentoo without a species term would create confounding and a misleading two-predictor surface.
2. **Adaptation versus replication:** fitting all complete cases is deterministic and suitable for the explorer, but differs from the publication's random training/test and model-averaging workflow. State this explicitly.
3. **Outcome wording:** label Z as molecularly determined biological sex and the surface as probability female; do not describe it as gender or as a general sexing rule for penguins elsewhere.
4. **Scope of inference:** these are foraging adults sampled near Palmer Station during 2007–2009. Avoid extrapolating beyond the observed predictor ranges, species, life stage, geography, or period.
5. **Raw auxiliary identifiers:** the EDI source includes animal `Individual ID` and several unused scientific fields. For the bundled model-ready snapshot, retain only the required measurements, response, and minimal provenance key; there is no need to expose unrelated columns in the app.
6. **License etiquette:** CC0 permits redistribution, but bundle the dataset citation, primary-paper citation, DOI, EDI package version, direct URL, checksum, retrieval date, and CC0 notice.

## Final selection

Select **Adélie penguins: female probability from bill length and body mass, binomial GLM with logit link**. It satisfies the beta contract exactly, has primary-paper support for the same response coding, family, link class, species-specific analysis, and two-predictor formula, comes from a versioned authoritative archive, and is CC0-redistributable with a short deterministic transformation to 146 complete X/Y/Z rows. Keep the fully verified Chinstrap package above as the fallback.
