# LM Model Brain — Spécification de conception

**Statut :** conception validée, relecture écrite requise

**Date :** 2026-08-15

**Dépôt :** LM Plot Explorer

**Interfaces cibles :** Shiny et Streamlit

## 1. Objectif

Donner à LM Plot Explorer un tournant centré sur la visualisation de données en
ajoutant un « Model Brain » : une représentation interactive, exacte et
explicable du calcul effectué par chaque LM, GLM et GLMM pris en charge.

L’interaction principale est l’exploration observation par observation. La
sélection d’un point ou d’une ligne montre comment les valeurs d’entrée, les
coefficients, la fonction de lien et l’éventuel effet aléatoire produisent la
prédiction. Une vue globale complète cette lecture locale avec les
incertitudes, distributions de contributions, résidus et effets aléatoires.

Le « cerveau » est un graphe de calcul scientifique. Il ne simule pas une
architecture biologique et ne dessine aucune couche cachée absente du modèle.

## 2. Séparation de périmètre

Le Model Brain étend l’application LM/GLM/GLMM existante. Il ne fait pas partie
du package `llm_audit`, qui possède un modèle de données, un runtime et un cycle
de livraison indépendants.

Cette séparation préserve la décision architecturale de maintenir Shiny à côté
du nouvel espace d’audit. Les deux spécifications peuvent partager des règles
de rigueur visuelle, mais aucune dépendance fonctionnelle n’est créée.

## 3. Périmètre fonctionnel

Le Model Brain couvre les 15 combinaisons du registre actuel :

| Modèle | Liens | Graphe de calcul |
|---|---|---|
| `lm_2d` | `identity` | biais + X -> prédiction |
| `lm_3d` | `identity` | biais + X + Y -> prédiction |
| `glm_binomial_2d` | `logit`, `probit`, `cloglog` | prédicteur linéaire + lien inverse |
| `glm_binomial` | `logit`, `probit`, `cloglog` | prédicteur linéaire + lien inverse |
| `glm_poisson` | `log`, `identity`, `sqrt` | prédicteur linéaire + lien inverse |
| `glm_gamma` | `inverse`, `log`, `identity` | prédicteur linéaire + lien inverse |
| `glmm` | `identity` | effets fixes + intercept aléatoire de groupe |

Le MVP comprend :

- une représentation neuronale fonctionnellement équivalente ;
- une sélection liée depuis le graphique principal et la table ;
- un sélecteur explicite d’observation accessible au clavier ;
- un graphe de calcul 2D ;
- une décomposition locale des contributions ;
- une visualisation de la fonction de lien ;
- des vues globales des coefficients, contributions et effets aléatoires ;
- le mode populationnel et le mode conditionnel pour le GLMM ;
- un contrat `ModelBrain` versionné commun aux interfaces ;
- un export JSON de ce contrat et les exports graphiques permis par Plotly.

Le MVP exclut :

- l’entraînement d’un réseau neuronal de substitution ;
- les couches cachées artificielles ;
- la rétropropagation et une animation d’entraînement ;
- les réseaux profonds et les architectures de LLM ;
- la reconstruction d’un modèle à partir de ses seules réponses ;
- une visualisation 3D décorative du graphe ;
- une nouvelle bibliothèque graphique majeure ;
- de nouveaux modèles statistiques, formules ou effets aléatoires.

## 4. Principe scientifique

Pour une observation `i`, le Model Brain représente :

```text
contribution du biais       c0 = beta0
contribution du prédicteur  cj = beta_j * x_ij
prédicteur linéaire         eta_i = somme(cj) + u_g(i)
réponse attendue            mu_i = inverse_link(eta_i)
```

Pour LM et GLM, `u_g(i)` vaut zéro. Pour le GLMM conditionnel, il s’agit de
l’intercept aléatoire estimé du groupe de l’observation. Pour le GLMM
populationnel, `u_g(i)` vaut zéro.

