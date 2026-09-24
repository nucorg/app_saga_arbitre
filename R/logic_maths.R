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
compute_roi <- function(cost_manual, cost_agent, volume_mensuel, build_initial_ia = 1200, build_initial_manual = 3500) {
  months <- 1:12
  cost_manual_cum <- build_initial_manual + (cost_manual * volume_mensuel * months)
  cost_agent_cum <- build_initial_ia + (cost_agent * volume_mensuel * months)
  
  data.frame(
    Mois = rep(months, 2),
    Cout_Cumule = c(cost_manual_cum, cost_agent_cum),
    Type = rep(c("Manuel", "Agent IA"), each = 12)
  )
}

#' Calcul des totaux par couche du CTP sur l'horizon donné
#' @return list(C1, C2, C3, CTP)
compute_ctp_totals <- function(c, v, t_horizon, c_orch, kappa, w, h1, h2) {
  c1_total <- c * v * t_horizon
  c2_total <- c_orch * kappa * t_horizon
  
  months_calib <- min(t_horizon, 3)
  months_crois <- max(0, t_horizon - 3)
  c3_total <- w * ((h1 * months_calib) + (h2 * months_crois))
  
  ctp <- c1_total + c2_total + c3_total
  list(C1 = c1_total, C2 = c2_total, C3 = c3_total, CTP = ctp)
}

#' Calcul mensuel du CTP pour tracer la courbe (Le "Genou")
#' @return data.frame(Mois, C1, C2, C3, Total)
compute_ctp_monthly <- function(c, v, t_horizon, c_orch, kappa, w, h1, h2) {
  if(t_horizon < 1) return(data.frame())
  months <- 1:t_horizon
  
  monthly_c1 <- rep(c * v, t_horizon)
  monthly_c2 <- rep(c_orch * kappa, t_horizon)
  
  monthly_h <- ifelse(months <= 3, h1, h2)
  monthly_c3 <- w * monthly_h
  
  monthly_total <- monthly_c1 + monthly_c2 + monthly_c3
  
  data.frame(
    Mois = months,
    C1 = monthly_c1,
    C2 = monthly_c2,
    C3 = monthly_c3,
    Total = monthly_total
  )
}
