# Budget C2 mensuel : postes récurrents, hors C1, C3 et investissement.
infra_posts <- data.frame(
  id = c("c2_runtime", "c2_storage", "c2_observability", "c2_sources", "c2_security", "c2_tests"),
  label = c("Exécution et orchestration", "Stockage et mémoire technique", "Traces et observabilité",
            "Recherche, extraction et accès aux sources", "Contrôles d’accès et protection", "Exécution automatisée des tests"),
  help = c("Hébergement, planification, files d’attente, environnements de production et de test.",
           "Documents, index de recherche, états des traitements et sauvegardes.",
           "Outils de suivi des exécutions, conservation des traces et alertes.",
           "Recherche documentaire, extraction et abonnements aux sources. Hors appels aux modèles comptés en C1.",
           "Passerelles, gestion des secrets et protections logicielles.",
           "Infrastructure et outils exécutant les tests. Hors temps humain et appels aux modèles."),
  stringsAsFactors = FALSE
)
infra_input_names <- infra_posts$id
compute_infra_budget <- function(inputs) {
  missing <- function(x) is.null(x) || length(x)==0L ||
    (length(x)==1L && (is.na(x) || identical(x,"")))
  values <- lapply(infra_input_names, function(id) inputs[[id]])
  absent <- vapply(values, missing, logical(1))
  valid <- vapply(values, function(x) is.numeric(x) && length(x)==1L &&
    !is.na(x) && is.finite(x) && x>=0 && is.finite(x*100) &&
    abs(x*100-round(x*100))<1e-6, logical(1))
  invalid <- !absent & !valid
  complete <- all(valid)
  amounts <- vapply(seq_along(values), function(i) if(valid[i]) round(values[[i]]*100)/100 else NA_real_, numeric(1))
  total <- if(complete) sum(round(amounts*100))/100 else NA_real_
  error <- if(any(invalid)) paste0("Montant invalide : ",paste(infra_posts$label[invalid],collapse=", "),
    ". Saisissez un nombre positif ou nul, avec au plus deux décimales.") else ""
  if(complete && !is.finite(total)) { complete <- FALSE; total <- NA_real_; error <- "Le total dépasse la capacité de calcul." }
  list(complete=complete, count=sum(valid), total=total, error=error,
       rows=data.frame(Poste=infra_posts$label, Montant=amounts, stringsAsFactors=FALSE))
}
read_infra_example <- function(path="data/scenarios/veille-c2.json") {
  example <- jsonlite::fromJSON(path,simplifyVector=FALSE)
  result <- compute_infra_budget(example$inputs)
  if(!result$complete || result$total != example$expected$total)
    stop("L’exemple C2 est incomplet ou incohérent.")
  example
}