Le résidu aléatoire `epsilon` appartient au modèle génératif mais ne constitue
pas une entrée connue de la prédiction. Il est représenté dans la comparaison
entre valeur observée et prédite, jamais comme un nœud actif du trajet
prédictif.

### 4.1 Équivalence et limites

Le mot « neuronal » désigne l’équivalence fonctionnelle entre un prédicteur
linéaire et un neurone. Il ne signifie pas que le modèle R a été entraîné avec
un algorithme neuronal.

- LM : un neurone linéaire avec activation identité.
- GLM : un neurone linéaire suivi de la fonction de lien inverse.
- GLMM : un neurone linéaire enrichi d’une branche structurée d’effet
  aléatoire.

Le nombre de nœuds affiché reflète exactement les termes de la formule. La vue
ne densifie jamais artificiellement le réseau pour le rendre plus spectaculaire.

## 5. Fonctions de lien

Le calcul autoritatif utilise toujours l’objet `family` R et sa fonction
`linkinv`, ou la méthode de prédiction du modèle. Les équations suivantes sont
des libellés explicatifs et des oracles de test, pas une seconde implémentation
dans l’interface.

| Famille et lien | Activation présentée | Domaine de la réponse |
|---|---|---|
| Gaussian `identity` | `mu = eta` | réel |
| Binomial `logit` | `mu = 1 / (1 + exp(-eta))` | `[0, 1]` |
| Binomial `probit` | `mu = Phi(eta)` | `[0, 1]` |
| Binomial `cloglog` | `mu = 1 - exp(-exp(eta))` | `[0, 1]` |
| Poisson `log` | `mu = exp(eta)` | strictement positif |
| Poisson `identity` | `mu = eta` | strictement positif |
| Poisson `sqrt` | `mu = eta^2` | strictement positif |
| Gamma `inverse` | `mu = 1 / eta` | strictement positif |
| Gamma `log` | `mu = exp(eta)` | strictement positif |
| Gamma `identity` | `mu = eta` | strictement positif |

La courbe du lien montre `eta` en abscisse et la réponse attendue dans l’unité
de `Z` en ordonnée. Elle marque la position de l’observation sélectionnée et
signale visuellement les régions invalides pour la famille. Une prédiction non
finie ou hors domaine produit un avertissement et n’est jamais masquée par un
bornage silencieux.

## 6. Contrat canonique `ModelBrain`

Le moteur R est l’unique producteur des valeurs scientifiques du Model Brain.
La fonction publique est :

```r
build_model_brain(fit, df, model_type, link, labels = NULL)
```

Elle retourne une liste sérialisable dont `schema_version` vaut initialement
`model-brain/1.0` et comportant :

- `schema_version` ;
- `model_type`, `family`, `link` et formule ;
- `prediction_modes`, valant `conditional` uniquement sauf pour le GLMM, où
  `population` est également disponible ;
- `labels` et unités disponibles ;
- `topology.nodes` avec identifiant, rôle, libellé et position logique ;
- `topology.edges` avec source, cible, coefficient et terme ;
- `coefficients` avec estimation, erreur standard et intervalle de Wald à 95 %
  calculé par `estimate +/- qnorm(0.975) * standard_error` ;
- `observations` avec identifiant stable, entrées, contributions, effet
  aléatoire, `eta`, prédiction, observation, résidu et indicateurs de validité ;
- `link_curve` avec les coordonnées `eta`, `mu` et la validité de domaine
  calculées par R ;
- `global_summaries` avec, pour chaque terme, minimum, premier quartile,
  médiane, troisième quartile, maximum, valeurs manquantes et un échantillon
  déterministe destiné au tracé ; pour le GLMM, la même structure couvre les
  intercepts aléatoires ;
- `warnings` avec code stable, portée et message.

### 6.1 Identité d’observation

Chaque ajustement reçoit un identifiant d’observation stable dans son
instantané : l’identifiant métier de la source lorsqu’il existe, sinon l’indice
de ligne 1-based après validation des données. Cet identifiant est transmis
comme `customdata` à tous les graphiques liés.

