# LLM Audit — Spécification de conception

**Statut :** conception et spécification écrite approuvées pour planification

**Date :** 2026-08-15

**Dépôt :** LM Plot Explorer

**Public prioritaire :** chercheur ML et data scientist

## 1. Objectif

Ajouter à LM Plot Explorer un espace distinct permettant d’auditer des réponses
de modèles de langage. Cet espace doit examiner la qualité des données, conserver
une correction multidimensionnelle, comparer les modèles et les concepts
mobilisés, mesurer les désaccords entre évaluateurs et n’autoriser une
interprétation causale que lorsque son identifiabilité est justifiée.

Le système doit pouvoir conclure explicitement qu’une cause n’est pas
identifiable. Une association ne doit jamais être présentée comme une cause.

## 2. Périmètre du MVP

Le MVP couvre :

- des projets locaux contenant jusqu’à 100 000 réponses ;
- l’import CSV, TSV, JSONL et Parquet ;
- un mappage flexible vers un modèle interne strict ;
- la quarantaine des enregistrements invalides ;
- les évaluations déterministes, humaines, importées ou effectuées par un LLM
  local ;
- cinq dimensions de correction distinctes ;
- des graphes conceptuels attendus et extraits ;
- les statistiques descriptives, les incertitudes et les comparaisons de
  modèles ;
- les comparaisons appariées, les interventions contrôlées et les modèles à
  effets mixtes ;
- un rapport canonique JSON, un rapport Markdown et un tableau de bord
  Streamlit construits sur les mêmes résultats ;
- un adaptateur facultatif vers les méthodes R existantes.

Le MVP exclut :

- l’authentification et la collaboration multiutilisateur ;
- l’exécution des modèles évalués ;
- tout appel cloud ;
- les appels externes implicites et la télémétrie réseau ;
- une base de données graphe ;
- la découverte automatique de DAG ;
- une conclusion causale obtenue à partir d’une simple corrélation ;
- les PDF et autres documents non structurés en entrée ;
- une infrastructure distribuée ;
- le chiffrement applicatif des données au repos.

## 3. Architecture retenue

Le nouvel espace suit l’option C : un cœur analytique Python indépendant, une
interface Streamlit légère, un adaptateur R facultatif et l’application Shiny
LM/GLM/GLMM maintenue séparément.

```text
Fichiers locaux
    -> ingestion et mappage confirmé
    -> données normalisées et versionnées
    -> services d’évaluation, de connaissance et d’analyse
    -> AuditRun immuable
    -> AuditReport JSON canonique
    -> rapport Markdown + tableau de bord Streamlit

Méthode R demandée
    -> adaptateur R facultatif
    -> résultat typé ou méthode indisponible
```

Le package Python `llm_audit` contient :

- `domain` : objets typés, identités, contraintes et transitions ;
- `ingestion` : lecture, aperçu, proposition de mappage, validation et
  quarantaine ;
- `storage` : projets, versions, transactions et artefacts ;
- `evaluation` : évaluations, résolutions et provenance des évaluateurs ;
- `knowledge` : concepts, relations et versions de graphes ;
- `statistics` : descriptions, incertitudes, accords et comparaisons ;
- `causality` : vérification d’identifiabilité et estimation conditionnelle ;
- `reporting` : schéma canonique JSON et rendu Markdown ;
- `adapters` : intégrations facultatives, dont R et LLM local ;
- `ui` : pages et composants Streamlit sans logique scientifique.

### 3.1 Règles de frontière

- Streamlit orchestre les actions et affiche des résultats ; il ne calcule
  aucun résultat scientifique.
- Un LLM ne crée aucune métrique numérique, ne décide pas du statut causal et
  ne peut pas ajouter une conclusion au rapport factuel.
- Toute analyse consomme une version de données normalisée et figée.
- Chaque exécution référence explicitement ses données, son plan, ses versions
  logicielles et sa graine.
- L’absence de R ne bloque que les méthodes dont le plan exige R.
- L’espace d’audit n’utilise pas le schéma historique `X`, `Y`, `Z`, `Group`.

