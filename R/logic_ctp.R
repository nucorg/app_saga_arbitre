# CTP du projet et valeur conventionnelle : aucune dépendance aux pages Terrain.
ctp_input_names <- c("ctp_t","ctp_v","ctp_c1_month","ctp_orch","ctp_detailed","ctp_kappa",
  "ctp_w","ctp_calibration","ctp_h1","ctp_h2","ctp_investment",
  "ctp_manual_minutes","ctp_alpha","ctp_value_hour")
read_ctp_example <- function(path="data/scenarios/veille-ctp-section-1.json")
  jsonlite::fromJSON(path, simplifyVector=FALSE)
ctp_scalar <- function(x, label, min=0, max=Inf, integer=FALSE) {
  if (!is.numeric(x) || length(x)!=1L || is.na(x) || !is.finite(x) ||
      x < min || x > max || (integer && x != floor(x)))
    stop(paste0("Renseignez ", label, " avec un nombre valide", if(integer) " entier" else "", "."))
  x
}
compute_ctp_scenario <- function(x) {
  t <- ctp_scalar(x$ctp_t,"l’horizon T (1 à 24 mois)",1,24,TRUE)
  v <- ctp_scalar(x$ctp_v,"le volume mensuel positif",1)
  cal <- ctp_scalar(x$ctp_calibration,"la durée du calibrage (0 à 120 mois)",0,120,TRUE)
  for (id in c("ctp_c1_month","ctp_orch","ctp_w","ctp_h1","ctp_h2")) ctp_scalar(x[[id]],id)
  if (!is.logical(x$ctp_detailed) || length(x$ctp_detailed)!=1L || is.na(x$ctp_detailed))
    stop("Précisez si C2 est un total mensuel déjà évalué.")
  k <- if (x$ctp_detailed) 1 else ctp_scalar(x$ctp_kappa,"le coefficient C2",1)
  inv <- x$ctp_investment
  unknown <- is.null(inv) || (is.atomic(inv) && length(inv)==1L && (is.na(inv) || identical(inv,"")))
  investment <- if (unknown) NA_real_ else ctp_scalar(inv,"l’investissement initial (zéro seulement s’il est nul)")
  series <- compute_ctp_monthly(x$ctp_c1_month/v,v,t,x$ctp_orch,k,x$ctp_w,x$ctp_h1,x$ctp_h2,cal)
  series$Phase <- ifelse(series$Mois <= cal,"Calibrage","Croisière")
  series$Heures <- ifelse(series$Mois <= cal,x$ctp_h1,x$ctp_h2)
  series$Cumul_exploitation <- cumsum(series$Total)
  series$Cumul_projet <- series$Cumul_exploitation + investment
  list(C1=sum(series$C1),C2=sum(series$C2),C3=sum(series$C3),CTP=sum(series$Total),
       investment=investment,project=sum(series$Total)+investment,monthly=series,
       human_hours=sum(series$Heures),calibration_months=min(t,cal),cruise_months=max(0,t-cal),
       effective_c2=x$ctp_orch*k)
}
compute_ctp_balance <- function(result,x) {
  minutes <- ctp_scalar(x$ctp_manual_minutes,"le temps manuel en minutes")
  alpha <- ctp_scalar(x$ctp_alpha,"la part réaffectée (0 à 100 %)",0,100)/100
  value_hour <- ctp_scalar(x$ctp_value_hour,"la valeur d’une heure réaffectée")
  monthly <- result$monthly
  manual <- x$ctp_v * minutes/60
  monthly$Heures_manuelles <- manual
  monthly$Capacite_nette <- manual-monthly$Heures
  monthly$Heures_reaffectees <- pmax(monthly$Capacite_nette,0)*alpha
  monthly$Valeur_reaffectee <- monthly$Heures_reaffectees*value_hour
  monthly$Penalite_surcharge <- pmax(-monthly$Capacite_nette,0)*x$ctp_w
  monthly$Solde_avant_investissement <- monthly$Valeur_reaffectee-monthly$Penalite_surcharge-monthly$C1-monthly$C2
  list(manual_hours=sum(monthly$Heures_manuelles),human_hours=result$human_hours,
       net_hours=sum(monthly$Capacite_nette),reallocated_hours=sum(monthly$Heures_reaffectees),
       value=sum(monthly$Valeur_reaffectee),penalty=sum(monthly$Penalite_surcharge),
       nonhuman=result$C1+result$C2,before_investment=sum(monthly$Solde_avant_investissement),
       balance=sum(monthly$Solde_avant_investissement)-result$investment,monthly=monthly)
}
