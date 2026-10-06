# Décision de publication — LM Plot Explorer 0.10.0-beta.1

> Mise à jour du 1 octobre 2026 : l'utilisateur a autorisé le push du candidat, réalisé avec succès. La [décision actualisée du 1 octobre](decision-0.10.0-beta.1-2026-10-01.md) et le [suivi CI](ci-hosted-2026-10-01.md) consignent les résultats hébergés, les deux corrections locales et les validations finales. Le présent document conserve le bilan du 23 septembre; ses mentions d'absence d'accord ou de run sont historiques. Les autres portes restent ouvertes.

Date : 23 septembre 2026. Candidat examiné : `b5e9bdd99a6d313007d3d65e4133c13e497b4b8b`, branche locale `master`.

**NO-GO en l'état.** Les preuves hébergées du candidat, les validations humaines et le staging externe requis ne sont pas tous disponibles. Une réussite locale ne ferme pas ces portes.

Cette décision prépare la publication; elle ne crée ni tag ni release. Aucun push n'est autorisé tant que l'accord explicitement demandé à l'utilisateur n'est pas reçu. Les preuves ajoutées dans ce dossier sont locales et non commitées. Aucun fichier applicatif, test, architecture ou fonctionnalité n'a été modifié.

## Portes de livraison

| Porte | Résultat / preuve disponible | Condition de fermeture |
| --- | --- | --- |
| CI GitHub Windows/Linux et santé Docker | Distant sans divergence lors de la lecture : `a6d2b72`, ancêtre du candidat; `rev-list` = `0 35`. GitHub Actions renvoie zéro run et zéro workflow hébergé. **Suite Windows locale intégrale réussie** : 172 tests, 11 607 assertions, zéro échec/erreur/skip, exit 0. **Docker local réussi** : build Linux/AMD64 exit 0, conteneur `healthy` sous `network=none` et racine en lecture seule; contenu LM Plot Explorer et version vérifiés. Les erreurs initiales et reprises restent archivées séparément. | Accord explicite avant push non forcé, puis trois jobs verts sur le SHA candidat : Windows, Ubuntu et Docker. Conserver logs, versions/builds des paquets, avertissements et santé de l'image. |
| Formulations scientifiques | Revue préparatoire effectuée, sans erreur P0/P1 scientifique démontrée. Reprise UTF-8 des trois fichiers de formulations/métadonnées : 11 tests, 340 assertions, zéro échec/erreur/skip. Réserves : extension graphique de 15 % hors plages observées (P2), libellé « OLS-estimated Gamma GLM » alors que `glm.fit` utilise IWLS (P3). | Relecture et signature humaines des textes publics, exigées dans CHANGELOG; arbitrage explicite des réserves. Les tests ne constituent pas cette signature. |
| Accessibilité WCAG 2.2 AA | Checklist A/AA et observations interactives consignées : lien d'évitement, onglets, Previous/Next, erreur/correction d'index, table alternative, reflow partiel à 320 px, recherche DT. | Intervention humaine avec lecteur d'écran, parcours complet des contrôles/états, zoom 200 %, espacement, contrastes/cibles et autres lignes manuelles encore ouvertes. Aucune certification de conformité n'est revendiquée. |
| Staging avec ingress externe | Aucune URL HTTPS, configuration d'ingress, preuve WebSocket ou digest effectivement déployé n'a été fourni. Le dépôt délègue l'ingress à l'exploitant. | Fournir environnement et accès; vérifier via l'URL externe TLS, WebSocket, analyses exemple/simulation, alternatives et CSV, récupération après erreur, Expert absent et fonctionnement sans egress applicatif; identifier digest testé et cible de rollback. |

## Enregistrement final par le responsable de publication

Cette exigence transversale du changelog reste **ouverte**, indépendamment des quatre portes ci-dessus. Le responsable doit consigner avant publication :

- Le SHA effectivement testé par la CI et déployé en staging.
- Le digest immuable de l'image effectivement testée en staging, et son lien avec ce SHA. Le digest de l'image locale ne désigne aucun déploiement externe.
- L'identité, la date, la portée et la preuve des approbations scientifique et accessibilité, puis la décision de publication.
- La cible de rollback : digest précédent approuvé et configuration correspondante. Si aucun déploiement précédent n'existe, l'exploitant doit définir et valider la procédure de retrait; aucun digest fictif ne doit être inscrit.

Aucun responsable ni signataire n'est supposé avoir approuvé ces éléments. Les champs absents empêchent le go.

