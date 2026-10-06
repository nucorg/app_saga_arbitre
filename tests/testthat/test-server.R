source("../../R/logic_maths.R")
source("../../R/logic_ctp.R")
source("../../R/logic_monthly.R")
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
                    "Cas M1", "Télémétrie du Terrain", "télémétrie"))
    expect_false(grepl(removed, html, fixed = TRUE), info = removed)
  expect_match(html, "c3_governance")
})
test_that("Shiny conserve effort humain complet et C2 détaillé", {
  withr::with_dir("../..", shiny::testServer(saga_server, {
    session$setInputs(c3_v=1200, c3_escalade=20, c3_t_reprise=15,
      c3_review=5, c3_governance=40, c3_h1_input=300, c3_w=60,
      ctp_c1_month=600, ctp_calibration=3, ctp_investment=36000, ctp_v=1200, ctp_t=12, ctp_orch=2400, ctp_kappa="12",
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

test_that("appliquer et rétablir les tarifs ne modifient jamais le CSV de référence", {
  withr::with_dir("../..", {
    before <- readBin("data/pricing_models.csv", "raw", n = file.info("data/pricing_models.csv")$size)
    shiny::testServer(saga_server, {
      reference <- pricing_data()
      session$setInputs(table_pricing_edit_cell_edit = list(row = 1, col = 2, value = "3,14"))
      expect_equal(rv_pricing_edit()$p_in_1M[1], 3.14)
      expect_equal(pricing_data(), reference)
      expect_match(output$pricing_status, "à appliquer")
      session$setInputs(apply_pricing = 1)
      expect_equal(pricing_data()$p_in_1M[1], 3.14)
      expect_match(output$pricing_status, "personnels")
      session$setInputs(reset_pricing = 1)
      expect_equal(rv_pricing_edit(), reference)
      expect_equal(pricing_data(), reference)
      expect_match(output$pricing_status, "référence")
      session$setInputs(add_row = 1)
      session$setInputs(add_row = 2)
      expect_equal(anyDuplicated(rv_pricing_edit()$Identifiant), 0)
    })
    expect_equal(readBin("data/pricing_models.csv", "raw", n = file.info("data/pricing_models.csv")$size), before)
  })
})

test_that("l'import prépare le brouillon et refuse un fichier invalide sans perdre les tarifs", {
  path <- tempfile(fileext = ".csv"); on.exit(unlink(path))
  personal <- data.frame(Identifiant = 'Personnel, "éco"', p_in_1M = 1.23, p_out_1M = 4.56)
  export_api_pricing(personal, path)
  withr::with_dir("../..", shiny::testServer(saga_server, {
    reference <- pricing_data()
    session$setInputs(import_pricing = list(name = "tarifs.csv", datapath = path))
    expect_equal(rv_pricing_edit()$Identifiant, personal$Identifiant)
    expect_equal(pricing_data(), reference)
    # Le handler réel du téléchargement exporte le brouillon, même non appliqué.
    download <- output$export_pricing
    expect_equal(import_api_pricing(download), validate_api_pricing(personal))
    session$setInputs(apply_pricing = 1)
    expect_equal(pricing_data(), validate_api_pricing(personal))
    writeLines(c("Identifiant,p_in_1M,p_out_1M", "Invalide,-1,2"), path)
    session$setInputs(import_pricing = list(name = "invalide.csv", datapath = path))
    expect_match(pricing_error(), "prix numérique")
    expect_equal(rv_pricing_edit(), validate_api_pricing(personal))
    expect_equal(pricing_data(), validate_api_pricing(personal))
    session$setInputs(reset_pricing = 1)
    expect_equal(pricing_data(), reference)
    expect_equal(pricing_error(), "")
  }))
})

test_that("une édition invalide et la suppression du dernier modèle laissent la table intacte", {
  withr::with_dir("../..", shiny::testServer(saga_server, {
    reference <- rv_pricing_edit()
    session$setInputs(table_pricing_edit_cell_edit = list(row = 1, col = 2, value = "abc"))
    expect_match(pricing_error(), "prix numérique")
    expect_equal(rv_pricing_edit(), reference)
    session$setInputs(table_pricing_edit_cell_edit = list(row = 1, col = 5, value = "2026-02-30"))
    expect_match(pricing_error(), "Date invalide")
    expect_equal(rv_pricing_edit(), reference)
    session$setInputs(table_pricing_edit_cell_edit = list(row = 1, col = 0, value = reference$Identifiant[2]))
    expect_match(pricing_error(), "uniques")
    expect_equal(rv_pricing_edit(), reference)
    rv_pricing_edit(reference[1, , drop = FALSE])
    session$setInputs(table_pricing_edit_rows_selected = 1, delete_row = 1)
    expect_match(pricing_error(), "au moins un")
    expect_equal(nrow(rv_pricing_edit()), 1)
    expect_equal(pricing_data(), reference)
  }))
})

test_that("deux sessions simultanées ont des catalogues indépendants", {
  withr::with_dir("../..", {
    # testServer ne peut pas être imbriqué : garder deux domaines réactifs vivants.
    start_session <- function() {
      session <- shiny::MockShinySession$new()
      state <- new.env(parent = environment(saga_server))
      state$input <- session$input
      state$output <- session$output
      state$session <- session
      shiny::withReactiveDomain(session, eval(body(saga_server), envir = state))
      session$flushReact()
      list(session = session, state = state)
    }
    first <- start_session(); second <- start_session()
    on.exit(first$session$close(), add = TRUE)
    on.exit(second$session$close(), add = TRUE)
    reference_hash <- tools::md5sum("data/pricing_models.csv")
    reference <- shiny::isolate(first$state$pricing_data())
    first$session$setInputs(table_pricing_edit_cell_edit = list(row = 1, col = 2, value = "123.45"))
    first$session$setInputs(apply_pricing = 1)
    expect_equal(shiny::isolate(first$state$pricing_data())$p_in_1M[1], 123.45)
    expect_equal(shiny::isolate(second$state$pricing_data()), reference)
    expect_equal(shiny::isolate(second$state$rv_pricing_edit()), reference)
    second$session$setInputs(table_pricing_edit_cell_edit = list(row = 1, col = 2, value = "678.9"))
    second$session$setInputs(apply_pricing = 1)
    expect_equal(shiny::isolate(second$state$pricing_data())$p_in_1M[1], 678.9)
    expect_equal(shiny::isolate(first$state$pricing_data())$p_in_1M[1], 123.45)
    second$session$setInputs(reset_pricing = 1)
    expect_equal(shiny::isolate(second$state$pricing_data()), reference)
    expect_equal(shiny::isolate(first$state$rv_pricing_edit())$p_in_1M[1], 123.45)
    shiny::testServer(saga_server, {
      expect_equal(pricing_data(), validate_api_pricing(read_api_pricing()))
    })
    expect_identical(tools::md5sum("data/pricing_models.csv"), reference_hash)
  })
})
