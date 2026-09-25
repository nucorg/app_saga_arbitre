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

#' Calcul du coût de l'inférence C1 (en USD)
#' @param p_in_1M Prix pour 1M jetons en entrée (USD)
#' @param p_out_1M Prix pour 1M jetons en sortie (USD)
#' @param n_in Nombre de jetons en entrée
#' @param n_out Nombre de jetons en sortie
compute_c1_usd <- function(p_in_1M, p_out_1M, n_in, n_out) {
  (p_in_1M * n_in + p_out_1M * n_out) / 1000000
}

#' Conversion du coût USD vers EUR
compute_c1_eur <- function(cost_usd, usd_eur_rate) {
  cost_usd * usd_eur_rate
}

#' Calcul des jetons équivalents en tenant compte du cache (réduction de 75% sur le prix du cache)
#' @return list(equiv_in, equiv_out)
compute_equivalent_tokens <- function(prompt_in, cache_in, output, thinking, cache_discount = 0.25) {
  # Les jetons provenant du cache coûtent 25% du prix standard (soit une décote de 75%)
  equiv_in <- prompt_in + (cache_in * cache_discount)
  equiv_out <- output + thinking
  list(equiv_in = equiv_in, equiv_out = equiv_out)
}

#' Mise à l'échelle unitaire (par rapport au volume)
compute_equivalent_tokens_unit <- function(equiv_in, equiv_out, volume) {
  if (is.na(volume) || volume <= 0) {
    return(list(equiv_in_unit = equiv_in, equiv_out_unit = equiv_out))
  }
  list(equiv_in_unit = equiv_in / volume, equiv_out_unit = equiv_out / volume)
}

#' Calcul des composantes C2 Base Fixe et Variables
#' @param total_fixe_usd Somme des coûts mensuels fixes (USD)
#' @param total_var_unit_usd Somme unitaire des coûts variables (USD)
#' @param volume_v Volume mensuel (V)
#' @param usd_eur_rate Taux de conversion
#' @return list(fixe_eur, var_month_eur, total_eur)
compute_c2_maths <- function(total_fixe_usd, total_var_unit_usd, volume_v, usd_eur_rate) {
  # Base mensuelle fixe convertie
  fixe_eur <- total_fixe_usd * usd_eur_rate
  
  # Le coût variable s'applique par tâche (volume V) 
  var_unit_eur <- total_var_unit_usd * usd_eur_rate
  var_month_eur <- var_unit_eur * volume_v
  
  list(
    fixe = fixe_eur,
    var_month = var_month_eur,
    total = fixe_eur + var_month_eur
  )
}

#' Calcul du temps de maintenance en phase de Croisière (h2)
#' Basé sur la formule de la Taxonomie C3 :
#' h2 = Volume * Taux_Escalade * Temps_Reprise
#' @param volume_mensuel Volume de tâches mensuelles (V)
#' @param taux_escalade Taux de tâches nécessitant une reprise humaine (entre 0 et 1)
#' @param temps_reprise_minutes Temps moyen pour traiter manuellement une tâche échouée (en minutes)
#' @return Nombre d'heures mensuelles en phase de croisière (h2)
compute_h2_cruise <- function(volume_mensuel, taux_escalade, temps_reprise_minutes) {
  if (volume_mensuel < 0 || taux_escalade < 0 || temps_reprise_minutes < 0) return(0)
  
  (volume_mensuel * taux_escalade) * (temps_reprise_minutes / 60)
}
