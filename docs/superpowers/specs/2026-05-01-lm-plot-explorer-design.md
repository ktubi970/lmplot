# Spécification Design : LM Plot Explorer

**Date :** 2026-05-01  
**Statut :** Validé  
**Auteur :** Antigravity  
**Projet :** Portfolio Biostatistique - Standalone Tool

## 1. Vision et Objectifs
L'application **LM Plot Explorer** est un outil interactif conçu pour explorer visuellement le comportement des modèles de régression (linéaires, généralisés, mixtes) via la simulation. Elle permet de comprendre l'impact des paramètres (pente, bruit, taille d'échantillon) sur l'ajustement du modèle et les diagnostics associés.

## 2. Architecture Technique
- **Framework :** R Shiny avec `{bslib}` pour un design moderne (Sidebar, Cards).
- **Style :** Thème "Flatly" ou "Cerulean" pour un rendu professionnel et clair.
- **Modularité :** L'application sera structurée de manière simple dans un premier temps (`app.R`), mais prête pour une modularisation si le nombre de modèles augmente.
- **Stack R :**
    - Interface : `shiny`, `bslib`, `shinyWidgets`, `shinyAce`.
    - Calcul & Modèles : `stats`, `lme4`.
    - Visualisation : `ggplot2`, `plotly`, `ggfortify` (pour les diagnostics).
    - Tableaux : `DT`.

## 3. Spécifications Fonctionnelles

### Barre Latérale (Sidebar)
- **Organisation :** Accordion groupé par types :
    - Régression Linéaire (lm)
    - Modèles Généralisés (glm)
    - Effets Mixtes (glmm)
- **Action :** Un bouton "Générer & Ajuster" pour forcer une nouvelle simulation (bien que la réactivité soit automatique sur les sliders).

### Zone de Simulation (Bottom Left Card)
- **Mode Standard :** Sliders pour :
    - Paramètres (β0, β1, ...)
    - Bruit (σ)
    - Taille d'échantillon (n)
    - Seed (pour la reproductibilité)
- **Mode Expert :** Éditeur `shinyAce` permettant de modifier directement le script de génération des données `y <- ...`.

### Visualisation Principale (Top Card)
- **Graphique :** `plotly` interactif.
- **Contenu :** Nuage de points (simulés) + Droite/Courbe de régression (ajustée).
- **Interactivité :** Tooltips affichant les coordonnées (x, y) et le résidu estimé pour chaque point.

### Diagnostics et Résultats (Bottom Right Tabset Card)
- **Onglet 1 (Diagnostics) :** Affichage des graphiques de diagnostics générés par `{ggfortify}` (ex: `autoplot(mod)`). Un sélecteur permet de choisir le type de plot.
- **Onglet 2 (Données) :** Tableau `DT` des données générées.
- **Onglet 3 (Résumé) :** Sortie textuelle propre du `summary(model)`.

## 4. Design de l'Interface (UX)
- **Layout :** Sidebar à gauche (25% largeur), zone de travail à droite (75%).
- **Responsive :** Utilisation des composants `card()` de bslib qui s'empilent proprement sur mobile.

## 5. Critères de Succès
- La transition entre les sliders et le mode expert doit être fluide.
- Les graphiques `plotly` et `ggfortify` doivent être lisibles et esthétiques.
- L'application doit permettre de démontrer des concepts statistiques (ex: hétéroscédasticité, points aberrants) via la simulation manuelle.
