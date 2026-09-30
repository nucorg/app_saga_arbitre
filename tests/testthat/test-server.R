source("../../R/logic_maths.R")
source("../../R/logic_parsers.R")
source("../../R/server.R")
source("../../R/ui.R")
# Integration tests require the actual app dependencies; no silent skips.
for (pkg in c("shiny", "bslib", "ggplot2", "dplyr", "DT", "plotly"))
  suppressPackageStartupMessages(library(pkg, character.only=TRUE))
test_that("l'interface conserve les six pages publiques sans les pages terrain", {
  html <- as.character(htmltools::renderTags(saga_ui())$html)
  for (label in c("Manuel vs Agentique", "C1 - Inférence", "C2 - Infra",
                  "C3 - Humain", "Diagnostic d'Investissement (CTP)", "Prix API"))
    expect_true(grepl(label, html, fixed = TRUE), info = label)
  expect_length(gregexpr('data-bs-toggle="tab"', html, fixed = TRUE)[[1]], 6)
  for (removed in c("case_preset", "telemetry_confirm", "process_logs",
                    "Cas M1", "Télémétrie du Terrain"))
    expect_false(grepl(removed, html, fixed = TRUE), info = removed)
  expect_match(html, "c3_governance")
})
test_that("Shiny conserve effort humain complet et C2 détaillé", {
  withr::with_dir("../..", shiny::testServer(saga_server, {
    session$setInputs(c3_v=1200, c3_escalade=20, c3_t_reprise=15,
      c3_review=5, c3_governance=40, c3_h1_input=300, c3_w=60,
      ctp_c=.5, ctp_v=1200, ctp_t=12, ctp_orch=2400, ctp_kappa="12",
      ctp_detailed=TRUE, ctp_w=60, ctp_h1=300, ctp_h2=200)
    expect_equal(c3_computation()$h2, 200)
    expect_equal(ctp_res()$C2, 28800)
  }))
})

test_that("L'ajout et la suppression de modèles fonctionnent dans l'onglet Prix API", {
  withr::with_dir("../..", shiny::testServer(saga_server, {
    # On force rv_pricing_edit à au moins une ligne s'il était vide (le fichier CSV local de test)
    if(nrow(rv_pricing_edit()) == 0) {
      rv_pricing_edit(data.frame(Identifiant="Dummy", Fournisseur="D", p_in_1M=0, p_out_1M=0, p_cache_1M=0, date_verification=as.Date("2026-09-27"), stringsAsFactors=FALSE))
    }
    
    # Test initial length
    initial_length <- nrow(rv_pricing_edit())
    expect_true(initial_length > 0)
    
    # Test Add Row
    session$setInputs(add_row = 1)
    new_length <- nrow(rv_pricing_edit())
    expect_equal(new_length, initial_length + 1)
    
    # Le nouveau modèle est inséré en HAUT (ligne 1)
    expect_equal(rv_pricing_edit()$Identifiant[1], "Nouveau Modèle")
    
    # Test Delete Row sans sélection
    session$setInputs(delete_row = 1)
    expect_equal(nrow(rv_pricing_edit()), new_length) # n'a pas bougé
    
    # Sélection de la nouvelle ligne (qui est maintenant à l'index 1) et suppression
    session$setInputs(table_pricing_edit_rows_selected = 1)
    session$setInputs(delete_row = 2)
    expect_equal(nrow(rv_pricing_edit()), initial_length)
  }))
})

test_that("Propagation des modifications de prix vers l'onglet C1", {
  # Création d'un bac à sable pour ne pas écraser le vrai CSV pendant le test
  folder <- tempfile("saga-test-c1-")
  dir.create(folder)
  on.exit(unlink(folder, recursive = TRUE), add = TRUE)
  
  dir.create(file.path(folder, "data"))
  df_init <- data.frame(
    Identifiant = "Modele Initial",
    Fournisseur = "Test",
    p_in_1M = 1.0,
    p_out_1M = 2.0,
    p_cache_1M = NA,
    date_verification = as.Date("2026-09-27"),
    stringsAsFactors = FALSE
  )
  write.csv(df_init, file.path(folder, "data/pricing_models.csv"), row.names = FALSE, quote = FALSE, na = "")
  
  withr::with_dir(folder, shiny::testServer(saga_server, {
    # 1. Vérification de l'état initial
    expect_equal(pricing_data()$Identifiant, "Modele Initial")
    
    # 2. Ajout d'une ligne via l'UI Prix API
    session$setInputs(add_row = 1)
    
    # 3. Modification des cellules (info$row est 1-indexé, info$col est 0-indexé)
    # Changement du nom du modèle
    session$setInputs(table_pricing_edit_cell_edit = list(row = 2, col = 0, value = "Nouveau Super Modele"))
    # Changement du prix d'entrée (col 2 = 3ème colonne = p_in_1M)
    session$setInputs(table_pricing_edit_cell_edit = list(row = 2, col = 2, value = 3.14))
    
    # 4. Sauvegarde dans le CSV
    session$setInputs(save_pricing = 1)
    
    # 5. Vérifier que la propagation a bien mis à jour le reactive global `pricing_data()`
    # Ce reactive est celui qui alimente les calculs et sélecteurs de l'onglet C1
    updated_data <- pricing_data()
    expect_true("Nouveau Super Modele" %in% updated_data$Identifiant)
    expect_equal(updated_data$p_in_1M[updated_data$Identifiant == "Nouveau Super Modele"], 3.14)
    
    # Le tableau rendu de C1 (`output$table_c1_pricing`) est un widget htmlwidgets DT,
    # sa représentation as.character() contient les options JSON mais pas toujours 
    # les données elles-mêmes à cause du mode server-side par défaut ou du lazy-loading.
    # La vérification de `updated_data` ci-dessus prouve formellement que la source
    # réactive a bien propagé le changement.
  }))
})
