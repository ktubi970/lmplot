# Décision de publication — LM Plot Explorer 0.10.0-beta.1

> Décision historique. La [politique et la décision du 2 octobre](decision-0.10.0-beta.1-2026-10-02.md) remplacent l'exigence d'approbation scientifique exclusivement humaine; les preuves et observations ci-dessous restent conservées.

Date : 1 octobre 2026, Europe/Berlin. **NO-GO pour la publication.** Candidat courant : **`fdc7647bc73fc4e9574135895f119608ede4ae16`**, sur `master` local et distant. Le nouvel accord humain « oui » a autorisé le push des deux commits préparés `bf1018c` et `fdc7647`. La [CI du candidat](https://github.com/ktubi970/lmplot/actions/runs/36885551520) est terminée avec **les trois jobs réussis**, tentative 1, fin à 16:25:51 UTC. Le build et la santé Docker locale de ce SHA ont aussi réussi. Trois portes restent ouvertes : validation scientifique humaine, accessibilité manuelle complète et staging externe. Aucun tag Git ni publication créé.

Les résultats de `b5e9bdd` et de `42e70f3` ci-dessous sont historiques et ne valent pas validation de la CI du candidat courant.

Contexte historique observé vers 15:53 UTC : les jobs restaient dans `setup-renv` (Windows) et `setup-r` (Ubuntu), sans échec déclaré et sans suite commencée. GitHub refusait l'accès aux journaux de jobs actifs. Un [incident officiel « Actions Job Delays »](https://www.githubstatus.com/incidents/2dpbcq5j165n) était concomitant; il ne démontre pas la cause du délai de ces étapes ni celle de l'ancien timeout Windows. Les installations et suites se sont ensuite achevées avec succès. Le [suivi du candidat](ci-fdc7647-2026-10-01.md) conserve les métadonnées, journaux et CSV des deux OS.

## État des quatre portes

| Porte | Preuve actuelle | Condition restante |
| --- | --- | --- |
| CI GitHub Windows/Linux et Docker | [Run courant 36885551520](https://github.com/ktubi970/lmplot/actions/runs/36885551520), SHA `fdc7647`, tentative 1 : **Windows success**, 175 tests / 11 756 assertions; **Ubuntu success**, 175 tests / 11 745 assertions; **Docker success**, job 110461789291 terminé à 16:25:50 UTC. Les deux CSV ont zéro échec/erreur/skip/warning interne. R 4.6.0, renv cohérent et les 15 paquets requis Built 4.6.0; warnings externes conservés dans le [rapport hébergé](ci-fdc7647-2026-10-01.md). [Docker local du candidat](docker-fdc7647-2026-10-01.md) : build et santé exit 0, page/version vérifiées, réseau `none`, racine en lecture seule, utilisateur 997, limites CI. | **Porte vérifiée sur ce SHA.** L'écart de 11 assertions entre OS vient des tests du lanceur Windows; aucun skip. Les timeouts de `42e70f3` restent historiques, sans cause rétrospective affirmée. Ce succès ne valide pas l'ingress externe. |
| Formulations scientifiques | [Revue préparatoire](scientific-review-2026-09-23.md), sans défaut scientifique bloquant démontré dans les parcours examinés; réserves d'extrapolation et formulation Gamma documentées. Aucun texte scientifique modifié dans ce correctif. | Validation humaine nominative des formulations et arbitrage des réserves. |
| Accessibilité WCAG 2.2 AA | [Checklist](accessibility-review-2026-09-23.md). [Reprise DT](dt-accessibility-2026-10-01.md) : deux défauts de focus reproduits puis corrigés dans `fdc7647` — copies masquées et filtre actif hors champ à 517 px. Régression ciblée : 108 assertions vertes; contrôle interactif complémentaire avec contour visible. | Intervention humaine avec lecteur d'écran, zoom 200 % et autres états. Examiner les noms génériques `All` et le maintien d'un focus existant pendant resize. Les tests automatisés ne sont pas une certification de conformité. |
| Staging avec ingress externe | Aucune URL, accès ou preuve d'image déployée fournis. Les [recherches GitHub](staging-discovery-2026-09-23.md), répétées le 1 octobre à 13:33 UTC, renvoient encore zéro environnement et aucun déploiement; elles n'excluent pas un staging externe à GitHub. | Accès à l'URL HTTPS, identification SHA/digest et opérateur; smoke réel TLS/WebSocket, analyses exemple/simulation, alternatives et CSV, récupération après erreur, Expert absent, sans besoin d'egress applicatif. |

Le responsable de publication doit également consigner les approbations, le SHA et le digest effectivement testés en staging, puis la cible et la procédure de rollback (ou de retrait pour un premier déploiement). Aucun signataire ni environnement n'est supposé avoir validé ces éléments.

Docker hébergé : la [provenance du build](ci-fdc7647-docker-build-metadata.json) identifie le SHA courant, l'image/config `sha256:fe1516fe4047d176330f133e7dc86fa592439ed9f82e306c95ac516dfc28c51c` et le manifeste OCI `sha256:97f2f40544475cac4abe4b9ec505c810bba2a9cb335cc1b3ce427c24e9828802`. Le [journal](ci-fdc7647-docker-attempt1.log) confirme la configuration Compose, les contraintes du `docker run`, puis le titre et la version dans la réponse HTML à 16:25:41 UTC. La réussite de l'étape implique le passage de sa garde `healthy`; aucun dump des sondes `docker inspect` n'est imprimé sur le chemin vert. Les logs serveur collectés ne montrent pas d'erreur worker et le conteneur est supprimé. `push: false` : ce manifeste décrit le build testé, pas une image publiée ni un digest déjà déployé en staging.

Les warnings Docker restent dans les preuves, notamment la détection renv de `chromium` et `cmake` manquants pendant le build. La restauration annonce ensuite 113 paquets installés et la santé réussit; aucun navigateur dans l'image n'est prétendu testé. Les essais Chrome vérifiés appartiennent aux deux jobs R. Les warnings manpages et Node sont également conservés dans le rapport hébergé.

## Corrections bloquantes démontrées

1. La fixture du test de lanceur cherchait le R local sous Program Files, tandis que le runner GitHub l'installe sous C:\R. Seul le chemin Rscript de la copie temporaire du batch est adapté au runtime courant. Le lanceur public et les assertions no-bootstrap restent inchangés.
2. Le dispatcher Windows bin/Rscript.exe peut exécuter uniquement la première ligne d'un argument -e multiligne, sans propager les erreurs suivantes. Les deux étapes PowerShell exécutent maintenant des fichiers .R temporaires. Un test réel des deux commandes détecte le défaut avant correction (quatre assertions échouées) puis passe après correction.

Le correctif historique `42e70f3` touche uniquement `.github/workflows/ci.yml`, `tests/test_ci_scripts.R` et `tests/test_release.R`. Aucune fonctionnalité ajoutée, aucune modification d'architecture ou de code applicatif. Revue indépendante du diff sans finding actionnable.

## Validation préalable au push de 42e70f3 et reprise

- [Régression rouge](ci-multiline-red-2026-10-01.log) puis [validation ciblée verte](ci-fixes-green-2026-10-01.log) : 16 tests / 153 assertions, exit 0 après correction.
- [Suite complète de 42e70f3](local-full-ci-fixes-2026-10-01.log) et [résultats CSV](local-full-ci-fixes-2026-10-01.csv) : **31 fichiers, 173 tests, 11 623 assertions, zéro échec/erreur/skip**, exit 0. Un warning interne shiny et un warning séparé testthat compilés sous R 4.6.1 sont conservés; le runtime est exactement R 4.6.0. Le script [verify-ci-fixes-2026-10-01.R](verify-ci-fixes-2026-10-01.R) a été exécuté via bin/Rscript.exe et contrôle renv ainsi qu'un Chrome réel.
- [Détail Git, CI, causes et preuves](ci-hosted-2026-10-01.md). Le push autorisé a été exécuté avec `git -c push.followTags=false push --porcelain origin master:master`, exit 0, puis le distant a été vérifié à b5e9bdd. Le correctif a ensuite été poussé avec accord; voir le [nouveau suivi CI](ci-corrected-42e70f3-2026-10-01.md).

La seconde autorisation a été reçue et le push correctif effectué après ces vérifications (commandes conservées comme procédure, pas comme action restante) :

```powershell
git rev-parse master
git ls-remote origin refs/heads/master
git merge-base --is-ancestor origin/master master
git -c push.followTags=false push origin master:master
```

Avant le second push, `git ls-remote` annonçait b5e9bdd, l'ascendance était vérifiée (exit 0) et `git rev-list --left-right --count origin/master...master` indiquait `0 1`. Après le push, le distant était au SHA 42e70f3. Aucune divergence ni force-push.

Constat historique après la terminaison de la CI, avant la préparation de l'instrumentation ci-dessous : HEAD et `git ls-remote origin refs/heads/master` indiquaient tous deux `42e70f36788bfaeac880251a29195de2713ceb4c`; l'écart `origin/master...master` valait `0 0`. `git diff --check` terminait avec exit 0. `git status --short` ne signalait alors que le dossier de preuves non suivi `docs/release-evidence/`.

Le suivi `gh run watch 36867203181 --repo ktubi970/lmplot --interval 30 --exit-status` a terminé avec code 1 sur chacune des deux tentatives. Une seule reprise `gh run rerun 36867203181 --repo ktubi970/lmplot --failed` a été effectuée, sans changement de SHA ni nouveau push. Les journaux et métadonnées terminaux sont dans [le dossier CI du correctif](ci-corrected-42e70f3-2026-10-01.md).

Le préflight Windows réussit à la seconde tentative avec Chrome 154.0.8037.58. La suite échoue ensuite pendant la navigation initiale du smoke public. Le reporter affiche un seul incident et atteint le dernier fichier; les tests de régression CI et lanceur affichent leurs points de réussite. La cause du timeout CDP reste non isolée. Ce constat ne justifie ni une modification arbitraire des délais, ni la suppression du test, ni une correction applicative spéculative.

## Nouvelle collecte de preuves CI, préparée localement

La [préparation détaillée](ci-evidence-preparation-2026-10-01.md) corrige un défaut de collecte démontré : le tableau des résultats n'était pas produit après un échec de `test_dir()`. Le workflow écrit maintenant le CSV avant d'appliquer son garde bloquant inchangé; il publie les preuves en artefact et exécute un diagnostic séparé après un échec Windows. Les délais des tests restent inchangés. Les régressions réelles couvrent succès, assertion échouée, erreur et skip : quatre CSV manquants avant correction, puis **2 tests / 41 assertions** réussis et sorties négatives toujours à 1.

La suite complète du nouveau delta local termine avec **174 tests / 11 648 assertions, zéro échec/erreur/skip, exit 0**; l'avertissement Shiny compilé sous R 4.6.1 est conservé. Le diagnostic réel local réussit (Document reçu après 5 238 ms), et une injection de panne vérifie la collecte des logs et le statut 1 après timeout, sans processus R/Chrome observé encore actif à la fin. Ces observations ne démontrent ni la cause exacte ni la résolution du timeout GitHub.

La revue indépendante ne relève aucun défaut bloquant dans les quatre fichiers concernés : workflow, deux fichiers de tests et nouveau script `scripts/ci_browser_diagnostic.R`. Aucun changement applicatif, architectural, de dépendance ou de délai. À ce stade historique de préparation, un nouvel accord explicite était nécessaire avant push; il a depuis été reçu et utilisé comme consigné ci-dessous. Les preuves et scripts locaux du dossier `docs/release-evidence/` restent hors du commit.

État historique après préparation de la collecte CI : **`master` à `bf1018cfc423a72fa9c5a59c069ebce8ad5eacfb`**, commit `fix(ci): preserve failure evidence and browser diagnostics`. Le distant relu avec `git ls-remote --heads origin master` restait à **`42e70f3`**, sans divergence, écart `0 1`. Aucun run séparé de `bf1018c` n'a été lancé; ce commit est inclus dans le candidat `fdc7647` poussé après accord.

## Correctifs ciblés de focus — candidat local fdc7647

La poursuite des contrôles réalisables a reproduit deux défauts du tableau Data & provenance : des copies invisibles interceptaient Tab, puis le vrai filtre .residual pouvait rester entièrement hors de la zone visible à 517 pixels. Le [dossier ciblé](dt-accessibility-2026-10-01.md) consigne les preuves initiales, les rouges/verts, le contrôle interactif final, la revue indépendante et les limites. Le diagnostic initial d'absence de nom accessible a été corrigé après preuve CDP du nom générique `All`; cette réserve n'a pas donné lieu à un changement de libellé.

Le commit **`fdc7647bc73fc4e9574135895f119608ede4ae16`**, `fix(a11y): keep data table keyboard focus visible`, modifie uniquement `R/mod_data_provenance.R` (11 lignes de callback DT) et ajoute `tests/test_data_provenance_browser.R`. Aucune fonctionnalité, refonte, modification de calcul, dépendance ou délai. Les copies sont retirées du focus/exposition accessible et les filtres actifs défilent dans la zone visible à leur prise de focus, après l'ouverture DT du curseur numérique.

Validation finale locale : [suite complète](local-full-dt-a11y.log), [CSV](dt-a11y-full/lmplot-test-evidence/results.csv), **32 fichiers / 175 tests / 11 756 assertions réussies**, zéro échec/erreur/skip, exit 0. Avertissement interne Shiny compilé sous R 4.6.1 et warning extérieur testthat conservés; runtime R 4.6.0 et renv synchronisé. La régression ciblée finale compte 108 assertions réussies. Le contrôle interactif à 517 × 672 confirme le filtre .residual visible avec contour bleu 2 px et la sortie vers la pagination sans copie intermédiaire.

Git immédiatement avant le push autorisé : distant relu à `42e70f3`, ascendance vérifiée exit 0, écart **`0 2`**. Après le nouvel accord explicite « oui », `git -c push.followTags=false push --porcelain origin master:master` termine avec exit 0 et annonce `42e70f3..fdc7647`. Le contrôle distant renvoie le SHA complet `fdc7647bc73fc4e9574135895f119608ede4ae16`; `git rev-list --left-right --count origin/master...HEAD` indique désormais **`0 0`**. Aucun force-push, tag Git ni publication. `git status --short` ne signale que le dossier de preuves non suivi. [État Git et trace du push autorisé](git-fdc7647-push-evidence.json).

Le build Docker local du candidat termine avec exit 0, puis un conteneur neuf sous les contraintes CI atteint `healthy`. L'image porte le label du SHA complet; son identifiant est `sha256:1a17f011c8a3a30c3a0f1521b56d2ae7afda3ba3dbe3e4c2be649980f50c38dc`. La page contient le nom et la version attendus. Le conteneur de contrôle a été supprimé et les six conteneurs préexistants sont restés inchangés. Voir [preuves et limites Docker](docker-fdc7647-2026-10-01.md). Cette exécution sans ports et sans réseau ne teste aucun ingress externe.

## Conditions courtes de passage à GO

1. Obtenir l'approbation scientifique humaine, avec arbitrage des réserves d'extrapolation et de formulation Gamma.
2. Compléter les contrôles manuels d'accessibilité, dont lecteur d'écran et zoom 200 %, avec observations réellement consignées.
3. Fournir et tester le staging externe; consigner SHA/digest testé, approbations et cible/procédure de rollback.

## Contrôle terminal du coordinateur

Après la notification de réussite, le coordinateur a relu directement GitHub et Git, sans relance ni nouveau push :

```powershell
gh run view 36885551520 --repo ktubi970/lmplot --json headSha,status,conclusion,jobs,url,updatedAt
git rev-parse HEAD
git ls-remote --heads origin master
git rev-list --left-right --count origin/master...HEAD
git diff --check
git status --short --branch
```

Résultat : run `completed/success` et trois jobs `completed/success` au SHA `fdc7647bc73fc4e9574135895f119608ede4ae16`; HEAD et master distant égaux à ce SHA; écart **`0 0`**; contrôle du diff exit 0; aucun changement suivi, seulement `?? docs/release-evidence/`. Les CSV Windows et Ubuntu ont également été recalculés directement par le coordinateur : 175 tests chacun, respectivement 11 756 et 11 745 assertions, zéro échec/erreur/skip/warning interne.

L'URL de staging, les accès et les intervenants humains ont été demandés. Aucun élément permettant de fermer ces portes n'a été fourni pendant cette vérification. Les pièces de preuve restent locales dans `docs/release-evidence/`; elles ne font pas partie du commit correctif poussé.

