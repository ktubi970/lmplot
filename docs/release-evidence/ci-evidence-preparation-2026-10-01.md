# Préparation de preuves CI supplémentaires — 1 octobre 2026

Objectif : rendre LM Plot Explorer publiable sans ajouter de fonctionnalités ni modifier son architecture. Le tour précédent a produit un progrès vérifiable : push autorisé de 42e70f3, résultat Ubuntu vert, deux échecs Windows distincts archivés et décision NO-GO. La présente continuation a revalidé l'état distant : master reste à 42e70f3, run 36867203181 tentative 2 terminé en failure. Aucun job distant n'est encore actif.

## Diagnostic local de la première navigation

L'inspection de shinytest2 0.5.1 confirme que `app_start_shiny()` attend l'annonce « Listening » sans requête HTTP préalable. `app_initialize_()` appelle ensuite `Page.navigate` sans délai explicite; la session Chromote applique 10 secondes. Les délais AppDriver de 100 secondes couvrent d'autres phases. Source chargée : [inspection des fonctions](inspect-browser-navigation.log).

L'application ne lance pas d'analyse scientifique à l'initialisation : résultat initial NULL, vues protégées par `req(result())`, événement Generate avec `ignoreInit=TRUE`. Le premier rendu HTTP peut compiler le thème Bootstrap personnalisé et les composants Sass. Aucun chargement distant de police ou de CDN n'a été identifié dans les sources examinées.

Trois mesures distinctes, toutes exit 0, sans modification applicative ni augmentation des délais :

| Mesure | Observation | Limite |
| --- | --- | --- |
| [Première navigation AppDriver](first-navigation-local-1.log) | Chrome 154.0.8037.59, session CDP 10 s; en-têtes du Document après 6687 ms, navigation environ 6,74 s; application prête après 27,24 s au total. | Une exécution locale instrumentée; ne reproduit pas le timeout distant. |
| [Deux GET avec cache Sass vide](first-http-profile.log) | Premier HTTP 200 en 3,83 s, renderPage 3,77 s, compilation thème 1,633 s; second HTTP 200 en 0,62 s. Le profil échantillonné inclut compilation et copies de fichiers. | Autre processus, sans navigateur. Les durées ne s'additionnent pas à celles du premier essai. Profils [premier GET](first-http-1.Rprof) et [second GET](first-http-2.Rprof). |
| [Script de diagnostic proposé](ci-browser-diagnostic-local.log) | Chrome réel, cache Sass distinct vide; Document HTTP 200 avec en-têtes après 5238 ms; application prête à 23,33 s; exit 0. | Collecte d'événements réseau observés, pas waterfall complet. Aucun dépassement distant expliqué avec certitude. |

Les warnings de paquets locaux compilés sous R 4.6.1 sont conservés; le runtime est R 4.6.0. Les messages de fermeture de transport après `cleanup_start` sont distincts des observations de démarrage.

## Défaut de collecte démontré et correction proposée

Sur le run Windows échoué, `test_dir()` levait son erreur avant de retourner les résultats. Le tableau par test prévu dans le workflow n'était donc jamais produit. La modification conserve `stop_on_failure=FALSE` seulement le temps de collecter les résultats, écrit un CSV, puis applique le même garde bloquant sur échecs, erreurs et skips. Un artefact distinct par plateforme et tentative conserve ce CSV.

La régression exécute le vrai payload R du YAML dans quatre projets temporaires : réussite, assertion échouée, erreur et skip. [Avant correction](ci-evidence-red.log) : quatre échecs attendus sur l'absence de CSV; les statuts de sortie étaient corrects. [Après correction](ci-evidence-green.log) : 2 tests, 41 assertions, aucun échec/erreur/skip. Les quatre rapports contiennent le contrôle réussi et le cas testé; les trois cas négatifs sortent toujours avec code 1.

Le diagnostic [scripts/ci_browser_diagnostic.R](../../scripts/ci_browser_diagnostic.R) est une exécution séparée, déclenchée uniquement après un échec Windows. Il garde les délais actuels et enregistre la première réponse HTTP observée, les logs AppDriver et Chrome, avec un cache Sass neuf. Il utilise un hook d'instrumentation de la version verrouillée de shinytest2; il ne modifie pas la suite initiale. Sa réussite éventuelle ne transforme pas le job déjà échoué en réussite et ne constitue pas une correction du timeout.

## Validation et autorisation

La [suite complète locale](local-full-ci-evidence.log), exécutée par [verify-ci-evidence-full.R](verify-ci-evidence-full.R) avec le véritable payload R du YAML modifié, est terminée avec exit 0 : **31 fichiers, 174 tests, 11 648 assertions réussies, zéro échec/erreur/skip**. Le [CSV complet](ci-evidence-full/lmplot-test-evidence/results.csv) est conservé. Un avertissement interne dans `test_model_brain_ui.R:84:3` indique que Shiny a été compilé sous R 4.6.1; le warning extérieur testthat de même nature est aussi conservé. Runtime R 4.6.0 et renv synchronisé vérifiés. Aucune équivalence avec un résultat GitHub Windows n'est revendiquée.

Le [contrôle du chemin d'échec](verify-diagnostic-failure.R), exécutant le véritable script de diagnostic dans une application temporaire dont la réponse HTTP est volontairement retardée de 12 secondes, est terminé avec exit 0 : [journal](ci-browser-diagnostic-failure.log). Le processus diagnostic conserve le délai CDP de 10 secondes, la requête Document, l'erreur `Page.navigate`, les logs Shiny et Chrome, puis sort avec **code 1**, conformément à l'attente. Le contrôle a observé 14 processus enfants R/Chrome et n'en détecte aucun encore actif à la fin. C'est une injection de panne pour vérifier la collecte et la terminaison, pas une reproduction de la cause réelle sur GitHub.

La revue indépendante des quatre fichiers ne relève aucun défaut bloquant démontré; elle confirme que le diagnostic ne neutralise pas l'échec original et rappelle que les événements réseau ne forment pas une capture exhaustive. Les quatre fichiers concernés sont `.github/workflows/ci.yml`, `tests/test_ci_scripts.R`, `tests/test_release.R` et `scripts/ci_browser_diagnostic.R`. Aucun code applicatif, délai de test ou dépendance modifié.

Après ces validations, les quatre fichiers ont été commités localement dans **`bf1018cfc423a72fa9c5a59c069ebce8ad5eacfb`**, message `fix(ci): preserve failure evidence and browser diagnostics`. Le distant a été relu à `42e70f36788bfaeac880251a29195de2713ceb4c`, sans divergence : `git merge-base --is-ancestor origin/master HEAD` exit 0 et `git rev-list --left-right --count origin/master...HEAD` donne `0 1`. `git diff --cached --check` était sans erreur et l'état final ne signale que le dossier de preuves non suivi. Tout push de cette proposition nécessite un nouvel accord explicite, demandé à l'utilisateur. Aucun nouveau push effectué à ce stade.

Les portes scientifique humaine, accessibilité manuelle avec lecteur d'écran et staging externe restent ouvertes faute d'approbations/accès. Cette collecte ne les remplace pas et ne permet pas un GO de publication.
