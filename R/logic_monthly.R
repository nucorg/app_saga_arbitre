# Comparaison d'un mois stabilisé, hors projection de calibrage.
monthly_input_names <- c("vol", "ps", "time_h", "cost_h", "cost_c1_month",
                         "cost_orch", "maint_h", "build_ia", "amort_months",
                         "build_manual", "projection_months")

read_monthly_example <- function(path = "data/scenarios/veille-section-1.json") {
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

compute_monthly_comparison <- function(inputs) {
  required <- inputs[monthly_input_names]
  valid_scalar <- vapply(required, function(x)
    is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x), logical(1))
  if (!all(valid_scalar)) stop("Renseignez tous les paramètres avec des nombres valides.")
  x <- unlist(required)
  if (any(x < 0) || x["vol"] <= 0 || x["ps"] > 100 ||
      x["amort_months"] <= 0 || x["amort_months"] != floor(x["amort_months"]) ||
      !x["projection_months"] %in% c(6, 12))
    stop("Vérifiez les paramètres : volume positif, acceptation entre 0 et 100 %, répartition entière positive, projection à 6 ou 12 mois.")
  accepted <- inputs$vol * inputs$ps / 100
  c1 <- inputs$cost_c1_month
  c2 <- inputs$cost_orch
  c3 <- inputs$maint_h * inputs$cost_h
  current <- c1 + c2 + c3
  allocation <- inputs$build_ia / inputs$amort_months
  manual_unit <- inputs$time_h / 60 * inputs$cost_h
  manual_current <- manual_unit * accepted
  manual_allocation <- inputs$build_manual / inputs$amort_months
  # Aucun résultat accepté : le budget reste connu, le ratio est indéfini.
  current_unit <- if (accepted > 0) compute_cost(
    c1 / inputs$vol, c2 / inputs$vol, c3 / inputs$vol, inputs$ps / 100
  ) else NA_real_
  list(accepted = accepted, c1_per_input = c1 / inputs$vol,
       c1 = c1, c2 = c2, c3 = c3, current = current, allocation = allocation,
       analytical = current + allocation,
       current_per_accepted = current_unit,
       analytical_per_accepted = if (accepted > 0) (current + allocation) / accepted else NA_real_,
       manual_current = manual_current, manual_allocation = manual_allocation,
       manual_analytical = manual_current + manual_allocation,
       manual_per_accepted = if (accepted > 0) manual_unit + manual_allocation / accepted else NA_real_)
}

compute_monthly_projection <- function(inputs, result = compute_monthly_comparison(inputs)) {
  if (result$accepted <= 0) stop("La projection comparative nécessite au moins un résultat accepté.")
  df <- compute_roi(inputs$time_h / 60 * inputs$cost_h,
                    result$current_per_accepted, result$accepted,
                    inputs$build_ia, inputs$build_manual)
  # Le mois zéro rend l'investissement initial visible ; le moteur reste inchangé.
  initial <- data.frame(Mois = c(0, 0),
                        Cout_Cumule = c(inputs$build_manual, inputs$build_ia),
                        Type = c("Manuel", "Agent IA"))
  rbind(initial, df[df$Mois <= inputs$projection_months, ])
}
