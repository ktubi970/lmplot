# Real-data research for `lm_3d`

## Recommendation: 28-day concrete compressive strength

Use I-Cheng Yeh's **Concrete Compressive Strength** data, restricted to specimens tested at 28 days. The source is a laboratory-based civil-engineering study, the response and both predictors are continuous, and the restriction holds curing age constant so that a two-predictor fitted plane has a defensible physical interpretation.

### Evidence and access

- Primary peer-reviewed publication: I.-C. Yeh (1998), “Modeling of strength of high-performance concrete using artificial neural networks,” *Cement and Concrete Research* 28(12), 1797–1808, [DOI 10.1016/S0008-8846(98)00165-3](https://doi.org/10.1016/S0008-8846(98)00165-3) ([publisher page](https://www.sciencedirect.com/science/article/pii/S0008884698001653)). The article describes laboratory trial batches and states that concrete-strength development depends on the water-to-cement ratio as well as other ingredients.
- Authoritative dataset record: [UCI dataset DOI 10.24432/C5PK67](https://doi.org/10.24432/C5PK67) and [UCI landing page](https://archive.ics.uci.edu/dataset/165/concrete-compressive-strength). UCI identifies Yeh as creator, the 1998 paper as the introductory paper, and the task as regression.
- Machine-readable download: [UCI ZIP](https://archive.ics.uci.edu/static/public/165/concrete+compressive+strength.zip), containing `Concrete_Data.xls` and `Concrete_Readme.txt`. The inspected ZIP was 34,444 bytes with SHA-256 `dad85d14de8aee4e07479daa774e6b569a313715b71a3b92c95a07cf91c2c9a7`; the XLS was 124,928 bytes with SHA-256 `710076c66b9ca3f8050e7942f3dcbdbe04013534daeb0077ffd3079a52d8e0c4`.
- Redistribution: UCI explicitly licenses this dataset under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), allowing sharing and adaptation for any purpose with attribution ([license statement on the dataset page](https://archive.ics.uci.edu/dataset/165/concrete-compressive-strength#license)). Bundling either the source file or a derived three-column CSV is suitable if the repository preserves creator/dataset attribution, the CC BY link, and a note describing the 28-day filter and column renaming.

### Inspected schema

The first worksheet contains **1,030 rows and 9 numeric columns**: eight mixture/age inputs and one measured strength output; no column has a missing value. UCI independently reports 1,030 instances, eight quantitative inputs, one quantitative output, and no missing values on the [landing page](https://archive.ics.uci.edu/dataset/165/concrete-compressive-strength).

| Source column | Role | Unit | Full-file range | Missing | Range after `Age == 28` |
|---|---|---:|---:|---:|---:|
| `Cement (component 1)(kg in a m^3 mixture)` | X | kg/m³ | 102.0–540.0 | 0 | 102.0–540.0 |
| `Water  (component 4)(kg in a m^3 mixture)` | Y | kg/m³ | 121.75–247.0 | 0 | 121.75–247.0 |
| `Concrete compressive strength(MPa, megapascals) ` | Z | MPa | 2.331807832–82.5992248 | 0 | 8.53571288–81.75116932 |
| `Age (day)` | deterministic filter | days | 1–365 | 0 | exactly 28 |

The exact 28-day filter leaves **425 rows**, all complete for X, Y, and Z.

### Model and deterministic preprocessing

Fit the additive plane

\[
\text{compressive strength}_i = \beta_0 + \beta_1\,\text{cement}_i + \beta_2\,\text{water}_i + \varepsilon_i.
\]

Deterministic mapping from the downloaded workbook:

1. Read the first worksheet of `Concrete_Data.xls`, using the first row as headers and numeric values without rounding.
2. Retain rows for which the exact source field `Age (day)` equals numeric `28`.
3. Select the three exact source fields shown in the table.
4. Rename cement to `X`, water to `Y`, and compressive strength to `Z`; preserve source row order. No imputation, scaling, transformation, sampling, or outlier removal is needed.

Scientific rationale: at a common curing age, cement and water jointly encode the central water/cement composition relationship discussed by Yeh, while Z is the measured engineering response. An independent OLS sanity check on the 425 retained records gave `Z = 53.1952 + 0.0860708 X - 0.2146501 Y` and in-sample `R² = 0.5203`, so the plane is visually informative without looking artificially perfect.

This is an **educational low-order approximation**, not Yeh's final engineering model: the paper emphasizes nonlinear behavior and additional ingredients (slag, fly ash, superplasticizer, and aggregates). The UI copy should describe association within the observed 28-day mixtures, avoid causal claims, and discourage extrapolation outside the displayed ranges.

## Fallback: Palmer Penguins morphology

If a more approachable biological example is preferred, use adult penguin body mass as Z and two structural measurements as X and Y.

- Primary ecological publication: Gorman, Williams, and Fraser (2014), *PLOS ONE* 9(3):e90081, [DOI 10.1371/journal.pone.0090081](https://doi.org/10.1371/journal.pone.0090081). Its field methods document measurements of bill dimensions, flipper length, and body mass ([article methods](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0090081)).
- Authoritative curated data: the author-maintained [palmerpenguins landing page](https://allisonhorst.github.io/palmerpenguins/) and archived [v0.1.0 record, DOI 10.5281/zenodo.3960218](https://doi.org/10.5281/zenodo.3960218). The package and its data provenance are also documented in the peer-reviewed *R Journal* article [DOI 10.32614/RJ-2022-020](https://doi.org/10.32614/RJ-2022-020).
- Direct CSV: pinned [v0.1.0 `penguins.csv`](https://raw.githubusercontent.com/allisonhorst/palmerpenguins/v0.1.0/inst/extdata/penguins.csv), inspected as 15,241 bytes with SHA-256 `f204db2c753b0937caac3cb35258562c14f073e4bbc76be24b4c51ce22767a93`.
- License: the package landing page states that the data are [CC0](https://allisonhorst.github.io/palmerpenguins/LICENSE.html), permitting open-source bundling and redistribution. Retain the dataset and Gorman-paper citations even though CC0 does not require attribution.

The CSV has **344 rows and 8 columns**. For `bill_length_mm` (32.1–59.6 mm), `flipper_length_mm` (172–231 mm), and `body_mass_g` (2,700–6,300 g), each column has 2 missing values; complete-case selection across the three leaves **342 rows**. Map `X = flipper_length_mm`, `Y = bill_length_mm`, `Z = body_mass_g`, drop rows where any of those exact fields is empty/`NA`, preserve order, and fit `body_mass_g ~ flipper_length_mm + bill_length_mm` with no transformations. An OLS check gives `R² = 0.7600`.

The fallback's main risk is scientific interpretation: the 342 observations pool Adélie, Chinstrap, and Gentoo penguins, so the strong plane combines within-species and between-species morphology. Species may be used for point color or explanatory copy, but it must not silently become a third predictor; label the fit as descriptive and non-causal.

## Final choice

Ship the **28-day concrete** example. It has the cleanest licensing chain, no missing-data ambiguity, fully physical units, exactly two continuous compositional predictors, a continuous measured response, and a scientifically motivated preprocessing step that makes the plane easier to defend. Palmer Penguins is a well-licensed, visually friendly fallback, but its pooled-species structure creates a larger interpretation caveat.
