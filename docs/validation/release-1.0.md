# Arbitre 1.0 — validation

14 octobre 2026. Compagnon facultatif du PDF, interface française, licence MIT.

- Restauration complète de 85 packages depuis `renv.lock` dans une bibliothèque de projet neuve, Linux et R 4.5.2 : réussie.
- Suite `testthat` et chargement complet `scripts/smoke.R` : réussis.
- [CI Linux, Windows et macOS](https://github.com/nucorg/app_saga_arbitre/actions/runs/38547938213) : trois jobs réussis sur `ed674e6a91000107c3d5b4c2aaaf04d0a820986a`.
- Navigateur Chrome Linux, six onglets avec toutes les requêtes externes bloquées : aucune requête externe, aucune erreur JavaScript, aucune sortie Shiny en erreur.
- README d'installation indépendant des chemins de l'auteur ; scripts distants Polyfill et MathJax inutilisés supprimés, police système locale.
- Inventaire des chemins Git courants et historiques : aucun dossier telemetry, PDF ou fichier de secrets retrouvé. Aucun historique réécrit.

La validation navigateur a été exécutée sur Linux ; les deux autres OS ont fait l'objet de la restauration, des tests et du chargement en CI. La modification ultérieure de ce dossier ne change pas les calculs. La configuration shinyapps.io locale préexistante est conservée, sans déploiement hébergé.
