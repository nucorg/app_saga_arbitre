source("../../R/logic_parsers.R")
test_that("parse_billing_md extrait et nettoie les nombres", {
  tmp <- tempfile(fileext = ".md")
  writeLines(c(
    "# Facturation",
    "",
    "| Concept | Tokens | Cout |",
    "| :--- | :--- | :--- |",
    "| Inférence | 1 637 613 | 12.5 |",
    "| Cache | 450 | 0,05 |"
  ), tmp)
  
  df <- parse_billing_md(tmp)
  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 2)
  expect_equal(df[[2]], c(1637613, 450)) # Les espaces sont retirés
  expect_equal(df[[3]], c(12.5, 0.05)) # Les virgules sont converties en points
  
  unlink(tmp)
})

test_that("parse_compliance_md extrait le volume et le succes", {
  tmp <- tempfile(fileext = ".md")
  writeLines(c(
    "Voici le rapport de conformité du squad.",
    "Total de Livrables jugés : 42",
    "Quelques erreurs mineures.",
    "Fiabilité Composée (Ps)  : 95 %"
  ), tmp)
  
  res <- parse_compliance_md(tmp)
  expect_equal(res$volume, 42)
  expect_equal(res$success_rate, 95)
  
  unlink(tmp)
})

test_that("parse_billing_md map les noms de 8 colonnes et nettoie les asteristiques", {
  tmp <- tempfile(fileext = ".md")
  writeLines(c(
    "| Rôle | PID | Modèle | Reqs | Prompt | Cache | Output | Thinking |",
    "| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |",
    "| chef | 1000 | gemini-3.1-pro | 10 | **5 000** | 1000 | **200** | 0 |",
    "| TOTAL SQUAD | - | - | 10 | 5000 | 1000 | 200 | 0 |"
  ), tmp)
  
  df <- parse_billing_md(tmp)
  expect_equal(ncol(df), 8)
  # Check renaming
  expect_equal(names(df)[1], "Rôle (Task)")
  expect_equal(names(df)[2], "PID")
  expect_equal(names(df)[5], "Prompt (In)")
  
  # Check asterisks removal & numeric conversion
  expect_equal(df[["Prompt (In)"]][1], 5000)
  expect_equal(df[["Output"]][1], 200)
  
  unlink(tmp)
})

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
