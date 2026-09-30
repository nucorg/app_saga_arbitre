source("../../R/logic_parsers.R")

pricing_fixture <- function() {
  data.frame(Identifiant = c('Modèle, "éco"', "Modèle B"), Fournisseur = c("Équipe A", ""),
    p_in_1M = c(0, 2.5), p_out_1M = c(3, 5), p_cache_1M = c(NA_real_, 0),
    date_verification = as.Date(c("2026-09-27", NA)))
}

test_that("l'export et l'import préservent accents, virgules, guillemets et valeurs absentes", {
  path <- tempfile(fileext = ".csv"); on.exit(unlink(path))
  df <- pricing_fixture()
  export_api_pricing(df, path)
  expect_equal(import_api_pricing(path), df)
})

test_that("l'import accepte UTF-8 BOM, point-virgule et virgule décimale", {
  path <- tempfile(fileext = ".csv"); on.exit(unlink(path))
  writeLines(c("\ufeffIdentifiant;p_in_1M;p_out_1M", "Éco;0,25;1,5"), path, useBytes = TRUE)
  df <- import_api_pricing(path)
  expect_equal(df$Identifiant, "Éco")
  expect_equal(df$p_in_1M, 0.25)
  expect_equal(df$p_out_1M, 1.5)
  expect_equal(df$Fournisseur, "")
  expect_true(is.na(df$p_cache_1M))
  expect_true(is.na(df$date_verification))
})

test_that("un CSV valide sans saut de ligne final reste lisible", {
  path <- tempfile(fileext = ".csv"); on.exit(unlink(path))
  writeChar("Identifiant,p_in_1M,p_out_1M\nA,1,2", path, eos = NULL)
  expect_equal(import_api_pricing(path)$p_in_1M, 1)
})

test_that("les identifiants vides ou ambigus et les schémas invalides sont refusés", {
  df <- pricing_fixture()
  expect_error(validate_api_pricing(df[FALSE, ]), "au moins un")
  expect_error(validate_api_pricing(df[, -3]), "Colonnes requises")
  bad <- df; names(bad)[2] <- "Identifiant"
  expect_error(validate_api_pricing(bad), "sans doublon")
  bad <- df; bad$extra <- 1
  expect_error(validate_api_pricing(bad), "Colonnes inconnues")
  for (id in c("", "  ", NA_character_)) {
    bad <- df; bad$Identifiant[1] <- id
    expect_error(validate_api_pricing(bad), "non vide")
  }
  bad <- df; bad$Identifiant <- c("Modèle A", " modèle a ")
  expect_error(validate_api_pricing(bad), "uniques")
})

test_that("les prix sont finis et non négatifs, seuls les prix cache peuvent manquer", {
  for (column in c("p_in_1M", "p_out_1M", "p_cache_1M")) {
    for (value in c("-1", "abc", "Inf", "NaN")) {
      df <- pricing_fixture(); df[[column]][1] <- value
      expect_error(validate_api_pricing(df), "prix numérique")
    }
  }
  for (column in c("p_in_1M", "p_out_1M")) {
    df <- pricing_fixture(); df[[column]][1] <- NA
    expect_error(validate_api_pricing(df), "prix numérique")
  }
  expect_equal(validate_api_pricing(pricing_fixture())$p_in_1M[1], 0)
})

test_that("les dates impossibles ou au mauvais format sont refusées", {
  for (date in c("2026-02-30", "2026-13-01", "27/09/2026", "2026-09-27oops")) {
    df <- pricing_fixture(); df$date_verification <- c(date, "")
    expect_error(validate_api_pricing(df), "Date invalide")
  }
})

test_that("un fichier malformé ne peut pas produire un catalogue silencieusement tronqué", {
  path <- tempfile(fileext = ".csv"); on.exit(unlink(path))
  for (lines in list(character(), c("Identifiant,p_in_1M,p_out_1M"),
                     c("Identifiant,p_in_1M,p_out_1M", "A,1,2,3"),
                     c("Identifiant,p_in_1M,p_out_1M", "A,1"),
                     c("Identifiant,p_in_1M,p_out_1M", 'A,1,"2'))) {
    writeLines(lines, path)
    expect_error(import_api_pricing(path))
  }
})

test_that("la lecture de la référence conserve la compatibilité historique", {
  path <- tempfile(fileext = ".csv"); on.exit(unlink(path))
  df <- data.frame(Identifiant = "A", statut = "actif", source = "web", date_verification = "")
  write.csv(df, path, row.names = FALSE)
  read <- read_api_pricing(path)
  expect_false("statut" %in% names(read))
  expect_false("source" %in% names(read))
  expect_s3_class(read$date_verification, "Date")
  expect_equal(as.character(read$date_verification), "2026-09-27")
  expect_equal(nrow(read_api_pricing(file.path(tempdir(), "missing-pricing.csv"))), 0)
})