L’observation sélectionnée par défaut est celle dont la valeur ajustée est la
médiane ; en cas d’égalité, l’identifiant lexicalement le plus petit est choisi.

### 6.2 Précision numérique

Le JSON conserve les nombres R en double précision avec huit chiffres
significatifs à la sérialisation actuelle. L’interface affiche au moins six
chiffres significatifs dans les infobulles et adapte les unités visibles. Aucun
arrondi d’affichage ne modifie les valeurs du contrat.

## 7. Architecture d’intégration

### 7.1 Modules R

- `R/mod_model.R` reste responsable du registre, des ajustements et des
  prédictions.
- Un nouveau `R/mod_model_brain.R` extrait coefficients, incertitudes,
  contributions, effets aléatoires et topologie canonique.
- Un nouveau `R/mod_model_brain_plot.R` construit les figures Plotly de Shiny à
  partir du contrat, sans recalculer les valeurs scientifiques.
- `R/mod_visualization.R` ajoute les identifiants d’observation aux graphiques
  existants afin de permettre la sélection liée.

### 7.2 Shiny

`app.R` ajoute un onglet `Model Brain`. Le dernier ajustement réussi contient
le contrat `ModelBrain`. Un clic Plotly, une sélection dans la table ou le
sélecteur explicite met à jour un unique `selected_observation_id` réactif.

Le changement d’observation ne réajuste pas le modèle et ne recalcule pas les
contributions. Un changement de modèle, lien, données ou paramètres ne prend
effet qu’après l’action existante de génération et d’ajustement.

### 7.3 Streamlit

`scripts/run_analysis.R` ajoute `model_brain` au JSON de résultat. Un nouveau
module Python racine `model_brain_viz.py` valide la partie présentation du
contrat et construit les figures Plotly sans formule statistique.

`streamlit_app.py` ajoute l’onglet, conserve l’identifiant sélectionné dans
`st.session_state` et relie la sélection Plotly à la table et au sélecteur
explicite. Un changement de sélection réutilise le JSON mis en cache et ne
relance pas `Rscript`.

### 7.4 Flux

```text
données + modèle + lien
    -> ajustement R existant
    -> build_model_brain()
    -> contrat versionné
       -> rendu Plotly Shiny
       -> JSON R/Python -> rendu Plotly Streamlit

observation sélectionnée
    -> filtre du contrat pré-calculé
    -> cerveau + cascade + lien + vues liées
    -> aucun réajustement
```

## 8. Composition de l’onglet

L’ordre visuel est :

1. contexte : modèle, famille, lien, formule, mode de prédiction et N ;
2. sélecteur d’observation et actions précédent/suivant ;
3. graphe de calcul 2D ;
4. décomposition numérique de l’équation ;
5. cascade des contributions locales ;
6. courbe de lien avec le point courant ;
7. vues globales ;
8. table des valeurs sous-jacentes et export.

Sur écran large, le graphe et la décomposition sont côte à côte. Sur écran
étroit, ils sont empilés dans le même ordre. Le contexte et l’observation
sélectionnée restent visibles pendant l’exploration.

## 9. Encodages visuels

### 9.1 Graphe de calcul

Le graphe est orienté de gauche à droite : entrées, contributions, `eta`, lien
inverse et prédiction.

- positif : trait continu bleu-vert ;
- négatif : trait tireté orange ;
- nul ou négligeable à la précision affichée : trait pointillé gris ;
- épaisseur : valeur absolue de la contribution locale, normalisée uniquement
  à l’intérieur de l’observation sélectionnée ;
- forme du nœud : rôle, afin que la couleur ne soit jamais le seul canal ;
- flèche : direction du calcul.

L’épaisseur représente `abs(beta_j * x_ij)`, jamais `abs(beta_j)`. L’infobulle
affiche simultanément la valeur brute, le coefficient et la contribution pour
éviter de confondre poids global et effet local.

