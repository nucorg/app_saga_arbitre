# Calculs communs aux deux visions. Montants EUR, temps en heures sauf *_minutes.
# Coût analytique réparti et décaissement initial sont deux vues, jamais additionnées.
compute_scenario <- function(volume, accepted, manual_minutes, review_minutes,
                             rework_rate, rework_minutes, governance_hours,
                             hourly_cost, api_per_input, infra_month, investment,
                             amort_months = 24, horizon = 12, alpha = 0.5,
                             value_hour = hourly_cost, calibration_months = 3,
                             calibration_hours = NULL) {
  vals <- c(volume, accepted, manual_minutes, review_minutes, rework_rate,
            rework_minutes, governance_hours, hourly_cost, api_per_input,
            infra_month, investment, amort_months, horizon, alpha, value_hour,
            calibration_months, calibration_hours)
  if (anyNA(vals) || any(!is.finite(vals)) || any(vals < 0) || accepted > volume ||
      rework_rate > 1 || alpha > 1 || amort_months <= 0 || horizon < 1 ||
      horizon != floor(horizon) || calibration_months != floor(calibration_months))
    stop("Hypothèses manquantes ou invalides")
  h0 <- volume * manual_minutes / 60
  h2 <- compute_h2_cruise(volume, rework_rate, rework_minutes, review_minutes, governance_hours)
  h1 <- if (is.null(calibration_hours)) h2 else calibration_hours
  c1 <- volume * api_per_input
  c2 <- infra_month + investment / amort_months
  c3 <- h2 * hourly_cost
  total <- c1 + c2 + c3
  # Une surcharge humaine reste un coût entier ; alpha ne minore pas une perte.
  net_value <- function(h) pmax(h, 0) * alpha * value_hour + pmin(h, 0) * hourly_cost
  monthly_h <- ifelse(seq_len(horizon) <= calibration_months, h1, h2)
  balance <- net_value(h0 - h2) - c1 - c2
  yearly <- sum(net_value(h0 - monthly_h) - c1 - infra_month) - investment
  list(h0 = h0, h2 = h2, net_hours = h0 - h2,
       reallocated_hours = alpha * max(0, h0 - h2), C1 = c1, C2 = c2, C3 = c3,
       CTP = total, cost_accepted = if (accepted == 0) Inf else total / accepted,
       balance = balance, horizon_balance = yearly,
       comparable_coverage = accepted == volume,
       horizon_cost = sum(c1 + infra_month + monthly_h * hourly_cost) + investment)
}

# Identifiant exact après normalisation typographique, sans classification pro/flash.
model_key <- function(x) tolower(gsub("[^[:alnum:]]", "", x))
compute_telemetry <- function(billing, compliance, pricing, usd_eur_rate,
                              cache_ratio, infra_eur, human_hours, hourly_cost,
                              confirmed = FALSE, prompt_includes_cache = FALSE,
                              output_includes_thinking = FALSE) {
  fail <- function(message) list(status = message, volume = NA_real_, accepted = NA_real_,
                                 ps = NA_real_, ctask = NA_real_, api_eur = NA_real_,
                                 infra_eur = infra_eur, human_eur = human_hours * hourly_cost)
  if (!confirmed) return(fail("Confirmer la période commune, les coûts complets et les résultats finaux sans doublons."))
  if (length(compliance) == 0) return(fail("Conformité absente : dénominateur inconnu."))
  vols <- vapply(compliance, function(x) x$volume, numeric(1))
  acc <- vapply(compliance, function(x) x$accepted, numeric(1))
  if (anyNA(c(vols, acc)) || any(vols < 0) || any(acc < 0) || any(acc > vols))
    return(fail("Volume ou résultats acceptés manquants / incohérents."))
  cols <- c("Rôle (Task)", "Modèle", "Prompt (In)", "Cache (In)", "Output", "Thinking")
  if (is.null(billing) || !all(cols %in% names(billing))) return(fail("Facturation absente ou format incomplet."))
  billing <- billing[!grepl("^TOTAL", billing[[cols[1]]], ignore.case = TRUE), , drop = FALSE]
  if (nrow(billing) == 0) return(fail("Aucune consommation exploitable."))
  scalar_inputs <- list(usd_eur_rate, cache_ratio, infra_eur, human_hours, hourly_cost)
  if (any(lengths(scalar_inputs) != 1L)) return(fail("Paramètres de coût manquants."))
  rates <- unlist(scalar_inputs)
  if (anyNA(rates) || any(!is.finite(rates)) || any(rates < 0) || usd_eur_rate <= 0 || cache_ratio > 1)
    return(fail("Taux de change, cache ou coûts invalides."))
  if (!all(c("Identifiant", "p_in_1M", "p_out_1M") %in% names(pricing))) return(fail("Catalogue incomplet."))
  if (anyDuplicated(model_key(pricing$Identifiant))) return(fail("Identifiants tarifaires ambigus."))
  idx <- match(model_key(billing[["Modèle"]]), model_key(pricing$Identifiant))
  if (anyNA(idx)) return(fail(paste("Tarif inconnu :", paste(unique(billing[["Modèle"]][is.na(idx)]), collapse = ", "))))
  tokens <- suppressWarnings(do.call(cbind, lapply(billing[c("Prompt (In)", "Cache (In)", "Output", "Thinking")], as.numeric)))
  if (anyNA(tokens) || any(!is.finite(tokens)) || any(tokens < 0)) return(fail("Compteurs de jetons invalides."))
  prices <- pricing[idx, , drop = FALSE]
  price_values <- unlist(prices[c("p_in_1M", "p_out_1M")])
  if (anyNA(price_values) || any(!is.finite(price_values)))
    return(fail("Tarif manquant."))
  uncached <- tokens[, 1] - if (prompt_includes_cache) tokens[, 2] else 0
  output <- tokens[, 3] + if (output_includes_thinking) 0 else tokens[, 4]
  if (any(uncached < 0)) return(fail("Cache supérieur au prompt total."))
  cached_price <- prices$p_in_1M * cache_ratio
  if ("p_cache_1M" %in% names(prices)) {
    use <- !is.na(prices$p_cache_1M)
    cached_price[use] <- prices$p_cache_1M[use]
  }
  if (any(!is.finite(cached_price)) || any(c(prices$p_in_1M, prices$p_out_1M, cached_price) < 0)) return(fail("Tarif négatif."))
  api <- sum(uncached * prices$p_in_1M + tokens[, 2] * cached_price + output * prices$p_out_1M) / 1e6 * usd_eur_rate
  v <- sum(vols); a <- sum(acc)
  human <- human_hours * hourly_cost
  list(status = if (a == 0) "Aucun résultat accepté : coût unitaire non fini." else "Estimation au catalogue local ; comparer aux factures.",
       volume = v, accepted = a, ps = if (v == 0) NA_real_ else a / v,
       ctask = if (a == 0) Inf else (api + infra_eur + human) / a,
       api_eur = api, infra_eur = infra_eur, human_eur = human)
}
