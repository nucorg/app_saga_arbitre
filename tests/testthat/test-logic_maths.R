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

test_that("compute_c1_usd et compute_c1_eur calculent l'inférence correctement", {
  # Pour GPT-5 Mini (0.25 IN, 2.00 OUT) avec 8000 IN, 1500 OUT
  # usd = (0.25 * 8000 + 2.00 * 1500) / 1 000 000 = (2000 + 3000) / 1000000 = 0.005
  usd <- compute_c1_usd(p_in_1M = 0.25, p_out_1M = 2.00, n_in = 8000, n_out = 1500)
  expect_equal(usd, 0.005)
  
  # Conversion avec un taux imaginaire de 0.88
  eur <- compute_c1_eur(usd, 0.88)
  expect_equal(eur, 0.005 * 0.88)
})

test_that("compute_equivalent_tokens applique bien l'abattement du cache contextuel", {
  # 100 prompt_in, 100 cache_in -> equiv = 100 + 25 = 125
  # 50 output, 10 thinking -> equiv = 60
  res <- compute_equivalent_tokens(prompt_in = 100, cache_in = 100, output = 50, thinking = 10)
  expect_equal(res$equiv_in, 125)
  expect_equal(res$equiv_out, 60)
})

test_that("compute_equivalent_tokens_unit divise correctement par le volume", {
  res_unit <- compute_equivalent_tokens_unit(equiv_in = 1000, equiv_out = 500, volume = 50)
  expect_equal(res_unit$equiv_in_unit, 20)
  expect_equal(res_unit$equiv_out_unit, 10)
  
  # Securite volume = 0
  res_zero <- compute_equivalent_tokens_unit(equiv_in = 1000, equiv_out = 500, volume = 0)
  expect_equal(res_zero$equiv_in_unit, 1000)
})

test_that("compute_c2_maths dissocie correctement Fixe et Variable selon la Taxonomie", {
  # Test classique: Base 100$ fixe + 0.1$ variable unitaire avec V=1000 tasks, Taux = 0.9 EUR
  # Attendu (EUR) : Fixe = 90, Var_Unit = 0.09, Var_Mensuel = 90. Total = 180 EUR
  res <- compute_c2_maths(total_fixe_usd = 100, total_var_unit_usd = 0.1, volume_v = 1000, usd_eur_rate = 0.9)
  
  expect_equal(res$fixe, 90)
  expect_equal(res$var_month, 90)
  expect_equal(res$total, 180)
  
  # Si volume = 0, C2 = Uniquement Fixe
  res_zero <- compute_c2_maths(total_fixe_usd = 100, total_var_unit_usd = 0.1, volume_v = 0, usd_eur_rate = 0.9)
  expect_equal(res_zero$total, 90)
})

test_that("compute_h2_cruise calcule correctement les heures d'escalade mensuelles", {
  # V = 2000 tâches, Taux rejet = 5%, Temps correction = 12 minutes
  # 2000 * 0.05 = 100 tâches. 100 * (12/60) = 20 heures
  h2 <- compute_h2_cruise(volume_mensuel = 2000, taux_escalade = 0.05, temps_reprise_minutes = 12)
  expect_equal(h2, 20)
  
  # Si le modèle est parfait (0% d'escalade)
  h2_parfait <- compute_h2_cruise(volume_mensuel = 2000, taux_escalade = 0, temps_reprise_minutes = 15)
  expect_equal(h2_parfait, 0)
  
  # Protection contre valeurs négatives
  h2_neg <- compute_h2_cruise(volume_mensuel = -10, taux_escalade = 0.05, temps_reprise_minutes = 12)
  expect_equal(h2_neg, 0)
})
