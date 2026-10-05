# SAGA Arbitre — Simulations de coûts et diagnostic H4E

Application R/Shiny. Les résultats dépendent de données et conventions explicites ; ils ne certifient ni rentabilité réelle, ni qualité opérationnelle, ni conformité d’un service.

## Parcours

- **Manuel vs Agentique** : comparaison d’un mois de croisière, coûts courants et analytiques distincts, puis coûts par résultat finalement accepté. C1 et C2 sont saisis en EUR/mois ; C3 en heures mensuelles valorisées au coût horaire commun. La projection constante est secondaire et indépendante de la répartition analytique (voir ci-dessous).
- **C1** : simulation au catalogue de référence ou aux tarifs personnels appliqués à la session et conversion USD/EUR explicite.
- **C2** : frais non humains fixes et variables. Fixe/variable ne signifie pas CAPEX/OPEX. Les prix sont des hypothèses locales à vérifier.
- **C3** : revue systématique, reprises additionnelles et gouvernance/entretien. Le forfait de calibrage représente tout l’effort de cette phase ; trois mois est l’hypothèse du microscope historique.
- **CTP** : total sur l’horizon. Les transferts C1/C2/C3 restent manuels et doivent conserver volume, devise et période. Si C2 est déjà détaillé, la case correspondante impose κ=1 et évite une seconde multiplication.
- **Prix API** : tarifs personnels par session, import/export CSV et application explicite aux calculs C1.

## Reproduire le coût mensuel analytique — Section 1

Dans **Manuel vs Agentique**, cliquer sur **Charger l’exemple — Veille, Section 1**.
Le scénario versionné [`data/scenarios/veille-section-1.json`](data/scenarios/veille-section-1.json)
contient tous les paramètres, unités et résultats attendus. Les champs restent modifiables.

| Paramètre | Valeur |
|---|---:|
| Entrées mensuelles / acceptation finale | 1 200 / 100 % |
| Temps manuel / coût horaire commun | 30 min / 60 EUR/h |
| C1 / C2 | 600 / 2 400 EUR/mois |
| C3 | 200 h/mois, soit 12 000 EUR/mois |
| Investissement dispositif / manuel | 36 000 / 0 EUR |
| Répartition analytique | 24 mois |
| Projection constante | 6 mois par défaut ; 12 mois au choix |

Résultats : **15 000 EUR/mois courant**, **1 500 EUR/mois de part d’investissement**,
**16 500 EUR/mois analytique** ; **12,50 EUR** et **13,75 EUR** par résultat accepté.
C2 récurrent reste séparé de l’investissement. Le manuel est comparé au même nombre
mensuel de résultats acceptés. Un écart de coûts n’est pas automatiquement une économie de trésorerie.

Les montants mensuels C1/C2 et les heures C3 restent fixes si le volume ou l’acceptation
changent. C1 inclut les nouvelles tentatives. Une acceptation nulle conserve les budgets
mais rend les ratios et projections comparatives non définis. Les valeurs manquantes,
négatives, le volume nul et les durées invalides affichent une demande de correction.

**Ajouter à la comparaison — session** conserve les hypothèses et résultats en mémoire,
ainsi que la référence manuelle propre à chaque scénario. La simulation courante reste
visible. Ce bouton n’exporte pas un scénario et les comparaisons disparaissent à la fin
de la session. Le fichier versionné constitue la référence reproductible du pilote.

La **projection cumulée à charge constante**, repliée initialement, compte l’investissement
une seule fois au mois zéro, puis les coûts courants. Modifier la durée de répartition
analytique n’affecte pas cette courbe. Elle ne reproduit pas le CTP du cours avec calibrage.
Les **24 mois de répartition** et l’**horizon de projection** sont deux paramètres distincts.

Compatibilité : l’ancien champ `cost_tokens` (EUR/entrée) devient `cost_c1_month`
(EUR/mois). Les scripts de saisie visant ce dépôt doivent multiplier le coût unitaire
par le volume avant de renseigner ce champ. `ps` est désormais une saisie numérique,
toujours en pourcentage.
Le moteur historique garde ses signatures et ses unités. Le report conserve les six onglets publics et leur gestion des tarifs personnels par session.

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

Restaurer l’environnement déclaré par `renv.lock`, puis lancer `shiny::runApp()`. `app.R` charge explicitement les fonctions de `logic_maths.R`, `logic_monthly.R` et `logic_parsers.R`, puis l’interface et le serveur.

```r
testthat::test_dir("tests/testthat")
```

Les tests couvrent les calculs des pages publiques, les six pages de navigation, l’absence des pages retirées, les tarifs, les dates et l’application des tarifs à C1, l’isolation de sessions simultanées, l’intégrité du CSV de référence et le cycle import/export/réinitialisation. Les tests d’intégration exigent les dépendances réelles et ne sont pas ignorés silencieusement.

Pour l’audit du 27 septembre 2026, les dépendances absentes ont été installées dans `/tmp/saga-r-lib` sans modifier la bibliothèque personnelle ni `renv.lock`. Commande de reproduction dans cet environnement temporaire : `R_LIBS=/tmp/saga-r-lib Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'`. Une autre machine doit restaurer les dépendances du projet.

Voir le dossier [audit documentaire M1](../../KNOWLEDGE/SAGA-IA/M1/AUDIT_H4E/RAPPORT.md). Les données des préréglages sont également décrites dans les deux cadrages du corpus.

## Report du parcours mensuel — 2026-10-05

Report ciblé depuis `app_saga_terrain`, commit `f8e9506a06f4c082ab71b9e049cd4d62372750e3`. Seuls le premier onglet, ses styles, son module, son scénario et ses tests sont repris. Aucun ajout des pages internes. Les autres onglets, le catalogue de référence et la configuration de déploiement sont préservés. Voir [la validation et le rejeu](docs/validation/cout-mensuel/notice.md).
