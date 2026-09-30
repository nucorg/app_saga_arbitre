# SAGA Arbitre — Simulations de coûts et diagnostic H4E

Application R/Shiny. Les résultats dépendent de données et conventions explicites ; ils ne certifient ni rentabilité réelle, ni qualité opérationnelle, ni conformité d’un service.

## Parcours

- **Manuel vs Agentique** : coût par résultat accepté et coûts cumulés à couverture finale équivalente. Le volume est entrant ; le taux doit être l’acceptation finale. Les coûts d’inférence par entrée comprennent déjà les reprises. La courbe manuelle compare le nombre de résultats finalement acceptés ; elle ne prouve pas la couverture des autres entrées. Investissements initiaux séparés, référence manuelle sans nouveau coût de construction par défaut.
- **C1** : simulation au catalogue de référence ou aux tarifs personnels appliqués à la session et conversion USD/EUR explicite.
- **C2** : frais non humains fixes et variables. Fixe/variable ne signifie pas CAPEX/OPEX. Les prix sont des hypothèses locales à vérifier.
- **C3** : revue systématique, reprises additionnelles et gouvernance/entretien. Le forfait de calibrage représente tout l’effort de cette phase ; trois mois est l’hypothèse du microscope historique.
- **CTP** : total sur l’horizon. Les transferts C1/C2/C3 restent manuels et doivent conserver volume, devise et période. Si C2 est déjà détaillé, la case correspondante impose κ=1 et évite une seconde multiplication.
- **Prix API** : tarifs personnels par session, import/export CSV et application explicite aux calculs C1.

## Tarifs personnels et catalogue de référence

Le fichier `data/pricing_models.csv` est une référence en lecture seule pour les visiteurs. À l’ouverture d’une session, chaque utilisateur en reçoit sa propre copie. Aucun bouton de l’application n’écrit dans ce fichier.

- **Modifier, ajouter ou supprimer** prépare la table affichée. Les calculs utilisent les derniers tarifs appliqués ; un message indique les modifications en attente.
- **Appliquer à ma simulation** utilise cette table dans C1, pour cette session uniquement. Les modèles déjà sélectionnés restent sélectionnés s’ils existent encore.
- **Exporter mes tarifs** télécharge la table affichée, y compris ses modifications non appliquées. Le fichier CSV UTF-8 conserve les accents, les guillemets et les valeurs facultatives absentes.
- **Importer mes tarifs** remplace la table affichée après validation. Il faut ensuite appliquer les tarifs pour modifier les calculs. Un fichier refusé laisse la table et les calculs précédents intacts.
- **Rétablir les tarifs de référence** remplace immédiatement la table et les tarifs actifs de la session par sa référence initiale.

Les tarifs personnels ne sont pas conservés au-delà de la session. Exporter avant de quitter, puis importer à la prochaine visite. Un utilisateur ne voit jamais les tarifs personnels d’un autre ; une nouvelle session retrouve la référence.

L’import accepte un CSV UTF-8 (avec ou sans BOM), séparé par des virgules ou des points-virgules. Colonnes requises : `Identifiant`, `p_in_1M`, `p_out_1M`. Colonnes facultatives : `Fournisseur`, `p_cache_1M`, `date_verification`. Les colonnes inconnues ou dupliquées sont refusées. Les prix sont en USD par million de jetons, finis et positifs ou nuls ; les décimales peuvent utiliser un point ou une virgule. Le cache peut rester vide. Les identifiants sont non vides et uniques sans distinction de casse. Les dates utilisent `AAAA-MM-JJ` ou restent vides, sans date de vérification inventée. Le catalogue doit contenir au moins un modèle.

Pour modifier la référence proposée aux prochaines sessions, le mainteneur met à jour le CSV du dépôt et redéploie l’application. Les sessions déjà ouvertes gardent leur copie initiale.

## Deux applications indépendantes

Cette version publique conserve six pages. La copie complète locale, avec les pages « Cas M1 — Deux visions » et « Télémétrie du Terrain », les journaux et l’historique Git, se trouve dans `../app_saga_terrain/`. Voir [la procédure de séparation et de déploiement](SEPARATION.md).

## Exécution et tests

Restaurer l’environnement déclaré par `renv.lock`, puis lancer `shiny::runApp()`. `app.R` charge explicitement les fonctions de `logic_maths.R` et `logic_parsers.R`, puis l’interface et le serveur.

```r
testthat::test_dir("tests/testthat")
```

Les tests couvrent les calculs des pages publiques, les six pages de navigation, l’absence des pages retirées, les tarifs, les dates et l’application des tarifs à C1, l’isolation de sessions simultanées, l’intégrité du CSV de référence et le cycle import/export/réinitialisation. Les tests d’intégration exigent les dépendances réelles et ne sont pas ignorés silencieusement.

Pour l’audit du 27 septembre 2026, les dépendances absentes ont été installées dans `/tmp/saga-r-lib` sans modifier la bibliothèque personnelle ni `renv.lock`. Commande de reproduction dans cet environnement temporaire : `R_LIBS=/tmp/saga-r-lib Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'`. Une autre machine doit restaurer les dépendances du projet.

Voir le dossier [audit documentaire M1](../../KNOWLEDGE/SAGA-IA/M1/AUDIT_H4E/RAPPORT.md). Les données des préréglages sont également décrites dans les deux cadrages du corpus.
