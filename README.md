# SAGA Arbitre — Simulations de coûts et diagnostic H4E

Application R/Shiny. Les résultats dépendent de données et conventions explicites ; ils ne certifient ni rentabilité réelle, ni qualité opérationnelle, ni conformité d’un service.

## Parcours

- **Manuel vs Agentique** : coût par résultat accepté et coûts cumulés à couverture finale équivalente. Le volume est entrant ; le taux doit être l’acceptation finale. Les coûts d’inférence par entrée comprennent déjà les reprises. La courbe manuelle compare le nombre de résultats finalement acceptés ; elle ne prouve pas la couverture des autres entrées. Investissements initiaux séparés, référence manuelle sans nouveau coût de construction par défaut.
- **C1** : simulation au catalogue local et conversion USD/EUR explicite.
- **C2** : frais non humains fixes et variables. Fixe/variable ne signifie pas CAPEX/OPEX. Les prix sont des hypothèses locales à vérifier.
- **C3** : revue systématique, reprises additionnelles et gouvernance/entretien. Le forfait de calibrage représente tout l’effort de cette phase ; trois mois est l’hypothèse du microscope historique.
- **CTP** : total sur l’horizon. Les transferts C1/C2/C3 restent manuels et doivent conserver volume, devise et période. Si C2 est déjà détaillé, la case correspondante impose κ=1 et évite une seconde multiplication.
- **Prix API** : édition du catalogue local et propagation des tarifs enregistrés vers C1.

## Deux applications indépendantes

Cette version publique conserve six pages. La copie complète locale, avec les pages « Cas M1 — Deux visions » et « Télémétrie du Terrain », les journaux et l’historique Git, se trouve dans `../app_saga_terrain/`. Voir [la procédure de séparation et de déploiement](SEPARATION.md).

## Exécution et tests

Restaurer l’environnement déclaré par `renv.lock`, puis lancer `shiny::runApp()`. `app.R` charge explicitement les fonctions de `logic_maths.R` et `logic_parsers.R`, puis l’interface et le serveur.

```r
testthat::test_dir("tests/testthat")
```

Les tests couvrent les calculs des pages publiques, les six pages de navigation, l’absence des pages retirées, les tarifs, les dates et la propagation des modifications du catalogue vers C1. Les tests d’intégration exigent les dépendances réelles et ne sont pas ignorés silencieusement.

Pour l’audit du 27 septembre 2026, les dépendances absentes ont été installées dans `/tmp/saga-r-lib` sans modifier la bibliothèque personnelle ni `renv.lock`. Commande de reproduction dans cet environnement temporaire : `R_LIBS=/tmp/saga-r-lib Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'`. Une autre machine doit restaurer les dépendances du projet.

Voir le dossier [audit documentaire M1](../../KNOWLEDGE/SAGA-IA/M1/AUDIT_H4E/RAPPORT.md). Les données des préréglages sont également décrites dans les deux cadrages du corpus.
