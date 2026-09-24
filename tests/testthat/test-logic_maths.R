source("../../R/logic_maths.R")
test_that("compute_cost fonctionne correctement", {
  # C_task = (C_tokens + C_infra + C_revue) / P_s
  # (0.05 + 0.5 + 0) / 0.9 = 0.55 / 0.9 = 0.6111111
  expect_equal(compute_cost(0.05, 0.5, 0, 0.9), 0.6111111, tolerance = 1e-4)
  
  # Si P_s = 0, retourne Inf
  expect_equal(compute_cost(0.05, 0.5, 0, 0), Inf)
})

test_that("compute_roi retourne le dataframe attendu", {
  df <- compute_roi(cost_manual = 10, cost_agent = 1, volume_mensuel = 100, build_initial_ia = 5000, build_initial_manual = 3500)
  
  # Mois 1 Manuel : 3500 + 100 * 10 = 4500
  expect_equal(df$Cout_Cumule[df$Mois == 1 & df$Type == "Manuel"], 4500)
  
  # Mois 1 Agent : 5000 + (100 * 1) = 5100
  expect_equal(df$Cout_Cumule[df$Mois == 1 & df$Type == "Agent IA"], 5100)
  
  # Au mois 12 Manuel : 3500 + (10*100*12) = 15500
  expect_equal(df$Cout_Cumule[df$Mois == 12 & df$Type == "Manuel"], 15500)
  expect_equal(df$Cout_Cumule[df$Mois == 12 & df$Type == "Agent IA"], 6200)
})

test_that("compute_ctp_totals correspond a l'exemple theorique M2", {
  # Paramètres de l'exemple M2 : c = 0.0775, V = 2167, T = 6, C_orch = 200, kappa = 1, w = 55, h1 = 12, h2 = 6
  res <- compute_ctp_totals(c = 0.0775, v = 2167, t_horizon = 6, c_orch = 200, kappa = 1, w = 55, h1 = 12, h2 = 6)
  
  # Validation selon l'Etape 3 : C1 = 1008, C2 = 1200, C3 = 2970, CTP = 5178
  # Avec les arrondis, 0.0775 * 2167 * 6 = 1007.655 (~1008)
  expect_equal(res$C1, 1007.655, tolerance = 1e-4)
  expect_equal(res$C2, 1200)
  expect_equal(res$C3, 2970)
  expect_equal(res$CTP, 1007.655 + 1200 + 2970, tolerance = 1e-4)
})

test_that("compute_ctp_monthly produit le bon dataframe et le Genou du mois 3", {
  df <- compute_ctp_monthly(c = 0.0775, v = 2167, t_horizon = 6, c_orch = 200, kappa = 1, w = 55, h1 = 12, h2 = 6)
  
  expect_equal(nrow(df), 6)
  # Mois 3 (Calibrage) : C1(167.9) + C2(200) + C3(12*55=660) = ~1028
  expect_equal(df$C3[3], 660)
  
  # Mois 4 (Croisière) : C1(167.9) + C2(200) + C3(6*55=330) = ~698
  expect_equal(df$C3[4], 330)
  expect_true(df$Total[3] > df$Total[4])
})