## 4. Modèle de données

Le modèle logique est relationnel, normalisé et versionné. Une table large
unique est interdite comme représentation canonique.

### 4.1 Objets principaux

- `Project` : racine locale et identité du projet.
- `SourceArtifact` : fichier importé avec format, taille, empreinte SHA-256 et
  date d’enregistrement.
- `Dataset` : identité logique d’un jeu de données.
- `DatasetVersion` : instantané immuable créé après confirmation du mappage.
- `Example` : unité évaluée contenant `example_id`, `prompt`, les références
  facultatives et les valeurs de caractéristiques.
- `ModelRun` : provenance d’une génération déjà effectuée. Cet objet ne lance
  jamais de modèle.
- `ModelResponse` : réponse d’un modèle pour un exemple. Ce nom remplace
  `Response` afin d’éviter une identité de domaine trop générique.
- `FeatureDefinition` : déclaration d’une covariable, de son type, de son rôle
  et de ses valeurs admissibles.
- `FeatureValue` : valeur typée d’une covariable pour une unité donnée.
- `Evaluation` : verdict d’un évaluateur sur un seul critère.
- `EvaluationResolution` : décision ou consensus dérivé qui référence toutes
  les évaluations sources sans les remplacer.
- `Concept` et `Relation` : éléments d’un graphe conceptuel.
- `ConceptGraphVersion` : version attendue ou extraite d’un graphe.
- `Intervention` : facteur déclaré comme intervention avec ses niveaux, son
  unité et son mécanisme d’assignation.
- `AnalysisPlan` : plan d’analyse figé avant le calcul.
- `AuditRun` : identité, entrées et configuration immuables d’une exécution.
- `AuditRunEvent` : progression, avertissement ou résultat terminal ajouté à
  l’historique du run.
- `AuditReport` : sortie canonique versionnée d’un run terminé.

### 4.2 Contraintes d’identité et de cardinalité

- `example_id` est unique dans une `DatasetVersion`.
- Une réponse est identifiée par `dataset_version_id`, `example_id`,
  `model_run_id` et `sample_id`. `sample_id` vaut `0` lorsqu’une seule réponse
  existe pour cette combinaison.
- `model_id` appartient à `ModelRun` et reste présent dans la projection
  canonique des réponses.
- Les champs `example_id`, `model_id`, `prompt` et `response` sont non nuls et
  non vides après mappage.
- Toute référence entre objets est contrôlée par intégrité référentielle.
- Une version validée n’est jamais modifiée ; une correction crée une nouvelle
  version qui référence sa version parente.
- Les identifiants techniques des objets sont des UUIDv7. Les identifiants
  métier importés, dont `example_id`, restent des chaînes opaques et ne sont
  jamais réécrits.
- Les empreintes de contenu utilisent SHA-256.

### 4.3 Caractéristiques extensibles

Les facteurs comme le modèle, la variante du prompt, la méthode de retrieval,
le contexte, le domaine ou une catégorie métier sont représentés par
`FeatureDefinition` et `FeatureValue`. Une caractéristique possède un type
explicite : chaîne, catégorie, entier, nombre réel, booléen ou date-heure.

Une caractéristique n’acquiert aucune interprétation causale du seul fait de sa
présence. Elle doit être référencée par une `Intervention` valide.

## 5. Ingestion, mappage et quarantaine

L’ingestion suit les étapes suivantes :

1. enregistrer le `SourceArtifact` et calculer son empreinte ;
2. détecter le format et lire un aperçu borné ;
3. proposer un mappage sans l’appliquer ;
4. demander une confirmation explicite ;
5. valider et normaliser l’ensemble des lignes ;
6. placer les lignes invalides en quarantaine ;
7. créer et sceller la `DatasetVersion`.

La proposition de mappage reste un brouillon. Une analyse ne peut pas démarrer
avant sa confirmation.

Chaque ligne en quarantaine conserve :

- le fichier et la position source ;
- la charge utile originale lorsque sa conservation est autorisée, sinon son
  empreinte ;