La normalisation d’épaisseur est locale à l’observation. La légende indique que
les épaisseurs ne sont pas comparables entre deux observations ; les valeurs
exactes permettent cette comparaison.

Le biais est un nœud séparé. Le GLMM ajoute un nœud `u_group`, avec le groupe et
sa valeur exacte. Le mode populationnel rend cette branche inactive et indique
explicitement `u_group = 0`.

### 9.2 Décomposition locale

Une cascade part du biais, ajoute chaque contribution dans l’ordre de la
formule, puis aboutit à `eta`. Une étape séparée applique le lien inverse et
aboutit à la prédiction. La valeur observée et le résidu sont affichés comme
comparaison, pas comme composants de la prédiction.

### 9.3 Vues globales

- un forest plot des coefficients avec intervalle à 95 % et ligne de référence
  zéro ;
- un box plot par terme montrant médiane, quartiles et étendue des contributions
  locales ; jusqu’à 1 000 points sont superposés, sélectionnés par un
  échantillonnage déterministe lorsque N est supérieur à 1 000 ;
- la vue résidus-valeurs ajustées existante avec sélection liée ;
- pour le GLMM, un dot plot ordonné des intercepts aléatoires ;
- un accès à la table exacte sous-jacente.

Chaque axe indique son unité, la mention `unité non fournie` lorsque la source
n’en fournit aucune, ou précise qu’il s’agit de l’échelle de `eta`.
Chaque vue indique N, valeurs manquantes et mode conditionnel ou populationnel.
Les barres commencent à zéro lorsque leur longueur encode une magnitude. Les
axes tronqués sont explicitement signalés.

### 9.4 Interaction

- clic ou sélection rectangulaire dans le graphique principal ;
- clic sur une ligne de table ;
- sélecteur clavier et actions précédent/suivant ;
- zoom, panoramique et réinitialisation ;
- activation ou masquage des séries globales ;
- infobulles numériques complètes ;
- export des données filtrées et du contrat JSON ;
- export SVG ou PNG par la barre Plotly lorsqu’il est disponible.

Une transition inférieure à 250 ms peut accompagner un changement de
sélection. Aucune pulsation continue, particule animée ou déplacement gratuit
n’est autorisé.

## 10. États, erreurs et avertissements

L’onglet gère :

- aucun modèle ajusté : invitation à générer et ajuster ;
- construction du contrat : progression locale ;
- contrat partiel : avertissement et vues disponibles ;
- observation absente après changement de données : retour à l’observation par
  défaut ;
- coefficient ou intervalle indisponible : valeur `NA` explicitement affichée ;
- prédiction non finie ou hors domaine : avertissement scientifique visible ;
- effet aléatoire indisponible dans le moteur de repli : branche marquée
  indisponible, jamais remplacée par une estimation inventée ;
- contrat invalide : onglet en erreur récupérable, dernier résultat valide
  conservé.

Un échec du Model Brain ne masque ni le graphique principal, ni le résumé, ni
les diagnostics existants.

## 11. Accessibilité

- Le contraste respecte WCAG 2.2 AA : 4,5:1 pour le texte et 3:1 pour les
  éléments graphiques.
- Chaque interaction à la souris possède un équivalent clavier.
- Les nœuds et connexions ont des libellés accessibles.
- La couleur est doublée par une forme, un style de trait ou un texte.
- L’ordre de tabulation suit l’ordre de calcul.
- Une table fournit toutes les valeurs représentées graphiquement.
- Le mode de mouvement réduit désactive les transitions.

## 12. Performance

Le contrat est construit une seule fois par ajustement. La sélection d’une
observation filtre les données précalculées et ne relance ni l’ajustement ni
`Rscript`.

Sur une machine à 4 cœurs, 8 Gio de RAM et SSD local, pour 5 000 observations
et le modèle le plus complexe pris en charge :

