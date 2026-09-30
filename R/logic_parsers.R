# Lecture des journaux historiques, sans transformer une absence en zéro.
parse_billing_md <- function(path) {
  if (!file.exists(path)) return(NULL)
  lines <- readLines(path, warn = FALSE)
  sep <- grep("\\|\\s*:?-+:?\\s*\\|", lines, perl = TRUE)
  if (!length(sep)) return(NULL)
  i <- sep[1] + 1L
  rows <- list()
  while (i <= length(lines) && grepl("|", lines[i], fixed = TRUE)) {
    line <- sub("^\\s*\\|", "", lines[i], perl = TRUE)
    line <- sub("\\|\\s*$", "", line, perl = TRUE)
    rows[[length(rows) + 1L]] <- trimws(strsplit(line, "|", fixed = TRUE)[[1]])
    i <- i + 1L
  }
  if (!length(rows) || length(unique(lengths(rows))) != 1) return(NULL)
  df <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  if (ncol(df) == 8) names(df) <- c("Rôle (Task)", "PID", "Modèle", "Reqs", "Prompt (In)", "Cache (In)", "Output", "Thinking")
  for (j in seq_along(df)) {
    df[[j]] <- gsub("**", "", df[[j]], fixed = TRUE)
    clean <- gsub(",", ".", gsub("[[:space:]\u00a0\u202f]", "", df[[j]]), fixed = TRUE)
    if (all(grepl("^-?[0-9]+([.][0-9]+)?$", clean))) df[[j]] <- as.numeric(clean)
  }
  df
}

parse_compliance_md <- function(path) {
  missing <- list(volume = NA_real_, success_rate = NA_real_, accepted = NA_real_, basis = "missing")
  if (!file.exists(path)) return(missing)
  content <- gsub("**", "", paste(readLines(path, warn = FALSE), collapse = "\n"), fixed = TRUE)
  get_number <- function(pattern) {
    m <- regmatches(content, regexec(pattern, content, perl = TRUE, ignore.case = TRUE))[[1]]
    if (length(m) < 2) NA_real_ else as.numeric(gsub(",", ".", m[2], fixed = TRUE))
  }
  vol <- get_number("total de livrables jugés\\s*:\\s*([0-9]+)")
  ps <- get_number("fiabilité composée\\s*\\(ps\\)\\s*:\\s*([0-9]+(?:[.,][0-9]+)?)\\s*%")
  accepted <- get_number("résultats acceptés\\s*:\\s*([0-9]+)")
  basis <- "counts"
  if (is.na(accepted)) { accepted <- vol * ps / 100; basis <- "legacy_rate_estimate" }
  if (!is.na(accepted) && !is.na(vol) && vol > 0 && basis == "counts") ps <- 100 * accepted / vol
  if ((!is.na(ps) && (ps < 0 || ps > 100)) || (!is.na(accepted) && !is.na(vol) && accepted > vol)) return(missing)
  list(volume = vol, success_rate = ps, accepted = accepted, basis = basis)
}

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
