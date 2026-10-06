# Construction de C1 et C3, dans les unités des champs des onglets.
component_number <- function(x, label, min=0, max=Inf, integer=FALSE) {
  if(!is.numeric(x) || length(x)!=1L || is.na(x) || !is.finite(x))
    stop(paste0("Renseignez « ",label," »."),call.=FALSE)
  if(x<min || x>max || (integer && x!=floor(x)))
    stop(paste0("Valeur invalide pour « ",label," »."),call.=FALSE)
  x
}
c1_input_names <- c("c1_n_in","c1_n_out","c1_usd_eur","c1_v","c1_calls","c1_mod_a","c1_mod_b","c1_mod_c","c1_selected")
c3_input_names <- c("c3_v","c3_w","c3_h1_input","c3_escalade","c3_t_reprise","c3_review","c3_governance")
compute_inference_scenario <- function(x, pricing) {
  ni <- component_number(x$c1_n_in,"Jetons en entrée",integer=TRUE)
  no <- component_number(x$c1_n_out,"Jetons en sortie",integer=TRUE)
  rate <- component_number(x$c1_usd_eur,"Taux de change",min=.Machine$double.eps)
  volume <- component_number(x$c1_v,"Entrées par mois",integer=TRUE)
  calls <- component_number(x$c1_calls,"Appels par entrée")
  models <- vapply(c("c1_mod_a","c1_mod_b","c1_mod_c"),function(id) {
    m <- x[[id]]
    if(length(m)!=1L || is.na(m) || !m %in% pricing$Identifiant)
      stop("Choisissez les trois modèles dans le catalogue actif.",call.=FALSE)
    m
  },character(1))
  if(length(x$c1_selected)!=1L || !x$c1_selected %in% c("A","B","C"))
    stop("Choisissez le modèle à utiliser pour le budget.",call.=FALSE)
  rows <- pricing[match(models,pricing$Identifiant),]
  cost <- compute_c1_eur(compute_c1_usd(rows$p_in_1M,rows$p_out_1M,ni,no),rate)
  monthly <- cost*volume*calls
  if(any(!is.finite(c(cost,monthly)))) stop("Le budget dépasse la capacité de calcul.",call.=FALSE)
  comparison <- data.frame(Scenario=c("A","B","C"),Modele=models,Par_appel=cost,Mensuel=monthly)
  selected <- comparison[comparison$Scenario==x$c1_selected,,drop=FALSE]
  list(valid=TRUE,comparison=comparison,selected=selected,volume=volume,calls=calls,total=selected$Mensuel)
}
compute_human_scenario <- function(x) {
  v <- component_number(x$c3_v,"Entrées par mois",integer=TRUE)
  w <- component_number(x$c3_w,"Coût horaire")
  h1 <- component_number(x$c3_h1_input,"Travail humain en calibrage")
  escalation <- component_number(x$c3_escalade,"Part des entrées à reprendre",max=100)/100
  reprise <- component_number(x$c3_t_reprise,"Temps de reprise")
  review <- component_number(x$c3_review,"Temps de revue")
  governance <- component_number(x$c3_governance,"Supervision et maintenance")
  h2 <- compute_h2_cruise(v,escalation,reprise,review,governance)
  if(any(!is.finite(c(h2,h1*w,h2*w)))) stop("Le coût dépasse la capacité de calcul.",call.=FALSE)
  list(valid=TRUE,h1=h1,h2=h2,w=w,volume=v,
    review=v*review/60,reprise=v*escalation*reprise/60,governance=governance)
}
read_component_example <- function(component) {
  jsonlite::fromJSON(paste0("data/scenarios/",component,"-estimation.json"),simplifyVector=FALSE)
}
