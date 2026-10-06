# Validation de C2 — budget mensuel par poste

Les six montants saisis en euros mensuels constituent un budget attribué au dispositif. Le CSV historique `data/pricing_infra.csv` est conservé, mais n’est plus lu par l’application. Le catalogue des tarifs API reste indépendant.

L’exemple versionné [veille-c2.json](../../../data/scenarios/veille-c2.json) contient 500 + 350 + 300 + 700 + 300 + 250 = **2 400 €/mois**. Cette ventilation est une hypothèse pédagogique à remplacer par les dépenses du projet. Les montants excluent les appels aux modèles, le temps humain et l’investissement initial. Ils doivent partager la même base fiscale et être mensualisés avant la saisie.

## Résultats et preuves

- [tests.json](tests.json) : suite complète, aucune erreur ni exclusion. [tests-server-final.json](tests-server-final.json) : contrôle du serveur après les derniers ajustements visuels.
- [verification-interface.json](verification-interface.json) : entrées et observations de douze cas dans Chrome, version du navigateur, empreintes des sources, affichage à 1280 et 390 pixels, et volet mobile ouvert puis fermé.
- [calculs-mcp.json](calculs-mcp.json) : paramètres et réponses du serveur `saga-maths` pour les calculs mensuel et CTP concernés par le report.
- [capture-desktop.png](capture-desktop.png), [capture-budget.png](capture-budget.png), [capture-mobile-saisie.png](capture-mobile-saisie.png) et [capture-mobile-budget.png](capture-mobile-budget.png) : captures réelles des versions vérifiées.

Les tests couvrent les champs inconnus, les montants invalides, les centimes, les six zéros explicites, l’effacement, le report limité à sa destination, l’absence de synchronisation et l’isolation entre sessions. Les tests du serveur vérifient également le fonctionnement sans CSV d’infrastructure.

Pour reproduire l’exemple du cours, charger d’abord l’exemple de **Manuel vs Agentique** ou du **Diagnostic d’Investissement (CTP)**, puis charger et reporter l’exemple C2. Le report mensuel donne 15 000 €/mois de fonctionnement courant et 16 500 €/mois analytique. Le report CTP donne 108 000 € d’exploitation, 144 000 € avec l’investissement et un solde calculé de 9 000 €, selon les autres hypothèses de l’exemple. Dans le CTP, le report active le total déjà évalué et remet le coefficient à 1 pour éviter une double majoration.

Le contrôle MCP restitue 12,50 € de coût courant par résultat avec C1 = 0,50 €, C2 = 2 € et C3 = 10 €, ainsi que 108 000 € d’exploitation à six mois : C1 = 3 600 €, C2 = 14 400 €, C3 = 90 000 €. La somme des six postes C2, l’investissement et le solde sont contrôlés par les tests applicatifs ; ils ne sont pas des résultats du serveur MCP.

## Rejeu

Depuis la racine du dépôt, avec les dépendances R du projet disponibles :

```sh
RENV_CONFIG_SYNCHRONIZED_CHECK=FALSE Rscript -e 'testthat::test_dir("tests/testthat", reporter="summary")'
```

Pour le contrôle d’interface, lancer l’application et Chrome dans deux terminaux, puis le script dans un troisième. Les ports doivent être libres et Node doit être de version 22 ou ultérieure.

```sh
RENV_CONFIG_SYNCHRONIZED_CHECK=FALSE Rscript -e 'shiny::runApp(".", host="127.0.0.1", port=3866, launch.browser=FALSE)'
```

```sh
google-chrome --headless --disable-gpu --no-first-run --no-default-browser-check --remote-debugging-port=9366 --user-data-dir=/tmp/saga-c2-validation about:blank
```

```sh
CHROME_PORT=9366 SAGA_URL=http://127.0.0.1:3866 node tools/verify-c2.mjs
```

Le script bloque les accès HTTPS du navigateur et régénère les captures et le rapport d’interface dans ce dossier. Les budgets saisis restent propres à chaque session et ne sont pas sauvegardés automatiquement.
