# Décision après changement de politique — 2 octobre 2026

**NO-GO global maintenu. La porte scientifique est approuvée par agent avec réserves non bloquantes; l'accessibilité manuelle complète et le staging externe restent ouverts.**

L'utilisateur a demandé « change la politique d’approbation » après l'explication de l'exigence de signature scientifique humaine. La politique locale de [CHANGELOG.md](../../CHANGELOG.md#release-gates-and-evidence), reprise dans le [README](../../README.md#accessibility-and-verification) et [TODO.md](../../TODO.md), accepte désormais un humain ou un agent explicitement identifié. Elle exige une revue documentée et une décision motivée sur les constats; les tests automatisés seuls ne constituent pas cette revue. Les exigences d'accessibilité réellement observée et de staging externe restent obligatoires.

## Approbation scientifique documentée

- **Auteur de cette décision :** Codex, agent coordinateur de cette conversation (`/root`), le 2 octobre 2026, Europe/Berlin. Il reprend les conclusions et assume l'arbitrage ci-dessous; aucune identité humaine ni identité précise du reviewer historique n'est inventée.
- **Candidat examiné :** `fdc7647bc73fc4e9574135895f119608ede4ae16`, version `0.10.0-beta.1`. La revue source portait sur `b5e9bdd`, avec continuité des calculs et formulations vérifiée le 1 octobre jusqu'à `fdc7647`. Le delta local du 2 octobre modifie uniquement la politique documentaire dans CHANGELOG, README et TODO.
- **Périmètre :** formulations publiques Shiny, documentation scientifique, interprétations LM/GLM/modèle mixte gaussien, diagnostics, intervalles, causalité et Model Brain, selon la portée détaillée du [rapport scientifique](scientific-review-2026-09-23.md).
- **Preuves utilisées :** ce rapport contient les références primaires R/lme4, les reproductions numériques et la revue des textes; il conserve l'échec initial de locale puis la reprise UTF-8 réussie de 11 tests / 340 assertions. La [CI du 1 octobre](ci-fdc7647-2026-10-01.md) a ensuite validé les suites complètes sur les deux OS au SHA `fdc7647`. Ces résultats sont des preuves antérieures réutilisées, pas des exécutions du 2 octobre ni une approbation scientifique à eux seuls.
- **Verdict : APPROUVER la porte scientifique pour cette bêta pédagogique, avec les réserves ci-dessous explicitement acceptées comme non bloquantes.** Aucun défaut P0/P1 n'a été démontré dans le périmètre examiné. Cette décision ne prétend pas que les formulations sont exemptes d'erreurs ou que tous les modèles sont scientifiquement adéquats pour toute utilisation.

| Constat | Arbitrage de l'agent | Motif et limite conservée |
| --- | --- | --- |
| SCI-01, P2 : la surface s'étend hors des plages observées sans distinguer l'extrapolation. | Accepté comme limitation connue pour cette bêta; amélioration de la qualification visuelle à reprendre ultérieurement. | La revue démontre une omission de présentation et des coordonnées physiquement impossibles pour certains exemples, pas une erreur arithmétique du modèle. La documentation des exemples déconseille l'extrapolation. L'acceptation est limitée au produit exploratoire pédagogique et ne valide ni ces coordonnées ni la fiabilité des prédictions extrapolées. |
| SCI-02, P3 : deux notes appellent à tort « OLS » l'ajustement Gamma effectué par `stats::glm` / IWLS. | Erreur terminologique reconnue et correction reportée; non bloquante pour cette bêta. | La reproduction concorde avec l'ajustement `glm.fit` et les coefficients documentés. Ce classement ne rend pas la formulation « OLS » correcte; aucun texte scientifique n'est modifié dans cette demande de politique. |
| Réserve supplémentaire : portée du libellé « Literature-backed default link », notamment pour Gamma. | Réserve maintenue, non bloquante sur les preuves disponibles; qualification à reprendre lors d'une revue des sources de chaque exemple. | Le rapport distingue la proposition pédagogique Gamma de la méthode du papier source. Il ne démontre pas que tous les liens par défaut manquent d'appui bibliographique et n'a pas réaudité chaque article. Aucune validation exhaustive de cette filiation n'est revendiquée. |

Cette approbation n'est ni une signature humaine ni une revue indépendante de chaque article, de chaque prétraitement ou de la couverture statistique des intervalles. Les réserves demeurent visibles et traçables. Un changement des calculs, des formulations ou du périmètre examiné devra être évalué dans la preuve de revue du nouveau candidat.

## État des portes après la décision

| Porte | État et preuve |
| --- | --- |
| CI Windows/Linux et santé Docker | Réussie sur `fdc7647` le 1 octobre : [run 36885551520](https://github.com/ktubi970/lmplot/actions/runs/36885551520), 175 tests par OS, 11 756 / 11 745 assertions, zéro échec/erreur/skip. Le changement documentaire local du 2 octobre n'est ni commité, ni poussé, ni présenté comme un nouveau run CI. |
| Formulations scientifiques | Approuvée par Codex selon la nouvelle politique, avec l'arbitrage explicite ci-dessus. L'exclusivité humaine cesse d'être une condition. |
| Accessibilité WCAG 2.2 AA | Toujours ouverte : lecteur d'écran, zoom 200 % et autres contrôles de la [checklist](accessibility-review-2026-09-23.md) à réaliser et consigner. Aucun test automatisé n'est une certification WCAG. |
| Staging externe | Toujours ouvert : l'utilisateur indique ne pas avoir d'URL. Il faut mettre à disposition une préproduction accessible puis tester TLS/WebSocket, analyses, alternatives/CSV et récupération après erreur. Le SHA/digest réellement déployé et le rollback doivent être consignés. |

Le [dossier du 1 octobre](decision-0.10.0-beta.1-2026-10-01.md) et les autres rapports datés conservent les exigences et résultats en vigueur lors de leur rédaction. Le présent addendum remplace leur exigence de signature scientifique humaine obligatoire, sans réécrire leurs observations. Aucun push, tag Git, déploiement ou publication n'est effectué par ce changement de politique.

En particulier, la mention « signature humaine toujours requise » dans la table finale du [rapport CI du 1 octobre](ci-fdc7647-2026-10-01.md) décrit l'ancienne politique. Ce rapport et son manifeste de sommes de contrôle restent inchangés; la règle courante est celle de cet addendum et de CHANGELOG. Les cases du CHANGELOG et du TODO restent la checklist à consolider pour le candidat final, tandis que la table datée ci-dessus consigne les résultats acquis et les portes encore ouvertes.