- un code d’erreur stable ;
- un message explicite ;
- les champs concernés.

Aucune ligne n’est supprimée silencieusement. Le rapport indique le nombre
importé, accepté, mis en quarantaine et exclu de chaque analyse.

## 6. Stockage local et versionnement

Chaque projet utilise :

- DuckDB pour le catalogue, les identités, les relations et les tables de
  taille ordinaire ;
- Parquet pour les tables volumineuses sélectionnées par le stockage ;
- JSON pour les manifests, plans et rapports canoniques versionnés ;
- Markdown pour les rapports narratifs dérivés.

L’arborescence canonique d’un projet est :

```text
<project>/catalog.duckdb
<project>/sources/<source_artifact_id>/
<project>/data/<dataset_version_id>/
<project>/runs/<run_id>/manifest.json
<project>/runs/<run_id>/audit-report.json
<project>/runs/<run_id>/audit-report.md
```

DuckDB reste le catalogue logique même lorsqu’une table physique est en
Parquet. Le manifest du projet indique, pour chaque table, son emplacement, son
schéma et son empreinte afin d’éviter deux sources concurrentes.

Les écritures DuckDB sont transactionnelles. Les artefacts sont écrits dans un
fichier temporaire du même volume, vérifiés, puis renommés atomiquement.

Le cœur immuable d’un `AuditRun` est enregistré avant l’exécution. La
progression est ajoutée sous forme d’`AuditRunEvent`. Un seul événement
terminal, succès ou échec, peut être ajouté. Un résultat terminal et ses
artefacts ne sont jamais remplacés.

## 7. Évaluation multidimensionnelle

Les dimensions initiales sont :

- exactitude factuelle ;
- pertinence ;
- complétude ;
- respect des instructions ;
- alignement avec les concepts attendus.

Chaque `Evaluation` porte exactement un critère, un verdict appartenant au
vocabulaire déclaré par ce critère, une preuve facultative, l’évaluateur, sa
méthode, sa version et sa provenance.

Un juge LLM local produit uniquement un verdict catégoriel structuré et des
preuves textuelles. Les scores, taux et intervalles sont calculés ensuite par
des fonctions déterministes. Le texte audité est traité comme une donnée non
fiable et ne peut donner au juge aucune instruction opérationnelle.

La priorité recommandée est :

```text
test déterministe > consensus humain > humain unique > LLM local
```

Cette priorité alimente une `EvaluationResolution` distincte. Les évaluations
sources et leurs désaccords restent visibles et analysables.

## 8. Graphes de connaissance

Le système distingue :

- un graphe attendu provenant d’une référence ou d’une ontologie ;
- un graphe extrait de la réponse du modèle.

Une `ConceptGraphVersion` suit le cycle :

```text
proposé -> révisé -> validé
```

Seul un graphe attendu au statut `validé` peut servir de vérité de référence.
Un graphe proposé par un LLM local n’est jamais validé automatiquement.

La comparaison déterministe produit :

- la couverture des concepts attendus ;
- les concepts manquants ;
- les ajouts non justifiés ;
- les relations attendues retrouvées ;
- les relations incorrectes ;
- les preuves textuelles liées aux concepts et relations.

Sans graphe attendu validé, le système décrit le graphe extrait mais ne mesure
pas sa correction.

## 9. Plan et pipeline d’analyse

### 9.1 `AnalysisPlan`

Avant le calcul, le plan fixe :

- la population et les exclusions ;
- les dimensions et critères d’évaluation ;
- la règle déterministe transformant un verdict en succès ou échec ;
- les comparaisons, sous-groupes et familles de tests ;
- le niveau de confiance ;
- le traitement des valeurs manquantes ;
- la méthode de correction de multiplicité ;
- les interventions, estimands et hypothèses causales ;
- la graine et le moteur statistique de chaque méthode.

Le MVP utilise un niveau de confiance de 95 %, un seuil de faux taux de
découverte Benjamini-Hochberg de 0,05 et 2 000 réplications pour les intervalles
bootstrap. Ces valeurs sont enregistrées dans le plan et ne peuvent pas être
modifiées après le lancement du run.

