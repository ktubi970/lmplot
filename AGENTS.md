## Skill routing

For every user prompt:

1. Review the names and descriptions of all available skills.
2. Select every skill that genuinely matches the request, using the smallest sufficient set.
3. Read each selected `SKILL.md` completely before responding or taking action.
4. Follow the selected skills faithfully and in their required order.
5. Always use a skill explicitly named by the user.
6. Repeat this check for every new prompt; do not assume that a skill selected for a previous prompt still applies.
7. If no skill applies, continue normally.

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
