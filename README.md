# LM Plot Explorer 0.9.0-beta.1

Interactive local exploration of linear, generalized linear, and Gaussian mixed models.

## Quick start

Requires R 4.6.x. From the project root:

```r
renv::restore()
shiny::runApp(".")
```

Starting R in the project root loads the committed `.Rprofile`, which activates
the project library and bootstraps the locked `renv` version when necessary.
`renv::restore()` then installs the exact runtime and test dependencies recorded
in `renv.lock` into that isolated project library.

On Windows, `run.bat` first changes to its own directory so the same activation
takes effect, then performs the restore and launches the app with R 4.6.0.

Run tests from the project root with:

```r
testthat::test_dir("tests", reporter = "summary")
```

## Supported models

The beta supports exactly 15 model/link combinations.

| Model ID | UI label | Fit | Predictors | Link |
|---|---|---|---|---|
| `lm_2d` | Simple LM (2D) | `lm` | `X` | `identity` |
| `lm_3d` | Multiple LM (3D) | `lm` | `X + Y` | `identity` |
| `glm_binomial_2d` | Simple Binomial GLM (2D) | `glm(binomial)` | `X` | `logit` |
| `glm_binomial_2d` | Simple Binomial GLM (2D) | `glm(binomial)` | `X` | `probit` |
| `glm_binomial_2d` | Simple Binomial GLM (2D) | `glm(binomial)` | `X` | `cloglog` |
| `glm_binomial` | Binomial GLM | `glm(binomial)` | `X + Y` | `logit` |
| `glm_binomial` | Binomial GLM | `glm(binomial)` | `X + Y` | `probit` |
| `glm_binomial` | Binomial GLM | `glm(binomial)` | `X + Y` | `cloglog` |
| `glm_poisson` | Poisson GLM | `glm(poisson)` | `X + Y` | `log` |
| `glm_poisson` | Poisson GLM | `glm(poisson)` | `X + Y` | `identity` |
| `glm_poisson` | Poisson GLM | `glm(poisson)` | `X + Y` | `sqrt` |
| `glm_gamma` | Gamma GLM | `glm(Gamma)` | `X + Y` | `inverse` |
| `glm_gamma` | Gamma GLM | `glm(Gamma)` | `X + Y` | `log` |
| `glm_gamma` | Gamma GLM | `glm(Gamma)` | `X + Y` | `identity` |
| `glmm` | Gaussian GLMM | `lmer` | `X + Y + (1 | Group)` | `identity` |

## Security and beta scope

Expert mode evaluates R code and is restricted to trusted local use. Do not
expose it to untrusted or remote users.

This beta does not provide hosted-user isolation, arbitrary formulas, uploaded
datasets, random slopes, or generalized mixed models.

## Scientific real-data examples

Each supported model has one bundled, reproducible teaching example. The
prepared CSV, provenance metadata, example-specific README, and static preview
are committed so normal app sessions remain fully offline. External provenance
links are opened only when a user chooses them; the app does not download data
at runtime.

