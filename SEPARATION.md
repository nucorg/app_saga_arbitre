# Séparation SAGA — 30 septembre 2026

## État et responsabilités

- `app_saga_arbitre` : six pages publiques, dépôt distant `nucorg/app_saga_arbitre` conservé.
- `../app_saga_terrain/` : copie complète locale des huit pages, avec l’historique Git et les 12 journaux ; aucun distant Git ni rattachement actif à shinyapps.io.
- Point de départ : commit `40811c8`. Le code applicatif, les tarifs, le logo, le lockfile et la télémétrie de la copie complète ont été comparés par SHA-256 avant simplification.
- Les deux projets ont leurs propres fichiers de données et bibliothèques de projet renv. Le cache de packages renv peut être partagé ; aucune bibliothèque ne pointe vers celle de l’autre projet.

Les journaux restent exclus de Git. Déposer les nouveaux journaux dans `../app_saga_terrain/telemetry/<squad>/<periode>/` et sauvegarder ce dossier après import. Aucun producteur externe visant l’ancien chemin n’a été trouvé dans les scripts INFRA et AGENTIC examinés.

Les tarifs locaux font foi. Les modifications futures des tarifs sont indépendantes dans chaque application. Sur shinyapps.io, les écritures dans le système de fichiers de l’instance restent temporaires et peuvent disparaître au redéploiement ou au remplacement d’une instance.

## Sauvegardes vérifiées

Dossier : `/home/boris/VIBE/projets/_sauvegardes/saga-separation-20260930-170408/`.

- `app_saga_arbitre-complet.tar.gz` : dépôt initial, historique Git, données et fichiers cachés, hors caches et bibliothèques reconstructibles.
- `inventory.json` et `archive.sha256` : inventaire et empreintes SHA-256 ; archive relue et vérifiée avant toute suppression.
- `shinyapps-bundle-12627615.tar.gz` : bundle réellement actif avant séparation, téléchargé via l’API authentifiée. MD5 vérifié : `6fddff736a4203a4442e8963f48d04b0`.
- Les anciens bundles et l’archive initiale contiennent la télémétrie. Les conserver localement ; ne pas les placer dans les fichiers à publier.

L’archive initiale permet de restaurer les sources dans un dossier séparé sans écraser les travaux futurs. Le miroir et Git ne remplacent pas une sauvegarde vérifiée des journaux.

## Vérification et déploiement

Depuis la racine du dépôt public, dans l’environnement renv du projet :

```sh
Rscript -e 'testthat::test_dir("tests/testthat")'
Rscript scripts/deploy-public.R
```

La seconde commande affiche les fichiers qui seront envoyés, vérifie le rattachement à `18052078` et ne publie rien. `.rscignore` exclut la télémétrie, les tests, les outils de publication et les documents internes. Les noms de dossiers y sont écrits sans barre finale, conformément au comportement de rsconnect.

Publication explicite sur l’application existante :

```sh
Rscript scripts/deploy-public.R --publish
```

Le script vérifie le compte `qognito`, le serveur `shinyapps.io`, l’identité et l’URL de l’application distante avant de publier. Il refuse tout fichier hors des sources, données et ressources applicatives prévues. L’URL attendue reste : https://qognito.shinyapps.io/app_saga_arbitre/.

`rsconnect` est un outil de publication déjà installé dans la bibliothèque du projet ; il n’est pas ajouté aux dépendances de l’application. `scripts/.renvignore` exclut cet outil de l’analyse des dépendances applicatives. Sur un nouveau poste, installer rsconnect séparément si nécessaire.

La publication peut interrompre les sessions actives. Contrôler ensuite les six pages, les graphiques, le catalogue de tarifs et les logs. Les versions des packages et les formules des pages conservées n’ont pas été modifiées.

## Vérifications réalisées

- Suites de tests de référence, de la copie complète et de la version simplifiée : réussies.
- Les deux environnements renv sont cohérents avec le lockfile inchangé.
- Contrôle Chrome local : six pages publiques et huit pages complètes, graphiques et logo affichés, aucune erreur JavaScript. Import des journaux réels vérifié dans la copie complète.
- Indépendance des écritures tarifaires vérifiée dans des dossiers temporaires. L’exclusion de télémétrie a aussi été vérifiée avec un dossier factice contenant des journaux.
- Publication réussie sur l’application existante `18052078`, bundle actif `12628277`, URL inchangée et réponse HTTP 200. Logs de démarrage sans erreur détectée.
- Contrôle Chrome en production : les six pages, les sept graphiques et le catalogue sont rendus ; logo chargé, aucune erreur JavaScript ni erreur de sortie persistante après initialisation.
- Le calcul C2, inchangé par la séparation, peut afficher transitoirement « no rows to aggregate » avant réception des cases à cocher. Le résultat devient normal après chargement des sélections (269,72 EUR avec les valeurs par défaut vérifiées). Le contrôle distant attend cette réception ; ce comportement reste documenté pour une correction distincte.
- Chrome bloque aussi la requête historique vers `polyfill.io` ; les fonctionnalités contrôlées restent opérationnelles.
- Les rapports, captures et logs sont conservés dans le dossier de sauvegarde ci-dessus.

## Retour arrière

Le bundle initial `12627615` reste l’identité de référence du retour arrière. Depuis le tableau de bord shinyapps.io, réactiver ce bundle si l’interface le permet. La commande R ci-dessous utilise le client interne de la version rsconnect 1.11.2 vérifiée pendant l’opération ; elle met à jour la même application sans en créer une autre :

```r
client <- rsconnect:::clientForAccount(rsconnect::accountInfo("qognito", "shinyapps.io"))
app <- client$getApplication("18052078")
stopifnot(app$name == "app_saga_arbitre",
          app$url == "https://qognito.shinyapps.io/app_saga_arbitre/")
task <- client$deployApplication(app, bundleId = "12627615")
task_id <- if (is.null(task$task_id)) task$id else task$task_id
client$waitForTask(task_id)
```

Ce retour arrière rétablit aussi les deux pages retirées et les journaux inclus dans l’ancien bundle. Si le bundle distant n’est plus disponible, extraire sa sauvegarde dans un dossier distinct et republier explicitement sur `18052078`.

Ne pas déployer depuis `app_saga_terrain`. Les anciens commits de son historique contiennent encore l’ancien rattachement : ne pas le rétablir. Pour la maintenance commune, transférer uniquement les correctifs sélectionnés et vérifier les deux suites de tests ; éviter une fusion globale réintroduisant les pages supprimées.