Toute modification produit une nouvelle version du plan et impose un nouvel
`AuditRun`.

### 9.2 Qualité et éligibilité

Le pipeline contrôle les doublons, identifiants orphelins, types invalides,
données manquantes, couverture des évaluations, disponibilité des paires par
`example_id`, couverture par facteur, statut des graphes et cohérence des
interventions.

Chaque constat est classé `bloquant` ou `avertissement`. Les exclusions, leur
raison et le dénominateur de chaque résultat sont exposés.

### 9.3 Statistiques

Le MVP produit :

- effectifs, distributions et données manquantes ;
- taux de réussite par dimension avec intervalle de confiance de Wilson ;
- accord brut, matrices de désaccord et coefficient de Krippendorff lorsque le
  nombre et le type d’évaluateurs le permettent ;
- comparaisons appariées par `example_id` ;
- différences de risque et autres tailles d’effet avec incertitude ;
- modèles à effets mixtes pour les mesures répétées ou imbriquées ;
- résultats stratifiés par modèle, concept et intervention.

Les résultats appariés ou groupés utilisent un bootstrap qui rééchantillonne
les unités `example_id` et enregistre sa graine. Les familles de comparaisons
multiples utilisent Benjamini-Hochberg. Les tailles d’effet et leurs
intervalles priment sur les seules valeurs de p.

## 10. Causalité

Le système distingue :

1. description ;
2. association ;
3. estimation causale sous hypothèses explicites.

Une variable ne reçoit une interprétation causale que si elle est déclarée
comme `Intervention`. Les facteurs initiaux admissibles sont le modèle, la
variante du prompt, la méthode de retrieval et le contexte fourni.

### 10.1 Porte d’identifiabilité

Un vérificateur déterministe examine :

- l’intervention, ses niveaux et son unité ;
- la population, le résultat et le contraste ;
- le mécanisme d’assignation ;
- la temporalité des variables ;
- l’appariement ou la comparabilité ;
- le support entre niveaux ;
- l’absence d’ajustement sur une variable postérieure à l’intervention ;
- les hypothèses de cohérence, non-interférence et données manquantes.

Le statut est exactement l’un des suivants :

- `identified` : le dispositif et les hypothèses justifient l’estimand ;
- `fragile` : l’estimation est possible mais dépend d’une hypothèse critique ou
  d’un support limité ;
- `non_identifiable` : aucune interprétation causale n’est autorisée.

`non_identifiable` est un résultat scientifique valide. Le système peut encore
produire une description ou une association portant une étiquette explicite.

### 10.2 Estimation conditionnelle

Après franchissement de la porte seulement, le MVP autorise :

- une comparaison appariée sur les mêmes `example_id` ;
- une intervention contrôlée ;
- une taille d’effet avec intervalle d’incertitude ;
- un modèle à effets mixtes lorsque la structure l’exige ;
- des diagnostics de support, de sensibilité et de données manquantes.

Aucune découverte automatique de DAG n’est effectuée. Un LLM ne propose ni
statut d’identifiabilité ni conclusion causale.

## 11. Adaptateurs R et LLM local

L’adaptateur R reçoit une requête typée, appelle une méthode explicitement
choisie et retourne un résultat conforme à un schéma versionné. L’absence du
runtime, d’un package ou d’une méthode produit `method_unavailable` pour cette
étape sans bloquer les analyses indépendantes.

Le LLM local est facultatif et désactivable. Il peut :

- proposer des verdicts catégoriels et leurs preuves ;
- proposer un graphe conceptuel ;
- reformuler un texte factuel déjà produit.

Il ne peut pas :

- créer une métrique numérique ;
- modifier l’`AuditReport` ;
- valider un graphe attendu ;
- décider de l’identifiabilité ;
- ajouter une conclusion ou une relation causale ;
- utiliser des outils, le réseau ou le système de fichiers.

## 12. Interface Streamlit

L’interface suit le parcours :