| Example | Model family | Default link | Rows | Publication identifier | Dataset identifier | License |
|---|---|---:|---:|---|---|---|
| [Adélie penguin body mass](data/real/adelie_flipper_mass/README.md) | Linear model (2D) | `identity` | 151 | [10.1371/journal.pone.0090081](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0090081) | [10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f](https://doi.org/10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| [28-day concrete compressive strength](data/real/concrete_28d/README.md) | Linear model (3D) | `identity` | 425 | [10.1016/S0008-8846(98)00165-3](https://doi.org/10.1016/S0008-8846(98)00165-3) | [10.24432/C5PK67](https://doi.org/10.24432/C5PK67) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| [Adélie penguin sex from morphology](data/real/adelie_sex/README.md) | Binomial GLM | `logit` | 146 | [10.1371/journal.pone.0090081](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0090081) | [10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f](https://doi.org/10.6073/pasta/98b16d7d563f265cb52372c8ca99e60f) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| [Abalone shell-ring count](data/real/abalone_rings/README.md) | Poisson GLM | `log` | 4,177 | [10.1071/MF9880167](https://doi.org/10.1071/MF9880167) | [10.24432/C55C7W](https://doi.org/10.24432/C55C7W) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| [Positive forest-fire burned area](data/real/forest_fire_positive_area/README.md) | Gamma GLM | `log` | 270 | [hdl:1822/8039](https://hdl.handle.net/1822/8039) | [10.24432/C5D88D](https://doi.org/10.24432/C5D88D) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| [Inner London examination achievement](data/real/inner_london_exam/README.md) | Gaussian GLMM | `identity` | 4,059 | [10.1080/0305498930190401](https://doi.org/10.1080/0305498930190401) | [10.32614/CRAN.package.mlmRev](https://doi.org/10.32614/CRAN.package.mlmRev) | [GPL-2-or-later](https://www.r-project.org/Licenses/GPL-2) |

The source snapshots are already bundled. Rebuild the model-ready CSV files
and static plots offline with R 4.6.0:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" scripts/build_real_examples.R
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" scripts/export_real_example_plots.R
```

To refresh the reviewed source snapshots, run the fetch step separately while
online, then rebuild offline:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" scripts/fetch_real_examples.R
```

Restore the exact package set before reproducing artifacts with
`renv::restore()`. The fetch script verifies the recorded checksums; the build
scripts preserve source row order and enforce each example's declared schema,
exclusions, units, row count, and statistical domain.

<!-- PATTERN-DESIGN-START -->
## Architecture & Design Patterns (Conventions Projet)

> [!IMPORTANT]
> **Directives pour l'Agent IA & Développeurs :**
> Ce projet suit des patrons de conception stricts. Lors de chaque création de fonctionnalité, refactorisation ou ajout de code,
> vous DEVEZ respecter les patterns ci-dessous sans introduire de sur-ingénierie inutile (KISS & YAGNI).

- **Style Architectural Actuel :** Reactive Scientific & Analytical Application (Shiny / Streamlit)
- **Langages & Frameworks :** Python, R | Pandas, NumPy, Plotly, ggplot2, testthat, Streamlit, Shiny, lme4, Pydantic, DT, bslib

### Patrons de Conception Retenus

#### Strategy Pattern (Behavioral) - 🔥 OBLIGATOIRE
- **Problème résolu :** Éviter les cascades de if/else ou switch/case pour les algorithmes variables (modèles statistiques, méthodes de calcul, formats d'export).
- **Règle stricte :** Encapsuler chaque algorithme ou intégration dans une fonction/classe dédiée respectant un contrat commun et utiliser un registre ou une fonction pivot pour la sélection.
```r
# Strategy : Modélisation statistique uniforme
fit_model <- function(strategy, formula, data, ...) {
  switch(strategy,
    'lm' = lm(formula, data = data),
    'glm' = glm(formula, data = data, ...),
    'glmm' = lme4::lmer(formula, data = data, ...),
    stop('Stratégie inconnue: ', strategy)
  )
}
```

#### Factory / Dependency Injection Pattern (Creational) - 🔥 OBLIGATOIRE
- **Problème résolu :** Éviter les instanciations directes en dur ('new Service()') qui créent un couplage fort et empêchent les mocks lors des tests.
- **Règle stricte :** Passer les dépendances et la configuration via les arguments ou constructeurs au lieu de référencer des globales en dur.
```r
# Factory : Instanciation de pipelines de calcul / validateurs
create_pipeline <- function(spec, validator = default_validator) {
  list(spec = spec, validate = validator, run = function(df) validator(df))
}
```

#### Adapter / Facade Pattern (Structural) - ✨ RECOMMANDÉ
- **Problème résolu :** Protéger le cœur du projet contre les changements d'API des services tiers ou bibliothèques externes (export, moteur de rendu, SDK).
- **Règle stricte :** Créer un Adapter pour chaque bibliothèque ou SDK externe. Le code métier ne communique qu'avec l'Adapter, jamais directement avec l'API bas niveau.
```r
# Adapter / Façade : Moteur de rendu graphique (Plotly / ggplot2)
render_prediction_plot <- function(fit, newdata, engine = c('plotly', 'ggplot2')) {
  engine <- match.arg(engine)
  if (engine == 'plotly') plotly_adapter(fit, newdata) else ggplot_adapter(fit, newdata)
}
```

#### Use Case / Service Layer Pattern (Architectural) - 🔥 OBLIGATOIRE
- **Problème résolu :** Présence de fichiers volumineux (app.R fait 844 lignes), signe potentiel de God Objects ou de contrôleurs obèses.
- **Règle stricte :** Chaque cas d'usage (action utilisateur, ajustement de modèle, transformation) doit avoir sa propre fonction ou service dédié (Single Responsibility Principle). L'UI ne fait que valider les entrées et appeler le Use Case.
```r
# Use Case : Logique métier et validation isolées du contrôleur Shiny
estimate_and_validate_usecase <- function(data, spec) {
  validated <- validate_schema(data, spec)
  model <- fit_model(spec$type, spec$formula, validated)
  extract_metrics(model)
}
```

#### Modular Reactive Component Pattern (Shiny Modules) (UI / Reactivity & State) - 🔥 OBLIGATOIRE
- **Problème résolu :** Collision des identifiants (input/output IDs) et logique monolithique difficile à maintenir dans un script UI centralisé.
- **Règle stricte :** Découper chaque panneau d'exploration, tableau ou graphique en modules Shiny indépendants (`NS(id)` + `moduleServer`). Isoler le calcul pur hors de `input$`.
```r
model_explorer_ui <- function(id) {
  ns <- NS(id)
  tagList(selectInput(ns('model'), 'Modèle', choices = c('lm', 'glm')), plotlyOutput(ns('plot')))
}
model_explorer_server <- function(id, data_r) {
  moduleServer(id, function(input, output, session) {
    fit_r <- reactive({ fit_model(input$model, data = data_r()) })
    output$plot <- renderPlotly({ plot_fit(fit_r()) })
  })
}
```

### Anti-Patterns à Proscrire Strictement
- ❌ **God Objects / Monstrous Handlers** : Fichiers uniques dépassant 300 lignes contenant à la fois validation, logique métier et requêtes SQL.
- ❌ **Couplage Fort aux Dépendances** : Instancier directement des clients HTTP ou des SDK tiers dans les services sans passer par une interface ou un Adapter.
- ❌ **Contournement des Couches** : Appeler directement la base de données depuis la couche présentation / contrôleur.
- ❌ **Sur-abstraction prématurée** : Ne pas créer d'usines à gaz abstraites si une simple fonction pure suffit pour le cas d'usage immédiat.

<!-- PATTERN-DESIGN-END -->
