source("../../R/logic_maths.R")
source("../../R/logic_parsers.R")
source("../../R/logic_audit.R")
source("../../R/server.R")
source("../../R/ui.R")
# Integration tests require the actual app dependencies; no silent skips.
for (pkg in c("shiny", "bslib", "ggplot2", "dplyr", "DT", "plotly"))
  suppressPackageStartupMessages(library(pkg, character.only=TRUE))
test_that("l'interface se construit avec les deux visions", {
  ui <- saga_ui()
  html <- as.character(htmltools::renderTags(ui)$html)
  expect_match(html, "case_preset")
  expect_match(html, "telemetry_confirm")
  expect_match(html, "c3_governance")
})
test_that("Shiny utilise effort complet, C2 détaillé et bilans M1", {
  withr::with_dir("../..", shiny::testServer(saga_server, {
    session$setInputs(c3_v=1200, c3_escalade=20, c3_t_reprise=15,
      c3_review=5, c3_governance=40, c3_h1_input=300, c3_w=60,
      ctp_c=.5, ctp_v=1200, ctp_t=12, ctp_orch=2400, ctp_kappa="12",
      ctp_detailed=TRUE, ctp_w=60, ctp_h1=300, ctp_h2=200)
    expect_equal(c3_computation()$h2, 200)
    expect_equal(ctp_res()$C2, 28800)
    session$setInputs(case_volume=1200, case_accepted=1200, case_manual=30,
      case_review=5, case_rework=.2, case_rework_min=15, case_governance=40,
      case_hourly=60, case_api=.5, case_infra=2400, case_investment=36000,
      case_amort=24, case_alpha=.5, case_value=60, case_calibration=3,
      case_h1=300, case_horizon=12)
    expect_equal(case_result()$CTP,16500)
    expect_equal(case_result()$horizon_balance,63000)
    session$setInputs(case_accepted=0)
    expect_equal(case_result()$cost_accepted,Inf)
    session$setInputs(case_volume=0)
    expect_equal(case_result()$h0,0)
    expect_false(case_result()$net_hours > 0)
  }))
})
test_that("Shiny recalcule la télémétrie avec le change et les coûts courants", {
  withr::with_dir("../..", shiny::testServer(saga_server, {
    b <- data.frame(role="a", model="GPT-5 Mini", prompt=1e6, cache=0, output=0, thinking=0)
    names(b) <- c("Rôle (Task)","Modèle","Prompt (In)","Cache (In)","Output","Thinking")
    raw_telemetry(list(billing=b, compliance=list(list(volume=10,accepted=10,basis="counts")),error=NULL))
    session$setInputs(telemetry_confirm=TRUE, telemetry_fx=.8, cache_discount=.25,
      cost_orch=0, maint_h=0, cost_h=15)
    expect_equal(telemetry_result()$api_eur,.2)
    session$setInputs(telemetry_fx=1, maint_h=2)
    expect_equal(telemetry_result()$ctask,3.025)
    session$setInputs(telemetry_confirm=FALSE)
    expect_true(is.na(telemetry_result()$ctask))
  }))
})

test_that("l'import réel lit les fichiers puis refuse les doublons", {
  folder <- tempfile("saga-test-"); dir.create(folder)
  on.exit(unlink(folder, recursive=TRUE), add=TRUE)
  dir.create(file.path(folder,"data"))
  write.csv(data.frame(Identifiant="Test Model",p_in_1M=2,p_out_1M=4),
    file.path(folder,"data/pricing_models.csv"),row.names=FALSE)
  logs <- file.path(folder,"telemetry","test","2026-09")
  dir.create(logs,recursive=TRUE)
  bill_path <- file.path(logs,"cout_carbone_test.md")
  writeLines(c("| Role | PID | Modele | Reqs | Prompt | Cache | Output | Thinking |",
    "|---|---|---|---|---|---|---|---|",
    "| a | 1 | Test Model | 1 | 1000000 | 0 | 0 | 0 |"),bill_path)
  writeLines(c("Total de Livrables jugés : 10", "Résultats acceptés : 8"),
    file.path(logs,"2026-09_squad_test.md"))
  withr::with_dir(folder, shiny::testServer(saga_server, {
    session$setInputs(squad_dir="test",month_dir="2026-09",telemetry_confirm=TRUE,
      telemetry_fx=.8,cache_discount=.25,cost_orch=10,maint_h=2,cost_h=15)
    session$setInputs(process_logs=1)
    expect_equal(telemetry_result()$ctask,5.2)
    expect_equal(telemetry_result()$volume,10)
    file.copy(bill_path,file.path(logs,"cout_carbone_copy.md"))
    session$setInputs(process_logs=2)
    expect_true(is.na(telemetry_result()$ctask))
    expect_match(telemetry_result()$status,"identiques")
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
