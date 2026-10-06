# Analyse du préflight Chrome Windows du 1 octobre 2026

Run GitHub Actions `36867203181`, tentative 1, SHA `42e70f36788bfaeac880251a29195de2713ceb4c`. Cette analyse porte sur le journal Windows et sur les mécanismes de démarrage des versions verrouillées `chromote 0.5.1` et `shinytest2 0.5.1`. Elle ne modifie aucun code, test ou délai et ne revendique aucune réussite de la tentative 2.

**Constat : le préflight a échoué pendant le démarrage Chrome/CDP, avant le lancement de la suite Windows. La cause physique du timeout n'est pas isolée.** Une différence réelle avec les tests navigateur existe : shinytest2 prévoit déjà une tentative préalable supplémentaire sur Windows en CI, tandis que le préflight appelle directement `ChromoteSession$new()` une seule fois.

## Preuves de la tentative hébergée

Source : [journal Windows de la tentative 1](ci-windows-36867203181.log).

- Ligne 94 : checkout du SHA exact `42e70f36788bfaeac880251a29195de2713ceb4c`.
- Lignes 626–645 : les contrôles R sont exécutés depuis un fichier, après correction du problème de payload multiligne. L'assertion R 4.6.0 précède les vérifications renv et dépendances.
- Ligne 660 : renv indique un projet cohérent. Lignes 661–692 : les 15 paquets requis sont présents et leurs versions/builds sont imprimés ; les 15 champs `Built` indiquent R 4.6.0.
- Ligne 658 : `CHROMOTE_CHROME` vaut `C:\Program Files\Google\Chrome\Application\chrome.exe`. La vérification d'existence du fichier précède l'appel Chromote.
- Lignes 693–718 : erreur `Chrome debugging port not open after 10 seconds`, dans la chaîne `ChromoteSession$new()` → objet Chromote par défaut → `Chrome$new()` → `launch_chrome()` → fonction de démarrage.
- Lignes 719–720 : arrêt R et code de sortie 1. La suite de tests Windows n'est pas lancée ; aucun total de tests Windows ne peut être déduit de cette tentative. Docker reste bloqué par la dépendance aux deux jambes R.

Aucune réponse `Browser$getVersion()` n'est présente. Le chemin valide ne prouve donc ni un démarrage fonctionnel de Chrome ni sa version effective sur ce runner. Le journal ne conserve pas les fichiers stdout/stderr Chrome, son port choisi ni son état détaillé à l'expiration du délai.

## Comparaison du préflight et des tests navigateur

Le [préflight](../../.github/workflows/ci.yml) appelle `chromote::ChromoteSession$new()` sans modifier l'option `chromote.timeout`. Les tests [test_app.R](../../tests/test_app.R) et [test_link_browser.R](../../tests/test_link_browser.R) passent `load_timeout = 1e5` et `timeout = 1e5` à `shinytest2::AppDriver$new()`.

Ces deux paramètres AppDriver ne remplacent pas le délai initial de lancement Chrome. L'inspection des fonctions installées montre :

- `chromote:::launch_chrome_impl()` lit `getOption("chromote.timeout", 10)` pour ce lancement.
- Sa condition de connexion attend une seule ligne stderr commençant par `DevTools listening on ws://`, le port attendu, puis l'ouverture de `http://127.0.0.1:<port>/json/protocol`.
- Les erreurs et avertissements de cette vérification sont absorbés pendant l'attente. Le message final ne distingue donc pas une absence d'annonce stderr, une annonce non reconnue et une connexion HTTP/CDP indisponible.
- Un arrêt détecté du processus Chrome pendant cette boucle produit normalement une autre erreur, `Failed to start chrome`. Notre journal contient le timeout, pas cette erreur ; cela ne prouve pas l'état exact du processus au dernier instant.
- `shinytest2:::app_init_timeouts()` enregistre les délais AppDriver ; il ne modifie pas l'option de lancement ci-dessus.
- `shinytest2:::app_initialize()` exécute, pendant les tests, une tentative silencieuse supplémentaire lorsque `on_ci()` et `is_windows()` sont vrais, puis la tentative contrôlée. `on_ci()` lit la variable d'environnement `CI`.

L'introspection locale a seulement chargé et imprimé les fonctions de ces namespaces, sans instancier de navigateur et sans lancer de test. La version locale de shinytest2 est 0.5.1 ; son build Windows local est R 4.6.1, tandis que celui du runner est R 4.6.0. Le comportement de reprise a également été vérifié dans le code source amont versionné ci-dessous.

## Références primaires lues

