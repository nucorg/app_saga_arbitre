source("../../R/logic_maths.R")
source("../../R/logic_ctp.R")
source("../../R/logic_monthly.R")
source("../../R/logic_parsers.R")
source("../../R/server.R")
for(pkg in c("shiny","bslib","ggplot2","dplyr","DT","plotly"))
  suppressPackageStartupMessages(library(pkg,character.only=TRUE))
ctp_example <- read_ctp_example("../../data/scenarios/veille-ctp-section-1.json")

test_that("le CTP nominal et son solde reproduisent le cours", {
  x <- ctp_example$inputs;r <- compute_ctp_scenario(x);b <- compute_ctp_balance(r,x)
  for(n in names(ctp_example$expected)) expect_equal(if(n %in% names(r)) r[[n]] else b[[n]],ctp_example$expected[[n]],info=n)
  expect_equal(r$monthly$Total,c(21000,21000,21000,15000,15000,15000))
  expect_equal(tail(r$monthly$Cumul_projet,1),144000)
})
test_that("calibrage variable, nul et hors horizon suivent la série réelle", {
  x <- ctp_example$inputs
  for(cal in c(0,2,3,6,12)) {
    x$ctp_calibration <- cal;r <- compute_ctp_scenario(x)
    expect_equal(sum(r$monthly$Total),r$CTP)
    expect_equal(r$calibration_months,min(6,cal))
    expect_equal(r$cruise_months,max(0,6-cal))
  }
  x$ctp_calibration <- 2
  expect_equal(compute_ctp_scenario(x)$CTP,102000)
  x$ctp_calibration <- 0
  expect_equal(compute_ctp_scenario(x)$CTP,90000)
  x$ctp_calibration <- 12
  expect_equal(compute_ctp_scenario(x)$CTP,126000)
  x$ctp_t <- 1
  expect_equal(compute_ctp_scenario(x)$CTP,21000)
})
test_that("les anciens appels du moteur conservent trois mois par défaut", {
  expect_equal(compute_ctp_totals(.5,1200,6,2400,1,60,300,200),
    compute_ctp_totals(.5,1200,6,2400,1,60,300,200,3))
  expect_equal(compute_ctp_totals(.5,1200,12,2400,1,60,300,200)$CTP,198000)
})
test_that("alpha ne change pas le CTP et ne minore jamais une surcharge", {
  x <- ctp_example$inputs;r <- compute_ctp_scenario(x)
  x$ctp_alpha <- 10
  expect_equal(compute_ctp_balance(r,x)$balance,-41400)
  expect_equal(compute_ctp_scenario(x),r)
  x$ctp_alpha <- 0
  expect_equal(compute_ctp_balance(r,x)$balance,-54000)
  x <- ctp_example$inputs;x$ctp_h1 <- 700;r <- compute_ctp_scenario(x);b <- compute_ctp_balance(r,x)
  expect_equal(b$net_hours,900)
  expect_equal(b$value,36000)
  expect_equal(b$penalty,18000)
  expect_equal(b$balance,-36000)
  x$ctp_alpha <- 0
  expect_equal(compute_ctp_balance(r,x)$penalty,18000)
})
test_that("un investissement inconnu ne devient pas zéro", {
  x <- ctp_example$inputs;x$ctp_investment <- NULL;r <- compute_ctp_scenario(x)
  expect_equal(r$CTP,108000);expect_true(is.na(r$project))
  b <- compute_ctp_balance(r,x);expect_true(is.na(b$balance));expect_equal(b$before_investment,45000)
  x$ctp_investment <- NA_real_;expect_true(is.na(compute_ctp_scenario(x)$project))
  x$ctp_investment <- NA;expect_true(is.na(compute_ctp_scenario(x)$project))
  x$ctp_investment <- "";expect_true(is.na(compute_ctp_scenario(x)$project))
  x$ctp_investment <- 0;expect_equal(compute_ctp_scenario(x)$project,108000)
})
test_that("C2 détaillé ignore le coefficient et les budgets restent mensuels", {
  x <- ctp_example$inputs;x$ctp_kappa <- 4
  expect_equal(compute_ctp_scenario(x)$C2,14400)
  x$ctp_detailed <- FALSE
  expect_equal(compute_ctp_scenario(x)$C2,57600)
  x$ctp_v <- 600
  expect_equal(compute_ctp_scenario(x)$C1,3600)
})
test_that("les entrées invalides sont distinguées de l'investissement inconnu", {
  for(bad in list(list(ctp_t=0),list(ctp_t=1.5),list(ctp_calibration=-1),list(ctp_calibration=1.5),
    list(ctp_v=0),list(ctp_c1_month=-1),list(ctp_h1=Inf),list(ctp_w=NA_real_),list(ctp_investment=-1)))
    expect_error(compute_ctp_scenario(modifyList(ctp_example$inputs,bad)))
  x <- ctp_example$inputs;r <- compute_ctp_scenario(x);x$ctp_alpha <- 101
  expect_error(compute_ctp_balance(r,x));expect_equal(compute_ctp_scenario(x)$CTP,108000)
})
test_that("Shiny affiche les deux lectures et laisse l'exploitation connue sans investissement", {
  withr::with_dir("../..",shiny::testServer(saga_server, {
    x <- read_ctp_example()$inputs;do.call(session$setInputs,x)
    expect_equal(ctp_res()$project,144000);expect_equal(ctp_balance()$balance,9000)
    expect_match(as.character(output$ctp_summary$html),"144\u202f000")
    session$setInputs(ctp_calibration=2)
    expect_equal(ctp_res()$CTP,102000);expect_equal(ctp_balance()$balance,12000)
    session$setInputs(ctp_investment=NA_real_)
    expect_true(is.na(ctp_res()$project));expect_match(as.character(output$ctp_summary$html),"Investissement inconnu")
    session$setInputs(ctp_t=0)
    expect_error(ctp_res(),"horizon")
  }))
})
