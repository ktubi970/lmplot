# Model Brain — référence de vérification

Cette page documente la référence de régression de la Task 1 et la matrice
canonique dérivée de `MODEL_REGISTRY`. Elle ne modifie aucune logique
applicative : les fixtures sont déterministes et réservées aux tests.

## Baseline

La baseline a été relevée avant la création des fichiers de cette tâche, sur
la branche `codex/model-brain`.

### Fichiers locaux présents

Commande :

```text
git status --short
```

Sortie exacte :

```text
 M R/mod_eli5.R
 M R/mod_model.R
 M R/mod_simulation.R
 M app.R
 M scripts/run_analysis.R
 M streamlit_app.py
 M tests/test_app.R
 M tests/test_eli5.R
 M tests/test_model.R
 M tests/test_server.R
 M tests/test_simulation.R
?? .agents/
?? .dockerignore
?? .streamlit/
?? AGENTS.md
?? Dockerfile
?? Rplots.pdf
?? artifacts/test_out.json
?? artifacts/test_req.json
?? docker-compose.yml
?? graphify-out/
?? test_out.log
?? tests/_problems/
```

### Suite historique R

Commande demandée :

```text
Rscript -e "testthat::test_dir('tests', reporter='summary')"
```

Dans l'environnement de travail, `Rscript` n'est pas dans le `PATH`. La même
commande a donc été exécutée avec l'exécutable installé à
`C:\Program Files\R\R-4.6.0\bin\Rscript.exe`.

Résultat : **échec historique conservé, code 1**. Les tests ont progressé
jusqu'à `simulation` et `visualization`; un seul test échoue :
`test_app.R:110:3`, « the real beta app completes its browser smoke », avec
`Error in startup(port = port, ...) : Chrome debugging port not open after 10 seconds.`
Les autres tests affichent les points de réussite (`acceptance`, `app`,
`app_structure`, `config`, `eli5`, `example_manifest`, `example_sources`,
`examples`, `model`, `real_data_acceptance`, `release`,
`scientific_metadata`, `server`, `simulation`, `visualization`).

Extrait pertinent de la sortie :

```text
══ Failed ══════════════════════════════════════════════════════════════════════
── 1. Error ('test_app.R:110:3'): the real beta app completes its browser smoke
Error in `startup(port = port, ...)`: Chrome debugging port not open after 10 seconds.
══ DONE ════════════════════════════════════════════════════════════════════════
Error:
! Test failures.
Execution halted
R_DIRECT_EXIT=1
```

### Compilation Python

Commande :

```text
python -m py_compile streamlit_app.py
```

Résultat : **PASS, code 0** (aucune sortie).

## Preuve TDD RED/GREEN

### RED

Le helper a d'abord été écrit avec la matrice dérivée de `MODEL_REGISTRY` et
les deux assertions temporaires demandées. Commande équivalente avec le chemin
absolu de R (le binaire `Rscript` n'étant pas dans le `PATH`) :

```text
Rscript -e "source('R/config.R'); source('R/mod_model.R'); source('R/mod_simulation.R'); source('tests/helper-model-brain.R')"
```

Sortie pertinente :

```text
Error in model_brain_cases() :
  could not find function "model_brain_cases"
Calls: source -> withVisible -> eval -> eval -> stopifnot -> nrow
Execution halted
RED_EXIT=1
```

La panne est donc bien due à l'interface manquante, et non à une faute de
syntaxe du test.

### GREEN

Après ajout minimal de `model_brain_cases()` et
`fit_model_brain_case()`, les assertions temporaires ont été retirées. La
vérification indépendante suivante réussit avec exactement 15 lignes :

```text
Rscript -e "source('R/config.R'); source('R/mod_model.R'); source('R/mod_simulation.R'); source('tests/helper-model-brain.R'); stopifnot(nrow(model_brain_cases()) == 15L)"
```

Résultat : **PASS, code 0** (`GREEN_EXIT=0`). Une vérification supplémentaire
ajoute les 15 ajustements, contrôle les quatre champs retournés, les 15 clés
uniques, les cinq groupes GLMM et la reproductibilité des données à seed fixe;
elle réussit également (`MATRIX_FIT_EXIT=0`). Un avertissement R de convergence
binomiale est émis pour une combinaison historique, sans échec.

## Matrice canonique

`model_brain_cases()` développe chaque élément `MODEL_REGISTRY[[id]]$links`,
dans l'ordre du registre, sans ajouter de combinaison :

| # | `model_type` | `link` |
|---:|---|---|
| 1 | `lm_2d` | `identity` |
| 2 | `lm_3d` | `identity` |
| 3 | `glm_binomial_2d` | `logit` |
| 4 | `glm_binomial_2d` | `probit` |
| 5 | `glm_binomial_2d` | `cloglog` |
| 6 | `glm_binomial` | `logit` |
| 7 | `glm_binomial` | `probit` |
| 8 | `glm_binomial` | `cloglog` |
| 9 | `glm_poisson` | `log` |
| 10 | `glm_poisson` | `identity` |
| 11 | `glm_poisson` | `sqrt` |
| 12 | `glm_gamma` | `inverse` |
| 13 | `glm_gamma` | `log` |
| 14 | `glm_gamma` | `identity` |
| 15 | `glmm` | `identity` |

`fit_model_brain_case(case, n = 80L, seed = 42L)` appelle les chemins
existants `simulate_data()` puis `fit_model()`, force cinq groupes pour le
GLMM et retourne `model_type`, `link`, `data` et `fit`.

## Fichiers de la tâche

- `docs/model-brain-verification.md`
- `tests/helper-model-brain.R`

Les modifications locales listées dans la baseline n'ont pas été réparées,
modifiées, indexées ou incluses dans ce travail.
