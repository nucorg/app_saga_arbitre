# SAGA Arbitre — Simulations de coûts et diagnostic H4E

Application R/Shiny. Les résultats dépendent de données et conventions explicites ; ils ne certifient ni rentabilité réelle, ni qualité opérationnelle, ni conformité d’un service.

## Parcours

- **Manuel vs Agentique** : coût par résultat accepté et coûts cumulés à couverture finale équivalente. Le volume est entrant ; le taux doit être l’acceptation finale. Les coûts d’inférence par entrée comprennent déjà les reprises. La courbe manuelle compare le nombre de résultats finalement acceptés ; elle ne prouve pas la couverture des autres entrées. Investissements initiaux séparés, référence manuelle sans nouveau coût de construction par défaut.
- **C1** : simulation au catalogue local et conversion USD/EUR explicite.
- **C2** : frais non humains fixes et variables. Fixe/variable ne signifie pas CAPEX/OPEX. Les prix sont des hypothèses locales à vérifier.
- **C3** : revue systématique, reprises additionnelles et gouvernance/entretien. Le forfait de calibrage représente tout l’effort de cette phase ; trois mois est l’hypothèse du microscope historique.
- **CTP** : total sur l’horizon. Les transferts C1/C2/C3 restent manuels et doivent conserver volume, devise et période. Si C2 est déjà détaillé, la case correspondante impose κ=1 et évite une seconde multiplication.
- **Cas M1 — Deux visions** : calcul commun Firme Minimale et Grands Groupes/ETI ; investissement initial, durée de calibrage et taux de réaffectation explicites. Distingue coût analytique réparti et coût sur horizon avec investissement payé une seule fois. Le solde est une valeur de capacité, pas de trésorerie.
- **Télémétrie** : lecture des journaux, prix par identifiant exact et coût estimé par accepté final. Une donnée manquante ou un tarif inconnu bloque le calcul ; zéro accepté donne un coût non fini.

## Deux cas de référence (simulations)

| Cas | Humain résiduel/mois | CTP analytique/mois | Solde conventionnel/mois |
|---|---:|---:|---:|
| Entreprise : 1 200 entrants et acceptés | 200 h | 16 500 EUR | 7 500 EUR |
| Qognito : 150 entrants et acceptés | 20,25 h | 529,25 EUR | 466,375 EUR |

Qognito : les 3,75 h historiques sont les seules reprises. Le scénario ajoute 12,5 h de revue et 4 h de gouvernance, suppose 0,05 EUR d’inférence par entrée, 218 EUR/mois incrémentaux et un investissement initial nul **à remplacer par sa mesure**. Ni 15 EUR/h ni C2=0 ne sont imposés aux firmes minimales. Les deux taux de valorisation (coût consommé et valeur réaffectée) sont distincts.

Entreprise : investissement 36 000 EUR réparti sur 24 mois ; coût récurrent non humain 3 000 EUR/mois ; trois mois à 300 h puis neuf à 200 h. Le solde conventionnel de première année est 63 000 EUR. L’amortissement n’est pas ajouté à l’investissement payé.

## Contrat des journaux

Répertoire `telemetry/<squad>/<periode>/`. Facturation : `cout_carbone_*.md` ; conformité : `*_squad_*.md`.

La première table de facturation porte huit colonnes dans cet ordre : rôle, PID, modèle, requêtes, Prompt (In), Cache (In), Output, Thinking. Espaces numériques et virgules décimales sont acceptés. Les lignes TOTAL sont exclues du calcul. Une table malformée invalide l’import.

La conformité doit donner `Total de Livrables jugés : N` et de préférence `Résultats acceptés : A`. L’ancien champ `Fiabilité Composée (Ps) : 95,5 %` reste lisible : il estime A à partir du taux, potentiellement arrondi, et exige confirmation qu’il s’agit bien du taux **final**, pas du premier passage. Les comptes explicites ont priorité.

Avant calcul, confirmer que journaux et coûts couvrent la même période, sans doublons ni populations superposées. Les journaux identiques sont refusés ; les formats historiques sans identifiants unitaires ne permettent pas de détecter tous les chevauchements. C2 et heures humaines proviennent du premier onglet et doivent représenter la période importée. Les champs de compteurs doivent préciser si cache et Thinking sont déjà inclus dans leurs totaux, via les deux cases dédiées.

L’identifiant du modèle est rapproché du catalogue après normalisation typographique, sans deviner un prix à partir de « pro » ou « flash ». Les tarifs historiques conservés sont marqués `historique_non_verifie` ; ils ne constituent pas une recommandation actuelle. `p_cache_1M` permet un tarif cache explicite ; sinon le ratio saisi est une hypothèse de simulation. Les frais de création/stockage éventuels sont à intégrer séparément aux coûts de période. Vérifier les compteurs, devises et factures avant décision réelle.

## Exécution et tests

Restaurer l’environnement déclaré par `renv.lock`, puis lancer `shiny::runApp()`. `app.R` charge explicitement les noyaux `logic_maths.R`, `logic_parsers.R` et `logic_audit.R`.

```r
testthat::test_dir("tests/testthat")
```

Les tests couvrent les deux cas, les sensibilités, le micro-cas des dates, les formats historiques, les tarifs inconnus, les données absentes, le cache, la conversion et les réactifs Shiny. Les tests d’intégration exigent les dépendances réelles et ne sont pas ignorés silencieusement.

Pour l’audit du 27 septembre 2026, les dépendances absentes ont été installées dans `/tmp/saga-r-lib` sans modifier la bibliothèque personnelle ni `renv.lock`. Commande de reproduction dans cet environnement temporaire : `R_LIBS=/tmp/saga-r-lib Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'`. Une autre machine doit restaurer les dépendances du projet.

Voir le dossier [audit documentaire M1](../../KNOWLEDGE/SAGA-IA/M1/AUDIT_H4E/RAPPORT.md). Les données des préréglages sont également décrites dans les deux cadrages du corpus.
