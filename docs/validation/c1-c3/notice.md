# C1 et C3 — interface et reports

Les deux onglets utilisent désormais le même parcours que C2 : hypothèses regroupées et expliquées, résultat identifié, deux boutons de report ponctuel, exemple modifiable et affichage adapté au mobile.

## C1 — Inférence

Choisir les volumes de jetons **par appel**, le taux EUR/USD, le volume mensuel et le nombre moyen d’appels par entrée. Ce dernier comprend les étapes et les nouvelles tentatives. Les trois modèles utilisent les tarifs actifs de la session ; sélectionner A, B ou C pour retenir son budget. Le modèle retenu est signalé dans le résultat et le graphique.

Le report remplace uniquement `cost_c1_month` ou `ctp_c1_month`. Le volume de la destination est conservé. Le budget reste fixe dans cette destination ; une modification de l’estimation ou des tarifs demande un nouveau report. La comparaison suppose un seul modèle et une taille moyenne d’appel, sans réductions de cache ou de lots, appels à des outils ni taxes.

[L’exemple C1](../../../data/scenarios/c1-estimation.json) donne, avec les tarifs de référence du 27 septembre 2026, 0,0044 € par appel et 10,56 €/mois pour A : 1 200 entrées × 2 appels. Il illustre la méthode d’estimation ; il ne reprend pas le budget global C1 du cours. Les modifications appliquées dans Prix API changent son résultat.

## C3 — Humain

Renseigner le volume, le taux horaire, le travail total de calibrage, puis les inducteurs de croisière : revue de toutes les entrées, part à reprendre et durée de reprise, supervision et maintenance fixes. Un champ vide demeure inconnu ; zéro est une hypothèse explicite. Les résultats distinguent heures et euros par phase.

Le report mensuel utilise la phase choisie (croisière par défaut) et remplace `maint_h` **et** `cost_h`. Ce coût horaire est commun au manuel et au dispositif : le report peut donc modifier aussi le coût manuel de référence. Le report CTP remplace `ctp_h1`, `ctp_h2` et `ctp_w`. Il conserve le volume, la durée du calibrage, l’investissement et l’horizon. La durée de calibrage est réglée dans le CTP ; aucun découpage fixe « mois 1 à 3 » n’est imposé dans C3. L’horizon du CTP reste de six mois par défaut.

[L’exemple C3](../../../data/scenarios/c3-estimation.json) donne 300 h/mois en calibrage et 200 h/mois en croisière, à 60 €/h. La croisière comprend 100 h de revue, 60 h de reprises et 40 h de supervision et maintenance.

## Validation et rejeu

- [tests.json](tests.json) conserve la suite de tests complète des calculs et des reports : choix de modèle, appels multiples, phases, inconnus, valeurs invalides, zéros et absence de synchronisation.
- [calculs-mcp.json](calculs-mcp.json) conserve les arguments et réponses de `saga-maths` pour les coûts par appel et les heures de croisière. La multiplication en budget mensuel et le report des champs sont vérifiés dans les tests applicatifs.
- [verification-interface.json](verification-interface.json) conserve les observations du parcours réel dans Chrome, les empreintes des sources, le nombre d’onglets et les contrôles à 1 280 et 390 pixels, ainsi que la navigation clavier.
- Captures : [C1](c1-desktop.png), [C3](c3-desktop.png), [C1 mobile](c1-mobile-resultat.png), [C3 mobile](c3-mobile-resultat.png). Les captures de saisie et les recadrages des résultats sont conservés dans le même dossier.

Depuis la racine du dépôt, avec les dépendances R du projet :

```sh
RENV_CONFIG_SYNCHRONIZED_CHECK=FALSE Rscript -e 'testthat::test_dir("tests/testthat", reporter="summary")'
```

Lancer l’application et Chrome dans deux terminaux, puis le contrôle dans un troisième (ports libres, Node ≥ 22) :

```sh
RENV_CONFIG_SYNCHRONIZED_CHECK=FALSE Rscript -e 'shiny::runApp(".", host="127.0.0.1", port=3866, launch.browser=FALSE)'
```

```sh
google-chrome --headless --disable-gpu --no-first-run --no-default-browser-check --remote-debugging-port=9366 --user-data-dir=/tmp/saga-components-validation about:blank
```

```sh
CHROME_PORT=9366 SAGA_URL=http://127.0.0.1:3866 node tools/verify-components.mjs
```

Le contrôle navigateur bloque HTTPS, utilise les tarifs locaux de référence et régénère ses observations et captures. Les estimations et les tarifs modifiés restent propres à la session.