```text
Créer un audit -> importer -> mapper -> valider
-> configurer les évaluations -> analyser
-> réviser les conclusions -> exporter
```

Les pages sont :

1. projet ;
2. import et aperçu ;
3. mappage et validation ;
4. qualité et quarantaine ;
5. évaluations et graphes ;
6. plan d’analyse ;
7. exécution ;
8. résultats, révision et export.

Le projet, la version du dataset, la version du plan et le `run_id` restent
visibles. Les tables sont filtrées et paginées côté stockage ; Streamlit ne
matérialise jamais les 100 000 réponses.

Chaque résultat montre sa valeur, son unité, son effectif, son dénominateur,
son intervalle, sa méthode, ses filtres et ses avertissements. Les niveaux
`description`, `association` et `causal` sont exprimés en texte ; la couleur
seule ne les distingue jamais.

Chaque vue traite les états chargement, vide, partiel, erreur récupérable et
accès au système de fichiers refusé. L’indisponibilité de R ou du LLM local est
un état de méthode, pas une panne globale.

## 13. Rapports

L’`AuditReport` JSON est la source de vérité des sorties analytiques. Il ne
remplace pas les données sources ni leur catalogue.

La première version du schéma porte l’identifiant
`llm-audit-report/1.0`. Le document contient :

- `schema_version`, `run_id`, versions d’entrées et empreintes ;
- qualité, exclusions et données manquantes ;
- résultats par dimension et accords d’évaluation ;
- analyses conceptuelles ;
- comparaisons et tailles d’effet ;
- statut causal, estimand et hypothèses ;
- limites, avertissements et provenance.

Chaque mesure contient son nom, sa valeur, son unité, son effectif, son
dénominateur, son intervalle, sa méthode, ses filtres et ses références de
provenance.

Le rapport Markdown est généré uniquement depuis le JSON par des gabarits
déterministes. Une reformulation par LLM local est stockée dans un artefact
secondaire non autoritatif, comparée au texte source et soumise à validation
humaine. Elle ne modifie ni le JSON ni le rapport déterministe.

Le tableau de bord des résultats lit le même JSON. Une valeur affichée ne doit
jamais être recalculée dans Streamlit.

## 14. Erreurs et reprise

Les familles d’erreurs sont : `mapping`, `validation`, `storage`, `evaluation`,
`analysis_prerequisite`, `method_unavailable`, `privacy` et `internal`.

Chaque erreur utilisateur indique l’étape, l’objet concerné, la cause, une
action de récupération et un identifiant technique. Les entrées saisies sont
préservées après une erreur récupérable.

Une méthode défaillante n’invalide pas un résultat indépendant. Le rapport
partiel signale explicitement toute section absente. Une reprise est
idempotente et ne remplace jamais un run terminal.

## 15. Confidentialité et sécurité locale

- Le MVP ne contient aucun client cloud et n’effectue aucun appel réseau
  non-loopback sortant.
- Les juges et reformulations LLM sont exécutés localement.
- Un adaptateur LLM peut joindre un service strictement local sur l’interface
  loopback. L’URL, le modèle et sa version sont enregistrés dans la provenance.
- Les prompts et réponses ne sont pas écrits dans les journaux techniques par
  défaut.
- Les contenus importés sont échappés à l’affichage et à l’export. Aucun HTML,
  script ou code importé n’est exécuté.
- Le LLM local reçoit le contenu audité dans une enveloppe de données non
  fiable et ne dispose d’aucun outil.
- Sans authentification MVP, les permissions du système d’exploitation
  contrôlent l’accès aux fichiers.
- `llm_audit` n’ajoute aucun chiffrement au repos. L’interface et la
  documentation indiquent que la protection dépend du chiffrement du disque et
  des permissions locales.
- Une intégration externe future exigerait un consentement par opération et
  enregistrerait fournisseur, modèle, finalité, champs transmis et date. Cette
  extension reste hors périmètre du MVP.

## 16. Reproductibilité

Un run référence :

