source("../../R/logic_parsers.R")
test_that("read_api_pricing et save_api_pricing fonctionnent correctement", {
  tmp <- tempfile(fileext = ".csv")
  df <- data.frame(
    Identifiant = c("Modele A", "Modele B"),
    Fournisseur = c("F1", "F2"),
    p_in_1M = c(1.0, 2.5),
    stringsAsFactors = FALSE
  )
  
  save_api_pricing(df, tmp)
  
  df_read <- read_api_pricing(tmp)
  
  expect_equal(df_read$Identifiant, df$Identifiant)
  expect_equal(df_read$p_in_1M, df$p_in_1M)
  
  # Return vide si n'existe pas
  df_empty <- read_api_pricing("fichier_inexistant_xyz.csv")
  expect_equal(nrow(df_empty), 0)
  
  unlink(tmp)
})

test_that("read_api_pricing supprime statut/source et formatte date_verification", {
  tmp <- tempfile(fileext = ".csv")
  df <- data.frame(
    Identifiant = c("Modele A"),
    statut = c("actif"),
    source = c("web"),
    date_verification = c(""),
    stringsAsFactors = FALSE
  )
  
  write.csv(df, tmp, row.names = FALSE)
  
  df_read <- read_api_pricing(tmp)
  
  expect_false("statut" %in% names(df_read))
  expect_false("source" %in% names(df_read))
  expect_true("date_verification" %in% names(df_read))
  expect_s3_class(df_read$date_verification, "Date")
  expect_equal(as.character(df_read$date_verification[1]), "2026-09-27")
  
  unlink(tmp)
})
