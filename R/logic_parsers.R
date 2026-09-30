# Lecture du catalogue de référence ; les tarifs personnels restent en session.
read_api_pricing <- function(path = "data/pricing_models.csv") {
  if (!file.exists(path)) return(data.frame())
  df <- read.csv(path, stringsAsFactors = FALSE)
  
  # Supprimer statut et source s'ils existent encore
  if ("statut" %in% names(df)) df$statut <- NULL
  if ("source" %in% names(df)) df$source <- NULL
  
  # Gestion de la date_verification
  if (!"date_verification" %in% names(df)) {
    df$date_verification <- "2026-09-27"
  } else {
    df$date_verification[is.na(df$date_verification) | df$date_verification == ""] <- "2026-09-27"
  }
  
  # Conversion en Date pour activer le calendrier interactif dans DT
  df$date_verification <- as.Date(df$date_verification)
  
  df
}

validate_api_pricing <- function(df) {
  required <- c("Identifiant", "p_in_1M", "p_out_1M")
  columns <- c("Identifiant", "Fournisseur", "p_in_1M", "p_out_1M",
               "p_cache_1M", "date_verification")
  if (!is.data.frame(df) || nrow(df) == 0L)
    stop("Conservez au moins un modèle dans le catalogue.", call. = FALSE)
  if (anyDuplicated(names(df)) || !all(required %in% names(df)))
    stop("Colonnes requises : Identifiant, p_in_1M et p_out_1M, sans doublon de colonne.", call. = FALSE)
  if (any(!names(df) %in% columns))
    stop("Colonnes inconnues : utilisez le format fourni par « Exporter mes tarifs ».", call. = FALSE)
  for (name in setdiff(columns, names(df))) df[[name]] <- NA_character_
  df <- df[, columns, drop = FALSE]
  df$Identifiant <- trimws(as.character(df$Identifiant))
  if (anyNA(df$Identifiant) || any(!nzchar(df$Identifiant)))
    stop("Chaque modèle doit avoir un identifiant non vide.", call. = FALSE)
  if (anyDuplicated(tolower(df$Identifiant)))
    stop("Les identifiants des modèles doivent être uniques (sans distinction de casse).", call. = FALSE)
  df$Fournisseur <- trimws(as.character(df$Fournisseur))
  df$Fournisseur[is.na(df$Fournisseur)] <- ""
  for (name in c("p_in_1M", "p_out_1M", "p_cache_1M")) {
    value <- trimws(as.character(df[[name]]))
    empty <- is.na(value) | value == ""
    parsed <- suppressWarnings(as.numeric(gsub(",", ".", value, fixed = TRUE)))
    optional <- name == "p_cache_1M"
    if (any((!empty & (!is.finite(parsed) | parsed < 0)) | (empty & !optional)))
      stop(paste0(name, " : saisissez un prix numérique fini et positif ou nul",
                  if (optional) " ; le tarif cache peut rester vide." else "."), call. = FALSE)
    parsed[empty] <- NA_real_
    df[[name]] <- parsed
  }
  value <- trimws(as.character(df$date_verification))
  empty <- is.na(value) | value == ""
  value[empty] <- NA_character_
  dates <- suppressWarnings(as.Date(value, format = "%Y-%m-%d"))
  if (any(!empty & (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", value) |
                    is.na(dates) | format(dates, "%Y-%m-%d") != value)))
    stop("Date invalide : utilisez AAAA-MM-JJ ou laissez la cellule vide.", call. = FALSE)
  df$date_verification <- dates
  rownames(df) <- NULL
  df
}

import_api_pricing <- function(path) {
  # Tout lire comme texte pour valider sans perdre les identifiants ni les erreurs.
  invalid_csv <- function(...) {
    stop("CSV illisible : utilisez un fichier UTF-8 avec un séparateur virgule ou point-virgule, des guillemets fermés et des lignes complètes.", call. = FALSE)
  }
  df <- tryCatch(withCallingHandlers({
    connection <- file(path, open = "rt", encoding = "UTF-8-BOM")
    on.exit(close(connection))
    lines <- readLines(connection, warn = FALSE)
    header <- read.table(text = lines, header = TRUE, sep = ",", nrows = 0,
                         check.names = FALSE)
    sep <- if (length(names(header)) == 1L && grepl(";", names(header), fixed = TRUE)) ";" else ","
    read.table(text = lines, header = TRUE, sep = sep, quote = "\"", comment.char = "",
               fill = FALSE, colClasses = "character", na.strings = "",
               check.names = FALSE)
  }, warning = invalid_csv), error = invalid_csv)
  validate_api_pricing(df)
}

export_api_pricing <- function(df, path) {
  # Seul le fichier temporaire du téléchargement est écrit, jamais la référence.
  df <- validate_api_pricing(df)
  df$date_verification <- as.character(df$date_verification)
  connection <- file(path, open = "wt", encoding = "UTF-8")
  on.exit(close(connection))
  write.csv(df, connection, row.names = FALSE, quote = TRUE, na = "")
}