Le [source shinytest2 v0.5.1, lignes 217–242](https://github.com/rstudio/shinytest2/blob/v0.5.1/R/app-driver-initialize.R#L217-L242) contient la branche Windows CI et le commentaire exact :

> Windows GHA needs a kick start for `{chromote}` to connect

Les lignes 225–236 appellent d'abord `try_chromote(silent = TRUE)` sur Windows CI, puis `try_chromote(silent = FALSE)`. Si cette dernière tentative échoue, shinytest2 appelle `testthat::skip()` ; LM Plot exige néanmoins zéro skip dans sa propre suite.

Le source renvoie à l'[issue shinytest2 nº 209](https://github.com/rstudio/shinytest2/issues/209), ouverte le 7 mai 2022. Elle rapporte le même message de timeout sur GitHub Actions malgré des tests locaux réussis. Le [commentaire du 9 mai 2022](https://github.com/rstudio/shinytest2/issues/209#issuecomment-1121465705) constate que des appels suivants peuvent réussir, mais déclare la cause inconnue et mentionne aussi des échecs ultérieurs intermittents. Cette observation historique n'établit pas la cause du présent run.

La [PR nº 225](https://github.com/rstudio/shinytest2/pull/225), fusionnée le 8 juin 2022 au commit `a8ce7de7a4e6702687706d6b196e22d3ba57a616`, lie les issues 201 et 209. Le `NEWS.md` de shinytest2 installé, ligne 227, documente également la tentative supplémentaire sur Windows CI. Le code versionné, le signalement, le commentaire cité et les métadonnées de fusion ont été lus directement depuis les sources publiques GitHub le 1 octobre 2026.

## Hypothèse et décision encore ouverte

**Hypothèse plausible :** le premier démarrage ou la première connexion CDP du runner Windows échoue temporairement dans la fenêtre de 10 secondes ; la tentative supplémentaire de shinytest2 peut expliquer pourquoi les parcours AppDriver ont fonctionné dans d'autres exécutions. Les sources amont rendent cette piste concrète, mais aucune mesure du présent runner ne prouve un simple démarrage lent ni une reprise qui aurait réussi dans ce même processus.

Un nouveau succès sur le même SHA démontrerait une différence entre exécutions, pas une réparation du code ni la cause précise du premier échec. Un nouvel échec identique renforcerait le besoin d'observer la sortie Chrome et la phase CDP, sans prouver à lui seul qu'un délai plus long suffit.

La tentative 2 des jobs échoués a été lancée séparément par l'agent principal, sur le même SHA. Son résultat et la reproduction locale doivent être examinés avant de choisir un changement. Si une modification du préflight devient nécessaire, les options minimales à évaluer sont une attente de lancement explicitement justifiée par les mesures ou une unique reprise Windows fondée sur le précédent amont, avec conservation de l'erreur initiale et échec final obligatoire si Chrome reste indisponible. Aucun skip, remplacement de navigateur, relâchement des assertions ou changement applicatif n'est proposé par cette analyse.

## Tentative 2 examinée après sa terminaison

Source : [journal Windows de la tentative 2](ci-windows-36867203181-attempt2.log), même run et même SHA, confirmé ligne 94. Cette section complète l'analyse historique ci-dessus : la tentative 2 est terminée en échec, malgré la réussite de son préflight.

Le préflight atteint cette fois `Browser$getVersion()` : Chrome **154.0.8037.58**, protocole CDP 1.3, lignes 693–706. Les contrôles R/renv/dépendances précèdent cette réponse ; les versions et les 15 champs `Built` sous R 4.6.0 sont conservés lignes 660–692. Cela atteste une connexion Chrome effective dans cette tentative, sans démontrer la cause du timeout de lancement précédent.

La suite de tests démarre ensuite. Le reporter affiche les **31 contextes/fichiers** de `acceptance` à `visualization`, lignes 733–765. Un seul incident y est repéré et détaillé :

- Lignes 768–769 : erreur dans `test_app.R:110:3`, lors de `AppDriver$new()` pour le workflow public, avant les assertions de ce scénario.
- Lignes 776–779 : création de session à 13:41:55.04, navigation à 13:41:55.29, puis timeout à 13:42:05.29, soit dix secondes d'attente de la réponse à `Page.navigate`.
- Ligne 783 : le journal Shiny indique une écoute sur `http://127.0.0.1:6268`. Ce message n'atteste pas à lui seul que la réponse HTTP ou le rendu de l'application était terminé.
- Ligne 795 : l'appel en défaut est `Page$navigate(private$shiny_url$get())`, dans l'initialisation AppDriver. L'inspection locale de `shinytest2:::app_initialize_()` confirme que cet appel ne transmet pas explicitement un argument `timeout_`.
- Lignes 811–815 : le reporter termine, `test_dir()` lève l'erreur finale et le processus sort avec le code 1.

Il s'agit donc d'un **timeout de réponse à une commande de navigation CDP**, après création de session. Ce n'est pas le timeout d'ouverture du port Chrome observé pendant le préflight de la tentative 1. Les délais AppDriver de 100 secondes n'ont pas empêché cette commande d'expirer au bout des dix secondes observées.

Le résumé continue après l'erreur du scénario public. Les contextes `ci_scripts`, `release` et `link_browser`, ainsi que les autres contextes, ne portent pas de marqueur d'échec supplémentaire. Des assertions réussies sont également affichées après l'incident dans `app`. Aucun skip ni warning de test n'est signalé par le reporter et aucune section correspondante n'est présente. Le seul avertissement explicite hors tests est la migration forcée de `actions/checkout@v4` de Node.js 20 vers Node.js 24, ligne 836.

**Limite des comptes :** `test_dir()` ne retourne pas ses résultats après cet échec. La table prévue par `as.data.frame(results)` et l'assertion finale sur les compteurs ne sont pas exécutées. Aucun total exact de tests/assertions ni tableau CSV complet n'est reconstitué à partir des points du résumé ; l'absence de signalement de skips/warnings reste décrite comme telle. Les sous-étapes de cache marquées `skipped` ne sont pas des tests ignorés.

La collecte de fin de job termine deux processus Chrome orphelins, lignes 834–835. Cela ne prouve ni un conflit entre ces processus ni la cause de la navigation bloquée. Aucun défaut applicatif précis n'est établi par la trace disponible ; une lenteur de première navigation, un état du navigateur ou une interaction avec le runner restent des hypothèses non isolées. La présence du serveur Shiny et la réussite des parcours ultérieurs ne suffisent pas à exclure toute cause applicative.

Docker, job `110399019167`, est sauté du fait de la dépendance à la matrice R en échec. La porte de CI hébergée reste ouverte. Aucune troisième relance ni modification de code n'a été effectuée pour cette analyse. Avant toute correction supplémentaire, il faut isoler la disponibilité HTTP et la réponse CDP de cette première navigation ; augmenter un délai ou attribuer l'échec à l'environnement ne constitue pas, en l'état, une cause démontrée.