- la construction du contrat ajoute moins de 2 secondes au résultat R ;
- le contrat sérialisé reste inférieur à 25 Mio ;
- un changement d’observation déjà chargé met à jour les vues en moins d’une
  seconde au 95e percentile sur dix sélections successives.

Les vues globales utilisent des agrégats ou un échantillonnage déterministe si
un navigateur ne peut pas afficher tous les points, mais la table et les
calculs conservent toutes les observations. Tout échantillonnage est signalé
avec son N affiché.

## 13. Stratégie de tests

Le développement suit test en échec, implémentation minimale puis
refactorisation.

### 13.1 Tests scientifiques R

Pour chacune des 15 combinaisons :

- la somme des contributions et de l’effet aléatoire reproduit `eta` ;
- l’application du lien inverse reproduit `predict_response()` ;
- l’écart accepté est `max(1e-10, 1e-8 * abs(valeur_attendue))` ;
- les résidus reproduisent la convention actuelle sur l’échelle de réponse ;
- les coefficients, erreurs standard et intervalles correspondent au fit ;
- toutes les valeurs hors domaine sont détectées ;
- les identifiants d’observation sont uniques et stables dans l’instantané.

Pour le GLMM :

- le mode populationnel exclut l’intercept aléatoire ;
- le mode conditionnel inclut exactement l’intercept du groupe ;
- les deux modes reproduisent les prédictions R correspondantes ;
- les moteurs `lme4`, `nlme` et le repli documenté ont un comportement explicite.

### 13.2 Tests de contrat

- validation du schéma et de sa version ;
- rejet des nœuds orphelins, cycles et identifiants dupliqués ;
- nombres non finis convertis en valeur absente accompagnée d’un avertissement ;
- sérialisation R vers JSON puis validation Python ;
- absence de formule scientifique dans les renderers.

### 13.3 Tests de visualisation

- topologie attendue pour LM, GLM et GLMM ;
- signe, trait, forme et épaisseur cohérents avec les contributions ;
- axes, unités, N et modes de prédiction présents ;
- intervalle à 95 % présent dans le forest plot ;
- sélection liée entre graphique, cerveau, diagnostics et table ;
- alternative clavier fonctionnelle ;
- absence de 3D décorative et de couleur utilisée seule ;
- export du contrat et accès aux données sous-jacentes.

### 13.4 Régression

Les suites historiques `test_model.R`, `test_visualization.R`, `test_server.R`,
`test_app.R` et les tests Streamlit existants sont exécutés avant et après
l’extension. Tout échec préexistant est enregistré ; aucun nouvel échec n’est
accepté.

Les modifications locales présentes avant l’implémentation sont conservées et
ne sont ni annulées ni incluses accidentellement dans les commits du Model
Brain.

## 14. Critères d’acceptation

Le Model Brain est accepté lorsque :

1. les 15 combinaisons produisent un contrat valide ;
2. chaque prédiction du contrat reproduit le moteur R dans la tolérance définie ;
3. aucun nœud ou couche fictive n’est affiché ;
4. les modes conditionnel et populationnel du GLMM sont distincts et exacts ;
5. un clic sur un point met à jour l’observation dans Shiny et Streamlit ;
6. le sélecteur clavier fournit le même résultat que le clic ;
7. changer d’observation ne réajuste pas le modèle et ne relance pas Rscript ;
8. le graphe, la cascade et la courbe de lien affichent les mêmes `eta` et
   prédiction ;
9. chaque infobulle expose entrée, coefficient, contribution, prédiction,
   observation et résidu applicables ;
10. les vues globales montrent les intervalles, N, unités et données manquantes ;
11. une prédiction invalide est signalée sans bornage silencieux ;
12. l’échec de l’onglet ne casse aucune vue historique ;
13. les exigences d’accessibilité et de performance sont vérifiées ;
14. tous les tests historiques réussissant avant l’extension continuent de
    réussir ;
15. aucun module de `llm_audit` ne devient une dépendance du Model Brain.
