#' Parse le fichier de facturation Markdown (cout_carbone_et_computation_YYYY-MM-DD.md)
parse_billing_md <- function(path) {
  if (!file.exists(path)) return(NULL)
  lines <- readLines(path, warn = FALSE)
  
  # Trouver la table markdown (ligne avec |:---| ou similaire)
  sep_idx <- grep("\\|\\s*:?-+:?\\s*\\|", lines)
  if (length(sep_idx) == 0) return(NULL)
  
  # On extrait juste la premiere table trouvée
  start_idx <- sep_idx[1] + 1
  end_idx <- start_idx
  while (end_idx <= length(lines) && grepl("\\|", lines[end_idx])) {
    end_idx <- end_idx + 1
  }
  end_idx <- end_idx - 1
  
  data_lines <- lines[start_idx:end_idx]
  if (length(data_lines) == 0) return(NULL)
  
  # Parser les lignes
  parsed <- lapply(data_lines, function(x) {
    # Nettoyer et spliter
    parts <- stringr::str_split_1(x, "\\|")
    # Retirer les elements vides aux extremités (dûs aux | de debut/fin)
    parts <- trimws(parts)[-c(1, length(parts))]
    parts
  })
  
  # Construction d'un DataFrame simple
  df <- as.data.frame(do.call(rbind, parsed), stringsAsFactors = FALSE)
  
  if (ncol(df) == 8) {
    colnames(df) <- c("Rôle (Task)", "PID", "Modèle", "Reqs", "Prompt (In)", "Cache (In)", "Output", "Thinking")
  }
  
  # Nettoyage et conversion des chiffres (ex: 1 637 613)
  for (i in seq_along(df)) {
    df[[i]] <- gsub("\\*\\*", "", df[[i]])
    clean_col <- gsub(" ", "", df[[i]])
    # Remplacer les virgules par des points pour as.numeric
    clean_col <- gsub(",", ".", clean_col)
    
    if (all(grepl("^-?[0-9.]+$", clean_col))) {
      df[[i]] <- as.numeric(clean_col)
    }
  }
  
  df
}

#' Parse le fichier de conformité Markdown (YYYY-MM-DD_squad_X.md)
parse_compliance_md <- function(path) {
  if (!file.exists(path)) return(list(volume = 0, success_rate = 0))
  content <- paste(readLines(path, warn = FALSE), collapse = "\n")
  
  # Total de Livrables jugés : 15
  vol_match <- stringr::str_extract(content, "(?i)total de livrables jugés\\s*:\\s*(\\d+)")
  vol <- if (!is.na(vol_match)) as.numeric(stringr::str_match(vol_match, "(?i)total de livrables jugés\\s*:\\s*(\\d+)")[2]) else 0
  
  # Fiabilité Composée (Ps)  : 95 %
  ps_match <- stringr::str_extract(content, "(?i)fiabilité composée\\s*\\(ps\\)\\s*:\\s*(\\d+)\\s*%")
  ps <- if (!is.na(ps_match)) as.numeric(stringr::str_match(ps_match, "(?i)fiabilité composée\\s*\\(ps\\)\\s*:\\s*(\\d+)\\s*%")[2]) else 0
  
  list(volume = vol, success_rate = ps)
}
