# Real-data research for `glm_gamma`

## Recommendation: positive burned area of Portuguese forest fires

Use the **positive-severity component** of the UCI Forest Fires data: among recorded fires, model nonzero burned area from air temperature and relative humidity. This gives two continuous meteorological axes, a strictly positive continuous response, and a natural Gamma mean-response surface.

### Scientific and data provenance

- Original publication: Paulo Cortez and Aníbal Morais (2007), “A Data Mining Approach to Predict Forest Fires using Meteorological Data,” pp. 512–523 in the EPIA 2007 proceedings; the University of Minho provides the stable publication record [hdl:1822/8039](https://hdl.handle.net/1822/8039). The paper used recent real-world observations from Montesinho Natural Park and found that direct weather measurements were useful inputs for burned-area prediction.
- Peer-reviewed corroboration of this exact dataset: Castelli, Vanneschi, and Popovič (2015), “Predicting Burned Areas of Forest Fires: an Artificial Intelligence Approach,” *Fire Ecology* 11:106–118, [DOI 10.4996/fireecology.1101106](https://doi.org/10.4996/fireecology.1101106). It states that the 517 events cover 2000–2003, that park staff assessed burned area with ground GPS survey and false-color aerial photography, and that temperature and humidity came from the park weather station ([methods and data provenance](https://link.springer.com/article/10.4996/fireecology.1101106#Sec8)).
- Authoritative dataset: [UCI dataset DOI 10.24432/C5D88D](https://doi.org/10.24432/C5D88D) and [UCI landing page](https://archive.ics.uci.edu/dataset/162/forest+fires). UCI names Cortez and Morais as creators, links the 2007 introductory paper, defines the units, and labels burned area as the regression output.
- Machine-readable data: [direct UCI ZIP](https://archive.ics.uci.edu/static/public/162/forest+fires.zip), containing `forestfires.csv` and `forestfires.names`; a [direct raw CSV](https://archive.ics.uci.edu/ml/machine-learning-databases/forest-fires/forestfires.csv) is also available. The inspected ZIP was 8,932 bytes with SHA-256 `abd40d6142b5e30fea73ff7292f91dcdd8b64bf3b3f36e20f96c37f5d14f06fb`; the CSV was 25,478 bytes with SHA-256 `0d6586a1fa52f55bef48578aef14eb97273f1e9330e1a53423df497a77065253`.
- Redistribution: UCI explicitly applies [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) and permits sharing/adaptation for any purpose with attribution ([dataset license statement](https://archive.ics.uci.edu/dataset/162/forest+fires#license)). An open-source bundle should retain the creator and dataset DOI, the license link, and a note that zero-area rows were excluded.

### Inspected schema and positivity

The CSV has **517 rows and 13 columns**: `X`, `Y`, `month`, `day`, `FFMC`, `DMC`, `DC`, `ISI`, `temp`, `RH`, `wind`, `rain`, and `area`. There are no missing values in any column. Of the 517 area values, **247 equal zero, 270 are strictly positive, and none are negative**.

| Source field | Role | Unit | Full-file range | Missing | Range after `area > 0` |
|---|---|---:|---:|---:|---:|
| `temp` | X | °C | 2.2–33.3 | 0 | 2.2–33.3 |
| `RH` | Y | % relative humidity | 15–100 | 0 | 15–96 |
| `area` | Z | hectares | 0–1,090.84 | 0 | **0.09–1,090.84** |

In the 270-row positive subset, burned area has median 6.37 ha, mean 24.6002 ha, and sample skewness 9.4455. This is not merely a small numerical departure from normality: it is an extremely right-skewed positive severity distribution.

### Formula, link, and deterministic preprocessing

Use a Gamma GLM with the **log link** as the default:

\[
Z_i \mid X_i,Y_i \sim \operatorname{Gamma}(\mu_i,\phi), \qquad
\log(\mu_i)=\beta_0+\beta_1 X_i+\beta_2 Y_i,
\]

where `X = temp`, `Y = RH`, and `Z = area`. The plotted surface is therefore
`E[area | temp, RH, area > 0] = exp(β0 + β1 temp + β2 RH)`.

Deterministic mapping from the source CSV:

1. Parse the header and parse `temp`, `RH`, and `area` as decimal numbers.
2. Retain a row if and only if its original numeric `area` is strictly greater than zero. This produces exactly 270 rows.
3. Select `temp`, `RH`, and `area`; rename them `X`, `Y`, and `Z`; preserve source order.
4. Do not impute, winsorize, standardize, sample, round, add an offset, or transform Z. Fit the Gamma GLM to the original positive hectare values.

The log link guarantees positive fitted means and expresses weather effects multiplicatively. The Gamma variance function, `Var(Z | X,Y) = φ μ²`, is a credible first model for positive severity whose spread grows with its mean, while its right-skewed sampling family matches the observed shape much better than a homoscedastic Gaussian. The original study likewise identified severe skew and used `ln(area + 1)` before non-Gamma modeling ([UCI methodological summary](https://archive.ics.uci.edu/dataset/162/forest+fires)); the proposed Gamma analysis instead keeps untransformed positive areas and explicitly conditions out zeros.

As a reproducibility check, an OLS-estimated Gamma GLM on the 270 retained rows gave `log(μ) = 2.721991 + 0.0493481 temp - 0.0130929 RH` and explained 7.39% of null deviance. The signs produce an intelligible surface (higher conditional mean at warmer, drier conditions), but the low deviance fraction correctly signals that two weather variables are not an operational fire-size predictor.

### Interpretation limits

This is a **conditional severity model**, not a model of whether a fire burns any recorded area. A Gamma distribution cannot include the 247 exact zeros; a production analysis of all events would need a two-part/hurdle model or a zero-capable family such as Tweedie. The observations also span space and time, and the two-input demo omits fuel indices, wind, rain, location, and season. Present the surface as a descriptive teaching example, not a causal or firefighting decision model.

## Fallback: abalone whole weight from shell dimensions

The UCI Abalone data provide a fully positive biological alternative with no row filtering.

- Original authoritative scientific source: Nash, Sellers, Talbot, Cawthorn, and Ford (1994), *The Population Biology of Abalone (Haliotis species) in Tasmania. I. Blacklip Abalone ...*, Tasmanian Sea Fisheries Division Technical Report 48, ISBN 978-0-7246-4144-4; see the [Victorian Government Library Service catalog record](https://www.vgls.vic.gov.au/client/en_AU/vgls/search/detailnonmodal?d=ent%3A%2F%2FSD_ILS%2F0%2FSD_ILS%3A59084~~0&h=0&ps=300&qu=Nash%2C+Warwick+J.&te=ILS).
- Dataset: [UCI DOI 10.24432/C55C7W](https://doi.org/10.24432/C55C7W), [landing page](https://archive.ics.uci.edu/dataset/1/abalone), and [direct ZIP](https://archive.ics.uci.edu/static/public/1/abalone.zip). The inspected ZIP SHA-256 is `755a6a67c5b266961a3f149ea13be2cfb6e6c727e48cee3c83bc0b4526210ee4`; `abalone.data` SHA-256 is `de37cdcdcaaa50c309d514f248f7c2302a5f1f88c168905eba23fe2fbc78449f`.
- License: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), explicitly stated on the [UCI record](https://archive.ics.uci.edu/dataset/1/abalone#license).

The headerless file has **4,177 rows and 9 fields**, with no missing values. Its documentation says all continuous measurements were divided by 200 for the ANN release. Deterministically multiply `Length`, `Diameter`, and `Whole_weight` by 200, yielding X = shell length (15–163 mm), Y = shell diameter (11–130 mm), and Z = whole weight (0.4–565.1 g); all 4,177 Z values are strictly positive. Fit `log(E[Z]) = β0 + β1 X + β2 Y` with a Gamma family and log link. A check explained 91.99% of null deviance.

This fallback is visually strong but scientifically less attractive for a 3D surface because length and diameter are almost redundant (`r = 0.9868` in the inspected file), so observations occupy a narrow band of the X–Y plane and separate coefficients are unstable. The source is also a government technical report rather than a peer-reviewed journal paper.

## Final choice

Ship the **positive forest-fire severity** example with the log link. It most clearly teaches why Gamma excludes zero, why a log link is useful, and why occurrence and positive severity may require separate models. Retain Abalone as the no-filter fallback when a stronger-looking surface is more important than predictor independence.