- les versions et empreintes de toutes les entrées ;
- le plan d’analyse ;
- les versions du package, des dépendances et de l’adaptateur éventuel ;
- les méthodes et paramètres ;
- les graines aléatoires ;
- l’identité et la version des évaluateurs ;
- les artefacts produits et leurs empreintes.

Le contenu analytique est sérialisé selon la canonicalisation JSON RFC 8785
avant calcul de son empreinte SHA-256. Les champs `run_id`, dates et durées sont
exclus de ce contenu canonique.

Deux runs exécutés avec les mêmes entrées, plan, versions et graines doivent
produire le même contenu analytique et la même empreinte de résultats. Leurs
`run_id` et horodatages peuvent différer et sont exclus de cette empreinte.

## 17. Stratégie de tests

Le développement suit test en échec, implémentation minimale et
refactorisation. Les couches automatisées sont :

1. domaine : types, contraintes, identités, immutabilité et transitions ;
2. ingestion : quatre formats, encodages, mappages et quarantaine ;
3. stockage : transactions, Parquet, atomicité, migrations et empreintes ;
4. évaluation : dimensions, priorités, désaccords et résolutions ;
5. statistiques : jeux de référence, tolérances numériques et propriétés ;
6. connaissance : versions, transitions et comparaison des graphes ;
7. causalité : table de décision comprenant tous les refus attendus ;
8. rapports : schéma JSON, rendu Markdown et traçabilité des faits ;
9. adaptateurs : contrats R et LLM local, disponibilité et isolement ;
10. interface : parcours principal et cinq états système ;
11. confidentialité : réseau interdit, journaux expurgés et contenus neutralisés ;
12. régression : suites historiques Shiny, R et Streamlit.

Les tests statistiques vérifient notamment les bornes des taux, l’ordre des
intervalles, l’invariance à la permutation des lignes et le respect des unités
d’appariement.

## 18. Critères d’acceptation

Le MVP est accepté lorsque :

1. les quatre formats produisent le même modèle canonique pour des données
   équivalentes ;
2. aucune analyse ne démarre avant confirmation du mappage ;
3. toute ligne invalide est mise en quarantaine avec une raison exploitable ;
4. les cinq dimensions restent distinctes dans les données, analyses et
   rapports ;
5. les évaluations contradictoires restent consultables après résolution ;
6. seul un graphe attendu validé permet une mesure de correction conceptuelle ;
7. une association sans intervention admissible produit `non_identifiable` ;
8. chaque résultat causal indique estimand, hypothèses, effet et incertitude ;
9. la reproductibilité définie à la section 16 est vérifiée ;
10. le JSON respecte son schéma et le Markdown n’ajoute aucun fait ;
11. l’application fonctionne sans R et sans LLM local ;
12. aucun appel réseau non-loopback sortant n’est observé pendant la suite MVP ;
13. aucun contenu importé ne peut exécuter du HTML, du code ou une instruction
    destinée au juge ;
14. le parcours complet produit JSON et Markdown sur un projet de référence ;
15. une fixture synthétique de 100 000 réponses d’environ 2 Kio chacune est
    importée et validée en moins de 120 secondes avec moins de 2 Gio de mémoire
    vive sur une machine à 4 cœurs, 8 Gio de RAM et SSD local ;
16. les vues tabulaires restent paginées côté stockage ;
17. `domain`, `causality` et `reporting` atteignent 90 % de couverture de
    branches, et l’ensemble Python atteint 80 % ;
18. tous les tests historiques qui réussissaient avant intervention continuent
    de réussir, et aucun nouvel échec n’est accepté.

## 19. Relation avec le « Model Brain »

La visualisation neuronale des modèles LM/GLM/GLMM appartient à l’application
existante et possède sa propre spécification :
`docs/superpowers/specs/2026-08-15-lm-model-brain-design.md`.

Les deux chantiers peuvent réutiliser des principes de visualisation et de
provenance, mais ne partagent ni modèle de données, ni runtime obligatoire, ni
cycle de livraison. Le « Model Brain » ne devient pas un module de
`llm_audit`.
