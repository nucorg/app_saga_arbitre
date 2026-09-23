source("../../R/logic_maths.R")
test_that("compute_cost fonctionne correctement", {
  # C_task = (C_tokens + C_infra + C_revue) / P_s
  # (0.05 + 0.5 + 0) / 0.9 = 0.55 / 0.9 = 0.6111111
  expect_equal(compute_cost(0.05, 0.5, 0, 0.9), 0.6111111, tolerance = 1e-4)
  
  # Si P_s = 0, retourne Inf
  expect_equal(compute_cost(0.05, 0.5, 0, 0), Inf)
})

test_that("compute_roi retourne le dataframe attendu", {
  df <- compute_roi(cost_manual = 10, cost_agent = 1, volume_mensuel = 100, build_initial = 5000)
  
  # Mois 1 Manuel : 100 * 10 = 1000
  expect_equal(df$Cout_Cumule[df$Mois == 1 & df$Type == "Manuel"], 1000)
  
  # Mois 1 Agent : 5000 + (100 * 1) = 5100
  expect_equal(df$Cout_Cumule[df$Mois == 1 & df$Type == "Agent IA"], 5100)
  
  # Au mois 12
  expect_equal(df$Cout_Cumule[df$Mois == 12 & df$Type == "Manuel"], 12000)
  expect_equal(df$Cout_Cumule[df$Mois == 12 & df$Type == "Agent IA"], 6200)
})
