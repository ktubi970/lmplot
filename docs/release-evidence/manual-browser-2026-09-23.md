# Observations interactives navigateur — 0.10.0-beta.1

Révision : `b5e9bdd99a6d313007d3d65e4133c13e497b4b8b`, Windows, 23 septembre 2026.
Application démarrée par `C:/Program Files/R/R-4.6.0/bin/x64/Rscript.exe -e 'shiny::runApp(".", host="127.0.0.1", port=3839, launch.browser=FALSE)'`, avec `LMPLOT_TRUSTED_LOCAL` absent et la bibliothèque renv activée. URL locale : `http://127.0.0.1:3839/`.

Observateur : agent, via le navigateur intégré Codex (moteur/version exacts non relevés), interactions clavier, captures visuelles et inspection DOM/arbre d'accessibilité. Ce ne sont **ni un essai humain avec lecteur d'écran, ni une certification WCAG, ni un smoke de staging externe**. Les sorties de l'outil navigateur dans la conversation constituent la trace des observations. Aucune capture n'est prétendue enregistrée sur disque.

| Contrôle effectué | Résultat constaté | Portée / réserve |
| --- | --- | --- |
| Premier Tab puis Entrée sur le lien d'évitement | Focus sur « Skip to main content », puis sur `main-content`; Tab suivant atteint Overview. Lien focalisé : rectangle x=16, y=0, 162,625 × 40 px; contour bleu solide de 2 px dans le DOM. | Première capture du lien peu concluante visuellement; transfert de focus confirmé dans l'arbre. |
| Flèches des onglets | Overview → Diagnostics → Model Brain, puis retour par deux flèches gauche; état sélectionné et focus suivent l'onglet. | Trois onglets testés par flèches; Data & provenance activé ensuite par Entrée. |
| Génération simulation LM 2D | Activation du bouton par Entrée; état Processing puis « Analysis complete ». N=200, graine=123; graphique, métriques et résumés chargés. Expert absent de l'interface publique observée. | Le bouton a été ciblé directement par l'outil : cela ne prouve pas tout le parcours Tab de configuration. |
| Model Brain Previous/Next | Depuis l'onglet, deux Tab atteignent Next; Entrée passe de 186 à 187. Shift+Tab puis Espace sur Previous revient à 186. | Focus de Next conservé, visible sur la capture; rectangle 94,42 × 47 px, contour solide 2 px. Cela ne valide pas toutes les cibles. |
| Erreur d'index et correction | Saisie 0 : « Enter a whole number from 1 to 200 », `aria-invalid=true`, `aria-describedby=brain-index_error`, erreur `role=alert`. Retour à 186 : message effacé. | Le résultat valide précédent reste affiché. Aucune annonce sonore vérifiée. |
| Alternative à l'équation | Tab depuis l'index puis Entrée ouvre « View exact equation data ». Table nommée « Model Brain equation data », colonnes/valeurs disponibles dans l'arbre. | Lecture avec lecteur d'écran et confort d'une table très large non validés. |
| Redistribution à 320 × 800 pixels CSS | Texte de Model Brain, navigation et champ numérique se redistribuent. Largeur utile racine=305, scrollWidth=305; main clientWidth=scrollWidth=257; contrôles clientWidth=scrollWidth=223. | Contrôle partiel de cette vue. Previous/Next se coupent sur plusieurs lignes; à reprendre lors de la revue humaine. Pas de verdict global sur 1.4.10. |
| Zoom navigateur | Cinq raccourcis Ctrl+plus ont été essayés; largeur et rendu sont restés à 1280 px. | **Non vérifié** : aucun facteur 200 % confirmé. Ne pas remplacer cet essai par le viewport 320 px. Ctrl+0 envoyé ensuite et override viewport réinitialisé. |
| Tableau Data & provenance | Tableau de 200 lignes chargé; labels Search et Show entries présents. Recherche `no-such-observation` : « No matching records found » et statut « Showing 0 to 0 of 0 entries (filtered from 200 total entries) ». | Annonce du statut non écoutée. La sortie par Tab atteint l'en-tête X; tri/pagination complets restent à confirmer. |

Points encore ouverts : tous les modèles/états et contrôles conditionnels, filtres DT dont le nom accessible observé est « All » sans nom de colonne, interactions Plotly complètes, pagination/téléchargements au clavier, zoom 200 %, espacement du texte, contraste de tous les états, modes de contraste forcé, parcours humain avec lecteur d'écran. Le navigateur expose les structures accessibles mais ne remplace pas l'écoute des annonces.

Narrator est présent sur Windows, mais le contrôle des applications natives et de sa sortie audio n'est pas disponible dans les outils de cette session. Une intervention humaine a été demandée. Aucune exécution NVDA, JAWS ou Narrator n'est revendiquée.
