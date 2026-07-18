# Real-data example for `glm_poisson`

## Final recommendation: abalone shell-ring counts

Use the UCI **Abalone** data to model the microscopic shell-ring count of an abalone from its shell length and dried shell weight. The data creators are Warwick Nash, Tracy Sellers, Simon Talbot, Andrew Cawthorn, and Wes Ford, and UCI assigns the dataset DOI [`10.24432/C55C7W`](https://doi.org/10.24432/C55C7W). UCI traces the data to Nash et al.'s 1994 Tasmanian government study *The Population Biology of Abalone (Haliotis species) in Tasmania: I. Blacklip Abalone (H. rubra) from the North Coast and Islands of Bass Strait*, Technical Report 48 ([authoritative government-library catalogue record; ISBN 9780724641444](https://www.vgls.vic.gov.au/client/en_AU/vgls/search/detailnonmodal?d=ent%3A%2F%2FSD_ILS%2F0%2FSD_ILS%3A59084~~0&h=0&ps=300&qu=Nash%2C+Warwick+J.&te=ILS)). That report has no DOI. The biological interpretation of shell rings as an ageing measurement is independently supported by Prince et al.'s peer-reviewed validation study, [*A method for ageing the abalone Haliotis rubra*, DOI `10.1071/MF9880167`](https://doi.org/10.1071/MF9880167).

Exact resources:

- Dataset landing page and DOI: [UCI Abalone, `10.24432/C55C7W`](https://doi.org/10.24432/C55C7W).
- Direct archive download: [`abalone.zip`](https://archive.ics.uci.edu/static/public/1/abalone.zip).
- Direct machine-readable table: [`abalone.data`](https://archive.ics.uci.edu/ml/machine-learning-databases/abalone/abalone.data).
- Direct schema/readme: [`abalone.names`](https://archive.ics.uci.edu/ml/machine-learning-databases/abalone/abalone.names).
- Original scientific report: [Nash et al. (1994), Tasmanian Department of Primary Industry and Fisheries, Technical Report 48](https://www.vgls.vic.gov.au/client/en_AU/vgls/search/detailnonmodal?d=ent%3A%2F%2FSD_ILS%2F0%2FSD_ILS%3A59084~~0&h=0&ps=300&qu=Nash%2C+Warwick+J.&te=ILS) (no DOI assigned).
- Related peer-reviewed ring-validation publication: [Prince et al. (1988), DOI `10.1071/MF9880167`](https://doi.org/10.1071/MF9880167).
- Dataset license: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), explicitly stated on the [UCI landing page](https://archive.ics.uci.edu/dataset/1/abalone).

## Actual-data audit

I downloaded and parsed the UCI archive on 2026-07-18. `abalone.data` is a headerless, comma-delimited table with **4,177 rows, nine fields, no missing values, and no duplicated complete rows** ([computed from the direct table](https://archive.ics.uci.edu/ml/machine-learning-databases/abalone/abalone.data)). The field order is `Sex`, `Length`, `Diameter`, `Height`, `Whole_weight`, `Shucked_weight`, `Viscera_weight`, `Shell_weight`, `Rings` ([UCI schema](https://archive.ics.uci.edu/ml/machine-learning-databases/abalone/abalone.names)). UCI notes that records with missing values had already been removed upstream and that the continuous measurements were divided by 200 for neural-network use ([UCI dataset documentation](https://archive.ics.uci.edu/dataset/1/abalone)).

| Role | Source field | Stored coding | Deterministic explorer value | Missing | Observed range |
|---|---|---|---|---:|---:|
| Z | `Rings` | integer ring count | unchanged integer | 0 | 1–29 rings |
| X | `Length` | physical measurement divided by 200 | `length_mm = 200 * Length` | 0 | 15–163 mm |
| Y | `Shell_weight` | physical measurement divided by 200 | `shell_weight_g = 200 * Shell_weight` | 0 | 0.3–201 g |

The response contains only positive whole numbers; its observed mean is 9.933684 and variance is 10.395266. The observed ring values span 1–29, with 28 absent but no invalid or fractional values ([computed from the direct table](https://archive.ics.uci.edu/ml/machine-learning-databases/abalone/abalone.data)). UCI defines `Length` as the longest shell measurement in millimetres, `Shell_weight` as dried shell weight in grams, and `Rings + 1.5` as approximate age in years ([UCI variable table](https://archive.ics.uci.edu/dataset/1/abalone)).

## Deterministic preprocessing

1. Read [`abalone.data`](https://archive.ics.uci.edu/ml/machine-learning-databases/abalone/abalone.data) as comma-delimited with no header and assign the nine field names in the exact [UCI schema order](https://archive.ics.uci.edu/ml/machine-learning-databases/abalone/abalone.names).
2. Set `Z = integer(Rings)`, `X = 200 * Length`, and `Y = 200 * Shell_weight`.
3. Retain a row if and only if Z is a finite, non-negative integer and X and Y are finite. No rows are removed from the archived file under this rule ([computed from the direct table](https://archive.ics.uci.edu/ml/machine-learning-databases/abalone/abalone.data)).
4. Preserve source row order. Do not filter by `Sex`, trim extremes, transform Z, or impute values.

The factor 200 reverses UCI's documented scaling and restores the published physical units ([UCI documentation](https://archive.ics.uci.edu/dataset/1/abalone)). It should be recorded in bundled provenance rather than silently applied.

## Exact Poisson model

Use the canonical, supported **log link**:

\[
Z_i \sim \operatorname{Poisson}(\mu_i), \qquad
\log(\mu_i)=\beta_0+\beta_1 X_i+\beta_2 Y_i,
\]

where Z is `Rings`, X is `length_mm`, and Y is `shell_weight_g`. In R notation: `glm(Rings ~ length_mm + shell_weight_g, family = poisson(link = "log"), data = abalone)`.

The log link is the recommended default because it guarantees a positive mean-count surface and makes each coefficient a multiplicative effect on expected ring count. The scientific question is deliberately associative: “How does expected shell-ring count vary with shell length and dried shell weight in this archived Tasmanian abalone sample?” Both predictors measure accumulated body/shell size, while Z is a directly counted shell feature used for ageing ([UCI description](https://archive.ics.uci.edu/dataset/1/abalone); [Prince et al. validation study](https://doi.org/10.1071/MF9880167)). This supports a simple first-order mean surface, not a causal claim.

## Fit and dispersion audit

A fresh maximum-likelihood fit to all 4,177 rows produced, in restored units,

\[
\widehat{\log(\mu)} = 1.841185 + 0.00148856\,\text{length\_mm}
                                  + 0.00584485\,\text{shell\_weight\_g}.
\]

The null deviance is 4,139.300; residual deviance is 2,476.695 on 4,174 residual degrees of freedom, so residual deviance/df is **0.593**. Pearson chi-square/df is **0.642** ([computed from the direct UCI table](https://archive.ics.uci.edu/ml/machine-learning-databases/abalone/abalone.data)). Therefore there is **no overdispersion**; instead, the conditional counts are moderately **underdispersed** relative to Poisson. The Poisson mean surface is suitable for this beta's visual demonstration, but its model-based uncertainty is not perfectly calibrated. If the application later supports alternatives, a generalized-Poisson or Conway–Maxwell–Poisson sensitivity fit would address underdispersion.

Two further limitations belong in the example text. First, the archived sample is already complete-case filtered, so it is not the untouched field table ([UCI documentation](https://archive.ics.uci.edu/dataset/1/abalone)). Second, the original documentation says weather and location may also be needed for age prediction ([UCI dataset information](https://archive.ics.uci.edu/dataset/1/abalone)). Length and shell weight are correlated body-size measures, so the rendered rectangular surface includes sparse combinations; predictions should be emphasized near the observed point cloud and never interpreted causally or extrapolated beyond X = 15–163 mm and Y = 0.3–201 g.

## Redistribution suitability

UCI explicitly licenses this dataset under **Creative Commons Attribution 4.0**, permitting sharing and adaptation for any purpose with appropriate credit ([UCI license statement](https://archive.ics.uci.edu/dataset/1/abalone); [CC BY 4.0 legal code](https://creativecommons.org/licenses/by/4.0/legalcode)). Bundling either the original files or a deterministic three-column derivative is compatible with an open-source repository. Include the five data creators, dataset title, UCI DOI, license, direct source URL, retrieval date, and the multiply-by-200 preprocessing statement.

## Fallback: Seoul bike demand (verified, but not recommended as the default)

The UCI [Seoul Bike Sharing Demand dataset, DOI `10.24432/C5F62R`](https://doi.org/10.24432/C5F62R), is an openly licensed alternative with 8,760 hourly records, no missing values, an integer `Rented Bike Count`, and weather measurements ([UCI schema and CC BY 4.0 statement](https://archive.ics.uci.edu/dataset/560/seoul%2Bbike%2Bsharing%2Bdemand); [direct ZIP](https://archive.ics.uci.edu/static/public/560/seoul+bike+sharing+demand.zip)). It underlies Sathishkumar and Cho's peer-reviewed study [DOI `10.1080/22797254.2020.1725789`](https://doi.org/10.1080/22797254.2020.1725789). A deterministic beta mapping would retain `Functioning Day == "Yes"` and fit `Rented Bike Count ~ Temperature(°C) + Humidity(%)` with a log link. However, the resulting 8,465-row Poisson fit has Pearson chi-square/df about **328.7**, indicating extreme overdispersion from omitted hour, season, holidays, and temporal dependence ([computed from the direct UCI archive](https://archive.ics.uci.edu/static/public/560/seoul+bike+sharing+demand.zip)). Use it only as an intentional diagnostics/failure lesson, not as the default scientifically defensible Poisson example.

## Decision

Use the abalone data. It has authoritative scientific provenance, an official machine-readable archive, explicit CC BY 4.0 terms, a genuinely integer count response, two continuous predictors with recoverable physical units, and a stable log-link surface. The residual risk is moderate underdispersion and correlated predictors; both should be disclosed, but they are materially less damaging than the extreme overdispersion of the verified bike-demand fallback.
