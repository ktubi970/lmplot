# Real-data research report: `glm_binomial_2d`

**Recommendation:** use the Palmer Station LTER **Adélie penguin sex-from-bill-length** case. Fit a 2D logit-binomial GLM to the probability that a molecularly sexed adult is female, using bill (culmen) length as the single continuous predictor.

## 1. Preferred case and scientific evidence

Gorman, Williams, and Fraser (2014), *Ecological Sexual Dimorphism and Environmental Variability within a Community of Antarctic Penguins (Genus Pygoscelis)*, PLOS ONE 9(3): e90081 ([article](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0090081); [DOI: 10.1371/journal.pone.0090081](https://doi.org/10.1371/journal.pone.0090081)).

## 2. Authoritative data, download, and redistribution rights

| Item | Exact location |
|---|---|
| Dataset citation | Palmer Station Antarctica LTER and K. B. Gorman (2020), *Structural size measurements and isotopic signatures of foraging among adult male and female Adélie penguins ... 2007–2009*, version 5 |
| Stable dataset DOI | [10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f](https://doi.org/10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f) |
| Direct machine-readable data | [version-5 `table_219.csv`](https://pasta.lternet.edu/package/data/eml/knb-lter-pal/219/5/002f3893385f710df69eeebe893144ff) |
| License text | [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/legalcode) |

## 3. Exact model and link

```r
glm(Z ~ X, data = model_data, family = binomial(link = "logit"))
```
