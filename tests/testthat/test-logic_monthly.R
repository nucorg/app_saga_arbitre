source("../../R/logic_maths.R")
source("../../R/logic_monthly.R")
source("../../R/logic_parsers.R")
source("../../R/server.R")
for (pkg in c("shiny", "bslib", "ggplot2", "dplyr", "DT", "plotly"))
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
example <- read_monthly_example("../../data/scenarios/veille-section-1.json")

test_that("le scénario versionné reproduit la lecture mensuelle du cours", {
  r <- compute_monthly_comparison(example$inputs)
  for (name in names(example$expected)) expect_equal(r[[name]], example$expected[[name]], info = name)
})
test_that("volume et acceptation changent les ratios, pas les budgets saisis", {
  x <- example$inputs; x$vol <- 600
  r <- compute_monthly_comparison(x)
  expect_equal(r$current, 15000); expect_equal(r$c1_per_input, 1)
  expect_equal(r$current_per_accepted, 25); expect_equal(r$manual_current, 18000)
  x <- example$inputs; x$ps <- 80
  r <- compute_monthly_comparison(x)
  expect_equal(r$accepted, 960); expect_equal(r$current, 15000)
  expect_equal(r$current_per_accepted, 15.625) # contrôle saga-maths
  expect_equal(r$manual_current, 28800)
  expect_equal(r$manual_per_accepted, 30)
})
test_that("charge humaine, investissement et répartition sont indépendants", {
  x <- example$inputs; x$maint_h <- 300
  expect_equal(compute_monthly_comparison(x)$c3, 18000)
  x <- example$inputs; x$amort_months <- 12
  expect_equal(compute_monthly_comparison(x)$analytical, 18000)
  expect_equal(compute_monthly_projection(x), compute_monthly_projection(example$inputs))
  x$build_ia <- 0
  expect_equal(compute_monthly_comparison(x)$analytical, 15000)
  x$build_manual <- 12000
  expect_equal(compute_monthly_comparison(x)$manual_analytical, 37000)
})
test_that("projection compte une seule fois l'investissement, à six ou douze mois", {
  x <- example$inputs; r <- compute_monthly_projection(x)
  expect_equal(max(r$Mois), 6)
  expect_equal(subset(r, Mois == 0 & Type == "Agent IA")$Cout_Cumule, 36000)
  expect_equal(subset(r, Mois == 6 & Type == "Agent IA")$Cout_Cumule, 126000)
  expect_equal(subset(r, Mois == 6 & Type == "Manuel")$Cout_Cumule, 216000)
  x$projection_months <- 12; r <- compute_monthly_projection(x)
  expect_equal(subset(r, Mois == 12 & Type == "Agent IA")$Cout_Cumule, 216000) # saga-maths
  expect_equal(subset(r, Mois == 12 & Type == "Manuel")$Cout_Cumule, 432000)
})
test_that("zéro acceptation et paramètres invalides ne donnent pas de faux ratios", {
  x <- example$inputs; x$ps <- 0
  r <- compute_monthly_comparison(x)
  expect_equal(r$current, 15000); expect_true(is.na(r$current_per_accepted))
  expect_true(is.na(r$analytical_per_accepted))
  expect_error(compute_monthly_projection(x), "résultat accepté")
  for (bad in list(list(vol=0), list(ps=101), list(maint_h=-1), list(amort_months=0),
                  list(amort_months=1.5), list(cost_c1_month=NA_real_), list(cost_h=Inf),
                  list(time_h="30"), list(projection_months=24))) {
    x <- modifyList(example$inputs, bad)
    expect_error(compute_monthly_comparison(x))
  }
  x <- example$inputs; x$vol <- NULL
  expect_error(compute_monthly_comparison(x), "Renseignez")
})
test_that("Shiny conserve les hypothèses et la simulation courante après ajout", {
  withr::with_dir("../..", shiny::testServer(saga_server, {
    x <- read_monthly_example()$inputs
    do.call(session$setInputs, x)
    expect_equal(monthly_result()$analytical, 16500)
    expect_match(as.character(output$monthly_summary$html), "16\u202f500")
    expect_match(as.character(output$monthly_summary$html), "13,75")
    expect_equal(monthly_projection()$Mois[3], 1)
    session$setInputs(add_scen = 1)
    expect_length(scenarios_rv$data, 1)
    expect_equal(scenarios_rv$data[[1]]$inputs, x)
    session$setInputs(maint_h = 300)
    expect_equal(monthly_result()$analytical, 22500)
    expect_equal(scenarios_rv$data[[1]]$result$analytical, 16500)
    df <- comparison_data()
    expect_equal(nrow(df), 6)
    expect_true("Simulation courante" %in% df$Scenario)
    expect_equal(subset(df, Scenario == "Scénario 1" & Type == "Manuel analytique")$Cout, 30)
    session$setInputs(cost_h = 80)
    expect_equal(subset(comparison_data(), Scenario == "Scénario 1" & Type == "Manuel analytique")$Cout, 30)
    session$setInputs(ps = 0, add_scen = 2)
    expect_length(scenarios_rv$data, 1)
    expect_true(is.na(monthly_result()$current_per_accepted))
    session$setInputs(vol = 0)
    expect_error(monthly_result(), "Vérifiez")
  }))
})
