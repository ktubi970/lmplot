# Real-data example for `lm_2d`

## Final recommendation

Bundle the Adélie-penguin table from the Palmer Station Antarctica Long-Term Ecological Research (PAL LTER) program and demonstrate the relationship between adult flipper length and body mass during the egg-laying sampling period. The measurements underlie Gorman, Williams, and Fraser's peer-reviewed ecological study, *Ecological Sexual Dimorphism and Environmental Variability within a Community of Antarctic Penguins (Genus Pygoscelis)* ([PLOS ONE article and DOI `10.1371/journal.pone.0090081`](https://doi.org/10.1371/journal.pone.0090081)). The authoritative archive is [EDI package `knb-lter-pal.219.5`](https://portal.edirepository.org/nis/mapbrowse?packageid=knb-lter-pal.219.5), whose current dataset DOI is [`10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f`](https://doi.org/10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f).

Exact resources:

- Publication: [Gorman et al. (2014), PLOS ONE](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0090081); DOI: [`10.1371/journal.pone.0090081`](https://doi.org/10.1371/journal.pone.0090081).
- Dataset landing page: [EDI `knb-lter-pal.219.5`](https://portal.edirepository.org/nis/mapbrowse?packageid=knb-lter-pal.219.5).
- Direct machine-readable data: [archived CSV](https://pasta.lternet.edu/package/data/eml/knb-lter-pal/219/5/002f3893385f710df69eeebe893144ff).
- Machine-readable schema and rights statement: [EDI EML metadata](https://pasta.lternet.edu/package/metadata/eml/knb-lter-pal/219/5).
- License: [Creative Commons CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

## Data audit

I downloaded and parsed the authoritative CSV directly on 2026-07-18. It contains **152 rows and 17 columns**; its headers are `studyName`, `Sample Number`, `Species`, `Region`, `Island`, `Stage`, `Individual ID`, `Clutch Completion`, `Date Egg`, `Culmen Length (mm)`, `Culmen Depth (mm)`, `Flipper Length (mm)`, `Body Mass (g)`, `Sex`, `Delta 15 N (o/oo)`, `Delta 13 C (o/oo)`, and `Comments` ([computed from the archived CSV](https://pasta.lternet.edu/package/data/eml/knb-lter-pal/219/5/002f3893385f710df69eeebe893144ff)). EDI describes this package as adult Adélie-penguin structural-size and isotope observations from 2007–2009 ([EDI dataset DOI](https://doi.org/10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f)).

| Original column | Meaning and unit | Missing in 152 rows | Observed range / values |
|---|---|---:|---|
| `Flipper Length (mm)` | Flipper length, millimetres | 1 | 172–210 mm |
| `Body Mass (g)` | Body mass, grams | 1 | 2,850–4,775 g |
| `Culmen Length (mm)` | Dorsal bill-ridge length, millimetres | 1 | 32.1–46.0 mm |
| `Culmen Depth (mm)` | Dorsal bill-ridge depth, millimetres | 1 | 15.5–21.5 mm |
| `Sex` | Molecularly determined sex code | 6 | 73 `FEMALE`, 73 `MALE`, 6 blank |
| `Island` | Sampling island | 0 | `Biscoe`, `Dream`, `Torgersen` |

Units and definitions above come from the [EDI EML schema](https://pasta.lternet.edu/package/metadata/eml/knb-lter-pal/219/5); counts and ranges were computed from the [archived CSV](https://pasta.lternet.edu/package/data/eml/knb-lter-pal/219/5/002f3893385f710df69eeebe893144ff). There are **151 complete X/Z pairs**. On those pairs, the reproducibility check gives the fitted line `Body Mass (g) = -2535.836802 + 32.831690 × Flipper Length (mm)` and `R² = 0.219213` ([computed from the archived CSV](https://pasta.lternet.edu/package/data/eml/knb-lter-pal/219/5/002f3893385f710df69eeebe893144ff)). These estimates are useful as an ingestion check, not values to hard-code into the explorer.

## Deterministic mapping and model

1. Read the archived CSV with its header row and decimal point `.`.
2. Preserve source row order. Set `X = Flipper Length (mm)` and `Z = Body Mass (g)`.
3. Parse both as numeric and retain a row if and only if both values are present and finite. Do not impute, winsorize, rescale, or filter on sex, island, or year. This produces 151 rows ([computed from the archived CSV](https://pasta.lternet.edu/package/data/eml/knb-lter-pal/219/5/002f3893385f710df69eeebe893144ff)).
4. Keep the source units: X in millimetres and Z in grams.

The exact beta-model formula is

\[
Z_i = \beta_0 + \beta_1 X_i + \varepsilon_i,
\qquad \varepsilon_i \overset{iid}{\sim} \mathcal N(0,\sigma^2),
\]

or `lm(\`Body Mass (g)\` ~ \`Flipper Length (mm)\`, data = adelie_complete)` / explorer shorthand `Z ~ X`.

This is scientifically defensible as a **descriptive within-species body-size association**: both variables are continuous ratio-scale morphology measurements ([EDI schema](https://pasta.lternet.edu/package/metadata/eml/knb-lter-pal/219/5)), and the peer-reviewed `palmerpenguins` data paper explicitly presents within-species linear fits of body mass against flipper length and describes the overall relationship as approximately linear ([Horst, Hill, and Gorman 2022, DOI `10.32614/RJ-2022-020`](https://doi.org/10.32614/RJ-2022-020)). Restricting the source to Adélie penguins avoids treating the three species as one homogeneous population; the same data paper warns that omitted species can materially change bivariate relationships ([R Journal article](https://journal.r-project.org/articles/RJ-2022-020/)).

The model must not be presented as causal or universally predictive. The primary study found males structurally larger than females, and it notes that body mass is seasonally plastic and that these mass observations apply to the egg-laying period ([Gorman et al. 2014](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0090081)). Sex, island, and year are therefore plausible omitted sources of structure. For the beta, label the result “association among sampled adult Adélie penguins,” show residual diagnostics, and avoid extrapolation beyond 172–210 mm.

## Redistribution suitability

The package's authoritative EML rights statement releases the data to the public domain under **CC0 1.0, No Rights Reserved** ([EDI EML metadata](https://pasta.lternet.edu/package/metadata/eml/knb-lter-pal/219/5); [CC0 legal tool](https://creativecommons.org/publicdomain/zero/1.0/)). This is suitable for bundling either the unchanged source CSV or a deterministic two-column derivative in an open-source repository. Retain the dataset DOI, publication citation, source URL, retrieval date, and preprocessing note in repository metadata even though CC0 does not require attribution.

## Fallback candidate (not fully audited in this pass)

If a species-independent teaching classic is preferred, the UCI Iris dataset is a plausible fallback: [UCI dataset landing page and dataset DOI `10.24432/C56C76`](https://doi.org/10.24432/C56C76), [direct ZIP download](https://archive.ics.uci.edu/static/public/53/iris.zip), [CC BY 4.0 license](https://creativecommons.org/licenses/by/4.0/), and Fisher's peer-reviewed publication [DOI `10.1111/j.1469-1809.1936.tb02137.x`](https://doi.org/10.1111/j.1469-1809.1936.tb02137.x). A defensible `lm_2d` version would first select one species and then model petal width from petal length to avoid a pooled species-cluster effect. Because its archive contents, exact subset statistics, and schema were not independently re-audited here, do **not** bundle it on the strength of this note alone.

## Decision

Use the EDI Adélie CSV. It is the stronger beta example because publication provenance, original archive, exact machine-readable object, schema, observed data, deterministic preprocessing, and CC0 redistribution terms have all been verified. The remaining scientific risk is omitted sex/year/island structure, which is manageable if the explorer describes the fit as a simple descriptive association and exposes diagnostics rather than making a causal claim.
