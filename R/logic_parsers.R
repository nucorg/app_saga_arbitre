# Lecture et sauvegarde du catalogue tarifaire partagé par C1 et Prix API.
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

save_api_pricing <- function(df, path = "data/pricing_models.csv") {
  # Reconvertir Date en texte pour le CSV de manière propre
  if ("date_verification" %in% names(df) && inherits(df$date_verification, "Date")) {
    df$date_verification <- as.character(df$date_verification)
  }
  write.csv(df, path, row.names = FALSE, quote = FALSE, na = "")
}
