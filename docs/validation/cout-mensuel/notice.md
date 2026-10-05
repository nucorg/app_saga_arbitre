# Report du parcours mensuel — SAGA Arbitre public

2026-10-05. Report ciblé depuis le commit `f8e9506` de `app_saga_terrain` vers la version publique à six onglets.

Le premier onglet reprend le parcours validé : saisie mensuelle de C1/C2, travail humain C3, investissement séparé, durée de répartition analytique, préréglage Veille/Section 1, comparaison en session avec conservation des hypothèses et projection constante à six mois par défaut. Les références aux paramètres partagés avec la télémétrie sont retirées. Les cinq autres onglets, leur serveur, la gestion des tarifs personnels par session, le catalogue et le fichier de rattachement au déploiement sont préservés.

## Résultats et preuves

- **30 tests, 193 assertions**, aucun échec, avertissement, erreur ni test ignoré : [tests.json](tests.json). Les tests couvrent aussi les six pages publiques, l’absence des pages internes, l’import/export des tarifs, l’intégrité du catalogue et l’isolation des sessions.
- **13 contrôles navigateur** : scénario nominal, variantes, hypothèses conservées, projection à six/douze mois, acceptation nulle, volume invalide et ouverture des cinq autres onglets. Largeurs 1 280 et 390 pixels contrôlées. [Rapport interface](verification-interface.json).
- **Calculs vérifiés par appels réels à saga-maths** : [calculs-mcp.json](calculs-mcp.json). Les calculs de répartition analytique sont contrôlés séparément par les tests et l’interface. Le moteur historique est identique entre source et cible et n’a pas été modifié.
- [Traçabilité du report](report-transfert.json) : commits source et cible, résultats de tests et conservation des modules hors périmètre.
- [Scénario capturé](scenario.json), copie de la source modifiable [veille-section-1.json](../../../data/scenarios/veille-section-1.json).
- [Capture originale](capture-originale.png), [résultats recadrés](capture-resultats.png), contrôles [1 280 px](capture-1280.png) et [390 px](capture-390.png). Captures issues du navigateur réel sans retouche du contenu affiché.

Le scénario affiche **15 000 €/mois courant**, **1 500 €/mois de part d’investissement**, **16 500 €/mois analytique**, soit **12,50 € courant et 13,75 € analytique par note acceptée**. La projection constante reste distincte du CTP avec calibrage du cours. Les comparaisons ajoutées sont conservées en session uniquement.

## Reproduire

Depuis la racine du dépôt, avec les dépendances de `renv.lock` restaurées :

```bash
RENV_CONFIG_SYNCHRONIZED_CHECK=FALSE Rscript -e 'shiny::runApp(host="127.0.0.1", port=3854, launch.browser=FALSE)'
```

Ouvrir `http://127.0.0.1:3854`, puis cliquer sur **Charger l’exemple — Veille, Section 1** dans **Manuel vs Agentique**.

Pour le rejeu automatique et les captures, lancer Chrome dans un profil dédié :

```bash
google-chrome --headless --disable-gpu --no-first-run --no-default-browser-check --remote-debugging-port=9354 --user-data-dir=/tmp/saga-public-monthly-chrome-9354 about:blank
node tools/verify-monthly.mjs
```

Le script utilise Node 22 et le client CDP local. `SAGA_APP`, `SAGA_URL` et `CHROME_PORT` permettent de modifier les emplacements. Il renouvelle les observations et captures dans ce dossier et consigne les empreintes des sources utilisées. Les ressources HTTPS externes sont bloquées pendant le contrôle ; la police de repli du premier onglet assure la lisibilité hors ligne.

```bash
RENV_CONFIG_SYNCHRONIZED_CHECK=FALSE Rscript -e 'testthat::test_dir("tests/testthat", reporter="summary")'
RENV_CONFIG_SYNCHRONIZED_CHECK=FALSE Rscript scripts/deploy-public.R
```

La dernière commande a été exécutée **sans `--publish`** et a validé le paquet : `R/logic_monthly.R` et `data/scenarios/veille-section-1.json` sont inclus ; `docs` et `tools` sont exclus via `.rscignore`. Le fichier de déploiement préalablement modifié par l’utilisateur est intact. Aucun déploiement, commit ou push n’a été effectué lors de ce report.

Les autres sources applicatives sont conservées dans le dépôt cible. Le scénario et les empreintes capturées permettent de retrouver les paramètres et la version testée ; le commit de base seul ne suffit pas tant que les modifications du report ne sont pas committées.
