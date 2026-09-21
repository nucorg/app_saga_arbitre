#' Calcul du Coût Complet par Tâche (C_task)
#' Formule : (Sum(C_tokens) + C_infra + C_revue_humaine) / P_s
compute_cost <- function(c_tokens, c_infra, c_revue_humaine, p_s) {
  if (p_s == 0) return(Inf)
  (c_tokens + c_infra + c_revue_humaine) / p_s
}

#' Calcul de la Fiabilité Composée
#' Formule : p^N
compute_composed_reliability <- function(p, n) {
  p^n
}

#' Calcul du ROI et Point Mort sur 12 mois
#' Retourne un dataframe pour ggplot
compute_roi <- function(cost_manual, cost_agent, volume_mensuel, build_initial = 5000) {
  months <- 1:12
  cost_manual_cum <- cost_manual * volume_mensuel * months
  cost_agent_cum <- build_initial + (cost_agent * volume_mensuel * months)
  
  data.frame(
    Mois = rep(months, 2),
    Cout_Cumule = c(cost_manual_cum, cost_agent_cum),
    Type = rep(c("Manuel", "Agent IA"), each = 12)
  )
}
