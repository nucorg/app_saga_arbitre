source("../../R/logic_maths.R")
source("../../R/logic_parsers.R")
source("../../R/logic_audit.R")
enterprise <- function(...) {
  args <- list(volume=1200, accepted=1200, manual_minutes=30, review_minutes=5,
    rework_rate=.2, rework_minutes=15, governance_hours=40, hourly_cost=60,
    api_per_input=.5, infra_month=2400, investment=36000, amort_months=24,
    horizon=12, alpha=.5, value_hour=60, calibration_months=3, calibration_hours=300)
  do.call(compute_scenario, modifyList(args, list(...)))
}
qognito <- function(...) {
  args <- list(volume=150, accepted=150, manual_minutes=45, review_minutes=5,
    rework_rate=.1, rework_minutes=15, governance_hours=4, hourly_cost=15,
    api_per_input=.05, infra_month=218, investment=0, calibration_hours=30)
  do.call(compute_scenario, modifyList(args, list(...)))
}
test_that("les deux cas utilisent le même bilan sans double comptage", {
  e <- enterprise()
  expect_equal(e$h2, 200)
  expect_equal(e$CTP, 16500)
  expect_equal(e$cost_accepted, 13.75)
  expect_equal(e$balance, 7500)
  expect_equal(e$horizon_balance, 63000)
  expect_equal(e$horizon_cost, 234000)
  q <- qognito()
  expect_equal(compute_h2_cruise(150, .1, 15), 3.75)
  expect_equal(q$h2, 20.25)
  expect_equal(q$CTP, 529.25)
  expect_equal(q$balance, 466.375)
  expect_equal(q$horizon_balance, 5377.125)
})
test_that("sensibilités économiques et couverture restent visibles", {
  expect_equal(enterprise(volume=300, accepted=300)$balance, -1950)
  expect_equal(enterprise(rework_rate=.5)$balance, 4800)
  expect_equal(enterprise(alpha=.1)$balance, -2100)
  expect_equal(enterprise(alpha=0)$balance, -4500)
  expect_equal(enterprise(governance_hours=120)$balance, 5100)
  expect_equal(enterprise(accepted=1000)$cost_accepted, 16.5)
  expect_false(enterprise(accepted=1000)$comparable_coverage)
  expect_equal(enterprise(accepted=0)$cost_accepted, Inf)
  expect_equal(qognito(alpha=0)$balance, -225.5)
  expect_equal(enterprise(investment=0)$horizon_balance - enterprise()$horizon_balance, 36000)
  # Une surcharge humaine n'est pas effacée par alpha=0.
  expect_lt(enterprise(governance_hours=700, alpha=0)$balance, -4500)
  expect_error(enterprise(accepted=1201))
  expect_error(enterprise(rework_rate=1.1))
  expect_error(enterprise(horizon=2.5))
  expect_error(enterprise(hourly_cost=NA_real_))
})
test_that("le micro-cas se rapproche du scénario global", {
  after <- enterprise(governance_hours=42,
    rework_rate=53.6 * 60 / (1200 * 15), infra_month=2420, investment=37200)
  expect_equal(after$h2, 195.6)
  expect_equal(after$CTP, 16306)
  expect_equal(after$balance, 7562)
  expect_equal(enterprise()$CTP - after$CTP, 194)
  expect_equal(after$balance - enterprise()$balance, 62)
})
bill <- data.frame(role="a", model="Test Model", prompt=1e6, cache=1e6,
                   output=1e6, thinking=0, stringsAsFactors=FALSE)
names(bill) <- c("Rôle (Task)","Modèle","Prompt (In)","Cache (In)","Output","Thinking")
prices <- data.frame(Identifiant="Test Model",p_in_1M=2,p_out_1M=4)
comp <- list(list(volume=10,accepted=8,success_rate=80,basis="counts"))
tel <- function(...) { args <- list(billing=bill,
  compliance=comp, pricing=prices, usd_eur_rate=.8, cache_ratio=.25,
  infra_eur=10, human_hours=2, hourly_cost=15, confirmed=TRUE)
  overrides <- list(...); args[names(overrides)] <- overrides
  do.call(compute_telemetry, args)
}
test_that("la télémétrie applique catalogue, change et dénominateur final", {
  x <- tel()
  expect_equal(x$api_eur, 5.2)
  expect_equal(x$ctask, (5.2 + 10 + 30) / 8)
  expect_equal(tel(cache_ratio=.5)$api_eur, 5.6)
  expect_equal(tel(usd_eur_rate=1)$api_eur, 6.5)
  expect_equal(tel(prompt_includes_cache=TRUE)$api_eur, 3.6)
  with_thinking <- bill; with_thinking$Thinking <- 1e6
  expect_equal(tel(billing=with_thinking)$api_eur, 8.4)
  expect_equal(tel(billing=with_thinking, output_includes_thinking=TRUE)$api_eur, 5.2)
  cache_price <- prices; cache_price$p_cache_1M <- .1
  expect_equal(tel(pricing=cache_price)$api_eur, 4.88)
  expect_equal(tel(compliance=list(comp[[1]], list(volume=90,accepted=81)))$ps, .89)
})
test_that("absence, taux nul et modèle inconnu ne fabriquent aucun coût fini", {
  unknown <- bill; unknown$Modèle <- "unknown-pro"
  expect_true(is.na(tel(billing=unknown)$ctask))
  expect_match(tel(billing=unknown)$status,"Tarif inconnu")
  expect_true(is.na(tel(confirmed=FALSE)$ctask))
  expect_true(is.na(tel(compliance=list())$ctask))
  expect_true(is.na(tel(compliance=list(list(volume=NA_real_,accepted=NA_real_)))$ctask))
  expect_equal(tel(compliance=list(list(volume=10,accepted=0)))$ctask, Inf)
  expect_true(is.na(tel(compliance=list(list(volume=10,accepted=11)))$ctask))
  expect_true(is.na(tel(pricing=rbind(prices,prices))$ctask))
  bad <- bill; bad$Thinking <- NA_real_
  expect_true(is.na(tel(billing=bad)$ctask))
  expect_true(is.na(tel(usd_eur_rate=0)$ctask))
})
test_that("parsing historique, décimales et acceptés explicites", {
  path <- tempfile(fileext=".md"); on.exit(unlink(path))
  expect_true(is.na(parse_compliance_md(path)$volume))
  writeLines(c("Total de Livrables jugés : 100", "Fiabilité Composée (Ps) : 95,5 %"), path)
  expect_equal(parse_compliance_md(path)$accepted, 95.5)
  expect_identical(parse_compliance_md(path)$basis, "legacy_rate_estimate")
  writeLines(c("Total de Livrables jugés : 100", "Résultats acceptés : 80", "Fiabilité Composée (Ps) : 90 %"), path)
  expect_equal(parse_compliance_md(path)$success_rate, 80)
  writeLines(c("| A | B |", "|---|---|"), path)
  expect_null(parse_billing_md(path))
  writeLines(c("| A | B |", "|---|---|", "| a | 2 |", "| b | 3 | 4 |"), path)
  expect_null(parse_billing_md(path))
})
