# Validation — CTP et solde conventionnel

2026-10-06 · Parcours de Section 1 · `app_saga_arbitre`.

## Résultat

Le préréglage **Veille, CTP à 6 mois** reprend 1 200 entrées/mois, C1 = 600 €/mois,
C2 = 2 400 €/mois, 60 €/h, trois mois de calibrage à 300 h/mois puis 200 h/mois,
et 36 000 € d’investissement initial. Il donne **108 000 € d’exploitation** et
**144 000 € de projet**, sans addition de parts analytiques de l’investissement.
La lecture de valeur, à 30 minutes manuelles, 50 % de réaffectation et 60 €/h réaffectée,
donne **2 100 h nettes**, **63 000 € valorisés** et **+9 000 € de solde conventionnel**.

Le CTP repose sur une série mensuelle commune aux totaux et graphiques. Les budgets C1/C2
restent fixes quand le volume change. Le travail humain suit les phases : les heures de
calibrage remplacent celles de croisière. Le solde est calculé mois par mois ; une surcharge
est valorisée intégralement, sans réduction par alpha ni dilution dans les gains d’une autre
phase. C3 est déjà intégré au temps net. Un investissement vide reste inconnu, distinct de zéro.

## Preuves conservées

- [Scénario modifiable](../../../data/scenarios/veille-ctp-section-1.json) et [copie capturée](scenario.json).
- [Tests R](tests.json) : **38 tests, 268 assertions**, sans échec, avertissement ni test ignoré.
- [Contrôle navigateur](verification-interface.json) : 17 cas, dont le nominal, les variantes,
  les données inconnues/invalides et les cinq autres onglets communs ; adaptation à 1 280 et 390 px.
- [Contrôles MCP](calculs-mcp.json) : huit appels de contrôle via le protocole MCP stdio du
  lanceur `app_saga_terrain/mcp/run.sh`, avec découverte du paramètre `calibration_months`.
  La réponse brute est conservée. Le client lit aussi le format texte R renvoyé par mcptools,
  sans exécuter de code R local pour refaire le calcul. Le moteur CTP est identique dans les deux dépôts.
- [Capture originale](capture-originale.png), [coût recadré](capture-ctp.png), [solde recadré](capture-solde.png).
  Captures du navigateur réel, sans modification du contenu affiché. Empreintes des sources,
  paramètres, navigateur et rectangles de capture consignés dans le contrôle navigateur.

La répartition analytique et la valeur réaffectée ne sont pas calculées par l’outil MCP CTP :
les tests applicatifs vérifient séparément l’investissement et le solde. Les variantes couvertes
incluent alpha à 10 % (−41 400 € sans changement du CTP), deux mois de calibrage
(102 000 € d’exploitation, 138 000 € de projet et +12 000 € de solde) et une phase en surcharge.

## Rejouer

Depuis le dépôt, après restauration des dépendances de `renv.lock` :

```bash
RENV_CONFIG_SYNCHRONIZED_CHECK=FALSE Rscript -e 'testthat::test_dir("tests/testthat", reporter="summary")'
RENV_CONFIG_SYNCHRONIZED_CHECK=FALSE Rscript -e 'shiny::runApp(host="127.0.0.1", port=3864, launch.browser=FALSE)'
```

Ouvrir l’application, sélectionner **Diagnostic d’Investissement (CTP)**, charger l’exemple,
puis déplier **Temps libéré et solde conventionnel**. Les autres onglets sont indépendants.

Pour les captures automatisées, démarrer Chrome dans un profil temporaire dédié puis lancer
le script avec Node 22. Le rejeu remplace les artefacts de ce dossier et vérifie les résultats
avant d’écrire le rapport final.

```bash
google-chrome --headless --disable-gpu --no-first-run --no-default-browser-check --remote-debugging-port=9364 --user-data-dir=/tmp/saga-ctp-chrome-9364 about:blank
SAGA_URL=http://127.0.0.1:3864 node tools/verify-ctp.mjs
```

`SAGA_APP`, `SAGA_URL` et `CHROME_PORT` permettent de changer les emplacements. Le script
bloque les ressources HTTPS externes pour un contrôle reproductible avec la police de repli.
Les contrôles des deux dépôts doivent être exécutés successivement s’ils utilisent le même navigateur.

Depuis `app_saga_terrain`, vérifier les nouvelles durées via le serveur MCP réel :

```bash
python3 tools/verify-ctp-mcp.py
```

Les clients MCP déjà ouverts doivent reconnecter `saga-maths` pour découvrir le nouveau
paramètre facultatif. Les appels sans `calibration_months` gardent trois mois par défaut.
Le schéma, le lanceur et toutes les réponses sont conservés dans le rapport MCP.

## Conservation du périmètre

Les autres onglets et leurs serveurs sont préservés. Les deux versions conservent leurs
particularités, notamment les tarifs personnels par session dans la version publique.
Son fichier de rattachement préalablement modifié est intact. Le contrôle local
`Rscript scripts/deploy-public.R` a vérifié l’inclusion du module et du scénario sans publier.
Les rapports et outils restent exclus du paquet public.

Les scripts historiques fondés sur `ctp_c`, `vb_ctp_val` ou `plot_ctp_donut` correspondent
à l’ancienne interface. Le nouveau parcours utilise `ctp_c1_month` en €/mois, une durée
`ctp_calibration` explicite et des sorties distinctes pour exploitation et projet. Les captures
historiques ne sont pas remplacées par ce pilote. Aucun PDF, commit, push ou déploiement
n’est effectué dans ce chantier. Le commit de base et les empreintes identifient les sources
capturées tant que les modifications n’ont pas été committées.