## Pièces de preuve

- [Git, absence de divergence et absence de runs CI](git-ci-2026-09-23.md).
- [Docker local et staging externe](docker-staging-2026-09-23.md).
- [Recherche de staging dans les métadonnées GitHub](staging-discovery-2026-09-23.md) : le 23 septembre à 18:32 UTC, zéro environnement et aucun déploiement visible. Un staging administré hors GitHub reste possible; son URL et ses accès doivent être fournis.
- [Build Docker initial](docker-build-fresh-2026-09-23.log), [état de santé brut](docker-health-2026-09-23.json) et [journal du conteneur](docker-health-2026-09-23.log). Cinq contrôles de santé enregistrés, chacun exit 0, `FailingStreak=0`; récupération racine exit 0, 23 836 octets, UID 997.
- [Revue scientifique](scientific-review-2026-09-23.md).
- [Checklist d'accessibilité](accessibility-review-2026-09-23.md).
- [Observations interactives dans le navigateur](manual-browser-2026-09-23.md).
- [Premier journal de suite Windows locale](local-windows-tests.log), avec l'environnement initial et les versions des paquets.
- [Reprise scientifique UTF-8](scientific-utf8-tests.log) et [résumé des 11 tests](scientific-utf8-tests.csv) : exit 0, 340 assertions réussies, un avertissement `shiny` compilé sous R 4.6.1 conservé.
- [Diagnostic du démarrage navigateur](browser-startup-diagnostic.log) : timeout `Page.navigate` reproduit avec une locale valide; Chrome/CDP fonctionnels sur page minimale, HTTP 200 et navigation réussie sur Shiny déjà disponible. La piste du premier chargement reste une hypothèse, pas une cause prouvée.
- [Reprise navigateur](browser-retest.log) et [résultats CSV](browser-retest.csv) : exit 0, 5 tests / 59 assertions réussies, zéro échec/erreur/skip et zéro warning dans les tests. Le warning de compilation de `testthat` sous R 4.6.1 est imprimé séparément et conservé.
- **Preuve intégrale locale la plus récente :** [journal Windows isolé UTF-8](local-windows-full-clean.log) et [résultats CSV par test](local-windows-full-clean.csv). Exécution terminée le 23 septembre 2026 vers 20:42 Europe/Berlin : 30 fichiers, 172 tests, 11 607 assertions, zéro échec/erreur/skip, exit 0. Un warning dans les tests (`shiny` compilé sous R 4.6.1) et un warning séparé en sortie (`testthat` compilé sous R 4.6.1) sont conservés. Runtime exact R 4.6.0, renv synchronisé, Chrome réel et Expert désactivé.

## Exécution intégrale locale isolée

Cette exécution couvre toute la suite, dont les contrats scientifiques et CLI, les modules, l'accessibilité automatisée et les scénarios Chrome réels. Aucun code, test ni délai n'a été modifié. Elle a été lancée après la fin des compilations et sondes concurrentes; les trois variables de locale injectées ont été retirées du seul processus enfant. Le budget Model Brain mesuré est de 0,430 s et 33 598 128 octets.

Commande d'exécution, via `C:/Program Files/R/R-4.6.0/bin/x64/Rscript.exe`, après vérification de R 4.6.0, de `renv::status()$synchronized` et des dépendances :

```r
results <- testthat::test_dir("tests", reporter="summary", stop_on_failure=FALSE)
evidence <- as.data.frame(results)
write.csv(evidence[c("file", "test", "failed", "error", "warning", "skipped", "passed")],
          "docs/release-evidence/local-windows-full-clean.csv", row.names=FALSE)
stopifnot(!any(evidence$failed > 0L | evidence$error | evidence$skipped))
```

Environnement : `CHROMOTE_CHROME=C:/Program Files/Google/Chrome/Application/chrome.exe`, `NOT_CRAN=true`; `LMPLOT_TRUSTED_LOCAL`, `LC_ALL`, `LC_CTYPE` et `LANG` retirées dans le processus PowerShell enfant. R confirme UTF-8 actif et codepage 65001. `stop_on_failure=FALSE` permet de conserver le détail CSV; l'assertion finale refuse toujours tout échec, erreur ou skip. Cette preuve clôt la reprise **locale** complète, pas la matrice hébergée ni les contrôles humains.

## Limites d'environnement constatées

La suite Windows complète a terminé avec **exit 1 et quatre erreurs**, toutes pendant `AppDriver$new` avant les assertions des scénarios :

- `tests/test_app.R:110` : workflow public.
- `tests/test_app.R:168` : conservation du résultat après erreur et récupération.
- `tests/test_app.R:194` : clavier, clic Plotly et sélection Model Brain.
- `tests/test_link_browser.R:5` : changement de famille conservant le lien sélectionné.

Message commun : `Chromote: timed out waiting for response to command Page.navigate`. Le rapport final initial ne présente pas d'autres échecs. Le warning interne à la suite concerne `shiny` compilé sous R 4.6.1; un warning `testthat` compilé sous R 4.6.1 apparaît également à la sortie. Cette **première exécution n'était pas verte** et ne validait pas ses scénarios navigateur. Son CSV prévu après `test_dir()` n'a pas été écrit, car `test_dir()` a levé l'erreur finale; son journal complet est conservé, distinct de la nouvelle suite intégrale verte ci-dessus.

**Reprise terminée, exit 0 :** après la fin de la compilation Docker, de la suite complète et des sondes, les deux fichiers ont été rejoués avec une locale UTF-8 valide, sans modification de code, de tests ou de timeout. Les quatre scénarios navigateur et le test de classification des logs passent : 5 tests, 59 assertions, zéro échec/erreur/skip. Les timeouts initiaux ne se reproduisent donc pas dans cette reprise; la charge et le premier chargement restent une explication plausible, pas une cause isolée expérimentalement. Cette combinaison de preuves ne doit pas être présentée comme une exécution intégrale unique verte ni comme de la CI hébergée.

Commande de reprise (Rscript standard, même Chrome et NOT_CRAN; LC_ALL/LC_CTYPE/LANG retirées du processus enfant) : `testthat::test_dir("tests", filter="^(app|link_browser)$", reporter="summary", stop_on_failure=FALSE)`, suivie de l'export CSV et d'une assertion sur l'absence d'échecs, d'erreurs et de skips.

Commande principale, après `CHROMOTE_CHROME=C:/Program Files/Google/Chrome/Application/chrome.exe`, `NOT_CRAN=true` et suppression de `LMPLOT_TRUSTED_LOCAL` : `C:/Program Files/R/R-4.6.0/bin/x64/Rscript.exe -e 'testthat::test_dir("tests", reporter="summary")'`. Le lancement réel vérifiait également R 4.6.0, `renv::status()$synchronized` et les paquets requis, et imprimait leurs versions/builds avant la suite.

Les premiers refus de connexion GitHub, d'accès au moteur Docker et au cache renv provenaient du sandbox. Les lectures/vérifications autorisées hors sandbox ont permis de continuer. Le renv standard a été vérifié synchronisé sous R 4.6.0; cela ne prouve pas une restauration neuve sur les runners hébergés.

Le processus initial héritait de `LC_ALL`, `LC_CTYPE` et `LANG` à `C.UTF-8`, valeur rejetée par R dans cet environnement Windows. La première suite scientifique ciblée avec `--vanilla` a montré des différences d'encodage. Un processus enfant sans ces trois variables a retrouvé `English_United Kingdom.utf8`, UTF-8 actif, codepage 65001 et les unités exactes. Les trois fichiers concernés ont ensuite passé leurs 340 assertions. Les échecs initiaux restent dans les preuves, séparés de leur reprise; aucune modification du code n'a été nécessaire pour celle-ci.

Le dépassement isolé du budget Model Brain à 2,160 s a été mesuré pendant plusieurs travaux concurrents. La suite principale a mesuré 1,400 s pour le même budget et 33 598 128 octets; le premier dépassement n'établit donc pas à lui seul une régression de performance.

## Reprise après accord et accès

Avant le push proposé, relire les deux extrémités et leur relation. Ne pas forcer si le distant évolue :

```powershell
git rev-parse master
git ls-remote origin refs/heads/master
git merge-base --is-ancestor a6d2b7260589dfcee808e284ee1013e6876ebaaf b5e9bdd99a6d313007d3d65e4133c13e497b4b8b
# Seulement après accord explicite et nouvelle vérification du distant :
git push origin master:master
```

Le besoin d'accord vient de la demande utilisateur, pas d'une procédure ajoutée par cette revue. Les demandes d'URL/access staging et de test humain avec lecteur d'écran sont également explicites dans la demande et restent nécessaires. Aucun résultat de ces contrôles absents n'est supposé.

