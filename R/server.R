saga_server <- function(input, output, session) {
  
  # -- Onglet 1 : un mois stabilisé --
  scenarios_rv <- reactiveValues(data = list())
  monthly_inputs <- reactive({
    values <- setNames(lapply(monthly_input_names, function(id) input[[id]]), monthly_input_names)
    if (!is.null(values$projection_months)) values$projection_months <- suppressWarnings(as.numeric(values$projection_months))
    values
  })
  monthly_result <- reactive({
    tryCatch(compute_monthly_comparison(monthly_inputs()), error = function(e) {
      validate(need(FALSE, conditionMessage(e)))
    })
  })
  observeEvent(input$load_monthly_example, {
    example <- read_monthly_example()
    for (id in setdiff(monthly_input_names, "projection_months"))
      updateNumericInput(session, id, value = example$inputs[[id]])
    updateSelectInput(session, "projection_months", selected = as.character(example$inputs$projection_months))
    showNotification("Exemple Veille — Section 1 chargé. Vous pouvez modifier les paramètres.", type = "message")
  })
  monthly_fmt <- function(x, digits = 0) {
    if (is.na(x) || !is.finite(x)) return("Non défini")
    formatC(x, format = "f", digits = digits, big.mark = "\u202f", decimal.mark = ",")
  }
  money <- function(x, digits = 0) paste0(monthly_fmt(x, digits), "\u00a0€")
  output$monthly_c1_hint <- renderText({
    paste0("Équivalent : ", money(monthly_result()$c1_per_input, 2), " par entrée.")
  })
  output$monthly_c3_hint <- renderText({
    r <- monthly_result(); x <- monthly_inputs()
    paste0(monthly_fmt(x$maint_h, 1), " h × ", money(x$cost_h, 2), "/h = ", money(r$c3), "/mois.")
  })
  output$monthly_summary <- renderUI({
    r <- monthly_result(); x <- monthly_inputs()
    metric <- function(label, value, id, number) tags$div(class = "monthly-metric",
      tags$span(label), tags$strong(value, id = id, `data-value` = number))
    tagList(
      p(strong(paste0(monthly_fmt(r$accepted, 1), " résultats finalement acceptés / mois")),
        paste0(" pour ", monthly_fmt(x$vol, 1), " entrées et ", monthly_fmt(x$ps, 1), " % d’acceptation finale.")),
      tags$div(class = "monthly-metrics",
        metric("Fonctionnement courant", paste0(money(r$current), "/mois"), "monthly-current", r$current),
        metric("Part d’investissement", paste0(money(r$allocation), "/mois"), "monthly-allocation", r$allocation),
        metric("Coût mensuel analytique", paste0(money(r$analytical), "/mois"), "monthly-analytical", r$analytical)),
      if (r$accepted > 0) p(
        "Par résultat accepté : ", strong(paste0(money(r$current_per_accepted, 2), " courant"), id = "monthly-unit-current", `data-value` = r$current_per_accepted),
        " puis ", strong(paste0(money(r$analytical_per_accepted, 2), " analytique"), id = "monthly-unit-analytical", `data-value` = r$analytical_per_accepted), ".")
      else p("Aucun résultat finalement accepté : les coûts mensuels restent connus, mais les coûts par résultat et la comparaison unitaire ne sont pas définis."),
      p(paste0("Répartition : ", money(x$build_ia), " / ", monthly_fmt(x$amort_months), " mois = ", money(r$allocation), "/mois.")),
      if (r$accepted > 0) p(paste0("Écart de coûts analytiques avec le manuel : ", money(r$manual_analytical - r$analytical), "/mois. Cet écart n’est pas automatiquement une économie de trésorerie.")))
  })
  output$monthly_breakdown <- renderTable({
    r <- monthly_result()
    data.frame(
      Poste = c("C1 — Utilisation des modèles", "C2 — Infrastructure logicielle", "C3 — Travail humain", "Fonctionnement courant", "Part mensuelle d’investissement", "Coût mensuel analytique"),
      `Manuel (€/mois)` = c("—", "—", money(r$manual_current), money(r$manual_current), money(r$manual_allocation), money(r$manual_analytical)),
      `Dispositif (€/mois)` = vapply(c(r$c1, r$c2, r$c3, r$current, r$allocation, r$analytical), money, character(1)),
      check.names = FALSE)
  }, striped = TRUE, bordered = FALSE, spacing = "s", width = "100%", rownames = FALSE)
  observeEvent(input$add_scen, {
    result <- tryCatch(compute_monthly_comparison(monthly_inputs()), error = function(e) NULL)
    if (is.null(result) || result$accepted <= 0) {
      showNotification("Renseignez des paramètres valides et au moins un résultat accepté avant d’ajouter une comparaison.", type = "warning")
      return()
    }
    scen_id <- paste("Scénario", length(scenarios_rv$data) + 1)
    scenarios_rv$data[[scen_id]] <- list(inputs = monthly_inputs(), result = result)
  })
  output$monthly_saved <- renderUI({
    if (!length(scenarios_rv$data)) return(p("Aucune comparaison ajoutée. La simulation courante reste affichée."))
    tagList(lapply(names(scenarios_rv$data), function(name) {
      saved <- scenarios_rv$data[[name]]; x <- saved$inputs; r <- saved$result
      tags$div(h5(name), p(paste0(
        monthly_fmt(x$vol), " entrées/mois ; ", monthly_fmt(x$ps, 1), " % acceptés ; manuel ", monthly_fmt(x$time_h, 1), " min/résultat ; ",
        money(x$cost_h, 2), "/h ; C1 ", money(x$cost_c1_month), "/mois ; C2 ", money(x$cost_orch), "/mois ; C3 ", monthly_fmt(x$maint_h, 1), " h/mois ; ",
        "investissement dispositif ", money(x$build_ia), ", manuel ", money(x$build_manual), " ; répartition ", monthly_fmt(x$amort_months), " mois ; projection ", monthly_fmt(x$projection_months), " mois.")),
        p(paste0("Courant : ", money(r$current), "/mois ; analytique : ", money(r$analytical), "/mois ; ", money(r$analytical_per_accepted, 2), "/résultat accepté.")))
    }))
  })
  comparison_data <- reactive({
    r <- monthly_result()
    validate(need(r$accepted > 0, "Aucun résultat accepté : comparaison par résultat non définie."))
    row <- function(label, result) data.frame(
      Scenario = label, Type = c("Manuel analytique", "Dispositif courant", "Dispositif analytique"),
      Cout = c(result$manual_per_accepted, result$current_per_accepted, result$analytical_per_accepted))
    current <- row("Simulation courante", r)
    saved <- lapply(names(scenarios_rv$data), function(name) row(name, scenarios_rv$data[[name]]$result))
    bind_rows(c(list(current), saved))
  })
  output$plot_ctask <- renderPlotly({
    df <- comparison_data()
    df$Type <- factor(df$Type, levels = c("Manuel analytique", "Dispositif courant", "Dispositif analytique"))
    df$Scenario <- factor(df$Scenario, levels = unique(df$Scenario))
    plot_ly(df, x = ~Scenario, y = ~Cout, color = ~Type,
      colors = c("#FFFFFF", "#779FCB", "#D4850F"), type = "bar",
      text = vapply(df$Cout, money, character(1), digits = 2),
      textposition = "outside", cliponaxis = FALSE,
      textfont = list(color = "white", size = 14),
      hovertemplate = "%{x}<br>%{fullData.name} : %{y:.2f} €<extra></extra>") %>% layout(
        barmode = "group", bargap = .3,
        font = list(color = "white", family = "system-ui, sans-serif"),
        plot_bgcolor = "transparent", paper_bgcolor = "transparent",
        xaxis = list(title = "", categoryorder = "array", categoryarray = levels(df$Scenario)),
        yaxis = list(title = "€ par résultat accepté", range = c(0, max(1, max(df$Cout) * 1.25))),
        legend = list(orientation = "h", x = 0, y = -.3, title = list(text = "")),
        margin = list(b = 95, t = 30, l = 65, r = 20)) %>%
      config(displayModeBar = FALSE)

  })
  monthly_projection <- reactive({
    r <- monthly_result()
    validate(need(r$accepted > 0, "Aucun résultat accepté : projection comparative non définie."))
    compute_monthly_projection(monthly_inputs(), r)
  })
  output$plot_roi <- renderPlotly({
    df <- monthly_projection()
    df$Type[df$Type == "Agent IA"] <- "Dispositif"
    p <- ggplot(df, aes(x = Mois, y = Cout_Cumule, color = Type)) +
      geom_line(linewidth = 1.2) + geom_point(size = 2) +
      scale_color_manual(values = c("Manuel" = "#FFFFFF", "Dispositif" = "#D4850F")) +
      scale_x_continuous(breaks = 0:monthly_inputs()$projection_months) +
      labs(y = "Coût cumulé (€)", x = "Mois — 0 : investissement initial", color = NULL) +
      theme_minimal(base_size = 13) + theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background = element_rect(fill = "transparent", color = NA),
        text = element_text(color = "white"), axis.text = element_text(color = "white"), legend.position = "bottom")
    ggplotly(p, tooltip = c("x", "y", "color")) %>% layout(
      plot_bgcolor = "transparent", paper_bgcolor = "transparent",
      legend = list(orientation = "h", x = .5, y = -.3, xanchor = "center"), margin = list(b = 75))
  })

  # -- Onglet C1 --
  
  # Chaque appel du serveur possède sa référence, ses tarifs actifs et son brouillon.
  reference_pricing <- validate_api_pricing(read_api_pricing("data/pricing_models.csv"))
  pricing_data <- reactiveVal(reference_pricing)
  rv_pricing_edit <- reactiveVal(reference_pricing)
  pricing_error <- reactiveVal("")

  # -- Onglet Prix API : aucune écriture dans le catalogue partagé --
  output$table_pricing_edit <- renderDT({
    datatable(
      isolate(rv_pricing_edit()),
      editable = TRUE, rownames = FALSE, selection = "single",
      options = list(pageLength = 100, dom = "tip", scrollX = TRUE)
    )
  })
  proxy_pricing_edit <- dataTableProxy("table_pricing_edit")
  refresh_pricing_table <- function() {
    replaceData(proxy_pricing_edit, rv_pricing_edit(), resetPaging = FALSE, rownames = FALSE)
  }
  pricing_action <- function(action) {
    tryCatch({
      action()
      pricing_error("")
    }, error = function(e) {
      pricing_error(conditionMessage(e))
      showNotification(conditionMessage(e), type = "error", id = "pricing-feedback")
      refresh_pricing_table()
    })
  }
  set_pricing_draft <- function(df) {
    rv_pricing_edit(validate_api_pricing(df))
    refresh_pricing_table()
  }
  output$pricing_error <- renderText(pricing_error())
  output$pricing_status <- renderText({
    if (!identical(rv_pricing_edit(), pricing_data()))
      "Modifications à appliquer : les calculs utilisent encore les tarifs précédemment appliqués."
    else if (identical(pricing_data(), reference_pricing))
      "Tarifs de référence actifs dans votre simulation."
    else
      "Vos tarifs personnels sont actifs dans votre simulation."
  })

  observeEvent(input$add_row, {
    pricing_action(function() {
      df <- rv_pricing_edit()
      name <- "Nouveau Modèle"
      suffix <- 2L
      while (tolower(name) %in% tolower(df$Identifiant)) {
        name <- paste("Nouveau Modèle", suffix)
        suffix <- suffix + 1L
      }
      new_row <- data.frame(Identifiant = name, Fournisseur = "",
        p_in_1M = 0, p_out_1M = 0, p_cache_1M = NA_real_,
        date_verification = as.Date(NA))
      set_pricing_draft(rbind(new_row, df))
    })
  })
  observeEvent(input$delete_row, {
    selected <- input$table_pricing_edit_rows_selected
    if (!length(selected)) {
      showNotification("Veuillez sélectionner une ligne à supprimer.", type = "warning")
      return()
    }
    pricing_action(function() {
      df <- rv_pricing_edit()
      selected <- intersect(selected, seq_len(nrow(df)))
      if (length(selected)) set_pricing_draft(df[-selected, , drop = FALSE])
    })
  })
  observeEvent(input$table_pricing_edit_cell_edit, {
    pricing_action(function() {
      info <- input$table_pricing_edit_cell_edit
      df <- rv_pricing_edit()
      row <- info$row
      column <- info$col + 1L
      if (length(row) != 1L || length(column) != 1L || is.na(row) || is.na(column) ||
          !row %in% seq_len(nrow(df)) || !column %in% seq_len(ncol(df)))
        stop("Modification de cellule invalide.", call. = FALSE)
      # Garder la valeur saisie jusqu'à validation, sans transformer une erreur en NA.
      df[[column]] <- as.character(df[[column]])
      df[row, column] <- info$value
      set_pricing_draft(df)
    })
  })
  observeEvent(input$apply_pricing, {
    pricing_action(function() {
      pricing_data(validate_api_pricing(rv_pricing_edit()))
      showNotification("Tarifs appliqués à votre simulation uniquement.", type = "message", id = "pricing-feedback")
    })
  })
  observeEvent(input$import_pricing, {
    req(input$import_pricing$datapath)
    pricing_action(function() {
      set_pricing_draft(import_api_pricing(input$import_pricing$datapath))
      showNotification("Tarifs importés. Cliquez sur « Appliquer à ma simulation » pour les utiliser.",
                       type = "message", duration = 8, id = "pricing-feedback")
    })
  })
  observeEvent(input$reset_pricing, {
    pricing_action(function() {
      set_pricing_draft(reference_pricing)
      pricing_data(reference_pricing)
      showNotification("Tarifs de référence rétablis dans la table et la simulation.", type = "message", id = "pricing-feedback")
    })
  })
  output$export_pricing <- downloadHandler(
    filename = function() paste0("saga-tarifs-", Sys.Date(), ".csv"),
    content = function(file) export_api_pricing(isolate(rv_pricing_edit()), file),
    contentType = "text/csv; charset=UTF-8"
  )

  observe({
    models <- sort(pricing_data()$Identifiant)
    ids <- c("c1_mod_a", "c1_mod_b", "c1_mod_c")
    for (i in seq_along(ids)) {
      selected <- isolate(input[[ids[i]]])
      if (length(selected) != 1L || !selected %in% models)
        selected <- models[min(i, length(models))]
      updateSelectInput(session, ids[i], choices = models, selected = selected)
    }
  })

  # -- C1 : comparaison et budget mensuel explicitement retenu --
  c1_inputs <- reactive(setNames(lapply(c1_input_names,function(id) input[[id]]),c1_input_names))
  c1_result <- reactive(tryCatch(compute_inference_scenario(c1_inputs(),pricing_data()),
    error=function(e) list(valid=FALSE,error=conditionMessage(e))))
  observeEvent(input$load_c1_example, {
    x <- read_component_example("c1")$inputs
    if(!all(unlist(x[c("c1_mod_a","c1_mod_b","c1_mod_c")]) %in% pricing_data()$Identifiant)) {
      showNotification("Un modèle de l’exemple est absent du catalogue actif. Rétablissez les tarifs de référence ou choisissez vos modèles.",type="warning")
      return()
    }
    for(id in c("c1_n_in","c1_n_out","c1_usd_eur","c1_v","c1_calls")) updateNumericInput(session,id,value=x[[id]])
    for(id in c("c1_mod_a","c1_mod_b","c1_mod_c")) updateSelectInput(session,id,selected=x[[id]])
    updateRadioButtons(session,"c1_selected",selected=x$c1_selected)
    showNotification("Exemple C1 chargé. Le budget utilise vos tarifs actifs.",type="message")
  })
  output$c1_summary <- renderUI({
    r <- c1_result()
    if(!r$valid) return(p(role="status",r$error))
    tagList(p(strong(paste0("Modèle ",r$selected$Scenario," — ",r$selected$Modele))),
      div(class="monthly-metrics",
        div(class="monthly-metric",span("Coût par appel"),strong(id="c1-call",`data-value`=r$selected$Par_appel,money(r$selected$Par_appel,6))),
        div(class="monthly-metric",span("Budget C1 mensuel"),strong(id="c1-total",`data-value`=r$total,paste0(money(r$total,2),"/mois")))),
      p(paste0(r$volume," entrées/mois × ",r$calls," appels/entrée = ",r$volume*r$calls," appels/mois.")))
  })
  output$c1_transfer_actions <- renderUI({
    div(class="saga-component-actions",
      actionButton("c1_to_monthly","Utiliser dans Manuel vs Agentique",disabled=!c1_result()$valid),
      actionButton("c1_to_ctp","Utiliser dans Diagnostic d’Investissement (CTP)",disabled=!c1_result()$valid))
  })
  c1_transfer <- function(destination) {
    r <- c1_result()
    if(!r$valid) { showNotification(r$error,type="warning");return(invisible(FALSE)) }
    id <- if(destination=="monthly") "cost_c1_month" else "ctp_c1_month"
    label <- if(destination=="monthly") "Manuel vs Agentique" else "Diagnostic d'Investissement (CTP)"
    updateNumericInput(session,id,value=r$total)
    bslib::nav_select("saga_nav",selected=label,session=session)
    showNotification(paste0("Budget C1 reporté : ",money(r$total,2),"/mois. Volume de la destination conservé ; budget fixe."),type="message")
    invisible(TRUE)
  }
  observeEvent(input$c1_to_monthly,{c1_transfer("monthly")},ignoreInit=TRUE)
  observeEvent(input$c1_to_ctp,{c1_transfer("ctp")},ignoreInit=TRUE)
  output$table_c1_pricing <- renderDT({
    rate <- input$c1_usd_eur
    validate(need(is.numeric(rate) && length(rate)==1L && !is.na(rate) && is.finite(rate) && rate>0,"Renseignez un taux de change positif."))
    df <- pricing_data()
    cols <- c("p_in_1M","p_out_1M","p_cache_1M")
    df[cols] <- lapply(df[cols],function(x) x*rate)
    names(df) <- c("Modèle","Fournisseur","Entrée (€/million)","Sortie (€/million)","Cache (€/million)","Vérifié le")
    datatable(df,rownames=FALSE,options=list(pageLength=5,dom='tip',scrollX=TRUE)) %>%
      formatRound(columns=names(df)[3:5],digits=3)
  })
  output$plot_c1_compare <- renderPlotly({
    r <- c1_result();validate(need(r$valid,r$error))
    df <- r$comparison
    plot_ly(df,x=~Mensuel,y=~Scenario,type="bar",orientation="h",
      marker=list(color=ifelse(df$Scenario==r$selected$Scenario,"#D4850F","#779FCB")),
      text=vapply(df$Mensuel,money,character(1),digits=2),textposition="outside",cliponaxis=FALSE,
      customdata=df$Modele,hovertemplate="%{y} — %{customdata}<br>%{x:.4f} €/mois<extra></extra>") %>%
      layout(font=list(color="white",family="system-ui, sans-serif"),plot_bgcolor="transparent",paper_bgcolor="transparent",
        xaxis=list(title="Budget mensuel (€)",range=c(0,max(1,max(df$Mensuel)*1.35))),
        yaxis=list(title="Modèle",autorange="reversed"),margin=list(l=60,r=35,t=15,b=60)) %>% config(displayModeBar=FALSE)
  })

  # -- Onglet C2 : construction explicite du budget mensuel --
  c2_inputs <- reactive(setNames(lapply(infra_input_names, function(id) input[[id]]), infra_input_names))
  c2_budget_result <- reactive(compute_infra_budget(c2_inputs()))
  observeEvent(input$load_c2_example, {
    x <- read_infra_example()$inputs
    for(id in infra_input_names) updateNumericInput(session,id,value=x[[id]])
    showNotification("Exemple pédagogique C2 chargé. Les six montants restent modifiables.",type="message")
  })
  observeEvent(input$clear_c2, {
    for(id in infra_input_names) updateNumericInput(session,id,value=NA_real_)
  })
  output$c2_budget <- renderUI({
    r <- c2_budget_result()
    if(!r$complete) return(tagList(
      p(id="c2-status",role="status",paste0("Budget à compléter — ",r$count,if(r$count==1) " poste renseigné sur 6" else " postes renseignés sur 6")),
      if(nzchar(r$error)) p(role="alert",r$error)))
    labels <- r$rows$Poste; values <- r$rows$Montant
    tagList(
      div(class="monthly-metric saga-c2-metric",span("Total mensuel C2"),
          strong(id="c2-total",`data-value`=r$total,paste0(money(r$total,2),"/mois"))),
      if(r$total==0) p(id="c2-zero","Les six postes sont explicitement nuls. Le budget C2 retenu est de 0 €/mois.")
      else tagList(h4("Répartition du budget"),
        tags$ul(class="saga-c2-bars",lapply(seq_along(values),function(i) tags$li(
          div(class="saga-c2-bar-label",span(labels[i]),strong(class="monthly-number",money(values[i],2))),
          div(class="saga-c2-track",`aria-hidden`="true",
            div(class="saga-c2-bar",style=paste0("width:",100*values[i]/max(values),"%;")))))))
    )
  })
  output$c2_transfer_actions <- renderUI({
    disabled <- !c2_budget_result()$complete
    div(class="saga-c2-actions",
      actionButton("c2_to_monthly","Utiliser dans Manuel vs Agentique",disabled=disabled),
      actionButton("c2_to_ctp","Utiliser dans Diagnostic d’Investissement (CTP)",disabled=disabled))
  })
  # Validation répétée côté serveur : un clic ne doit jamais transférer un ancien total.
  c2_transfer <- function(destination) {
    r <- c2_budget_result()
    if(!r$complete) {
      showNotification("Complétez les six montants C2 avant le report.",type="warning")
      return(invisible(FALSE))
    }
    if(destination=="monthly") {
      updateNumericInput(session,"cost_orch",value=r$total)
      bslib::nav_select("saga_nav",selected="Manuel vs Agentique",session=session)
      label <- "Manuel vs Agentique"
    } else {
      updateNumericInput(session,"ctp_orch",value=r$total)
      updateCheckboxInput(session,"ctp_detailed",value=TRUE)
      updateNumericInput(session,"ctp_kappa",value=1)
      bslib::nav_select("saga_nav",selected="Diagnostic d'Investissement (CTP)",session=session)
      label <- "Diagnostic d’Investissement (CTP), sans majoration"
    }
    showNotification(paste0("C2 reporté : ",money(r$total,2),"/mois dans ",label,". Autres paramètres conservés."),type="message")
    invisible(TRUE)
  }
  observeEvent(input$c2_to_monthly, { c2_transfer("monthly") },ignoreInit=TRUE)
  observeEvent(input$c2_to_ctp, { c2_transfer("ctp") },ignoreInit=TRUE)

  # -- C3 : charge humaine par phase, sans durée de phase imposée ici --
  c3_inputs <- reactive(setNames(lapply(c3_input_names,function(id) input[[id]]),c3_input_names))
  c3_computation <- reactive(tryCatch(compute_human_scenario(c3_inputs()),
    error=function(e) list(valid=FALSE,error=conditionMessage(e))))
  observeEvent(input$load_c3_example, {
    x <- read_component_example("c3")$inputs
    for(id in c3_input_names) updateNumericInput(session,id,value=x[[id]])
    updateRadioButtons(session,"c3_monthly_phase",selected="croisiere")
    showNotification("Exemple C3 chargé : calibrage et croisière restent modifiables.",type="message")
  })
  output$c3_ready <- renderText(if(c3_computation()$valid) "yes" else "no")
  outputOptions(output,"c3_ready",suspendWhenHidden=FALSE)
  output$c3_summary <- renderUI({
    r <- c3_computation()
    if(!r$valid) return(p(role="status",r$error))
    metric <- function(label,h,id) div(class="monthly-metric",span(label),
      strong(id=id,`data-value`=h,paste0(formatC(h,format="f",digits=2,decimal.mark=",")," h/mois")),
      p(paste0(money(h*r$w,2),"/mois à ",money(r$w,2),"/h")))
    tagList(div(class="monthly-metrics",metric("Calibrage — h1",r$h1,"c3-h1"),metric("Croisière — h2",r$h2,"c3-h2")),
      p(paste0("Croisière : ",formatC(r$review,format="f",digits=2,decimal.mark=",")," h de revue + ",
        formatC(r$reprise,format="f",digits=2,decimal.mark=",")," h de reprises + ",
        formatC(r$governance,format="f",digits=2,decimal.mark=",")," h de supervision et maintenance par mois.")),
      p(strong(paste0("Phase du report mensuel : ",if(identical(input$c3_monthly_phase,"calibrage")) "calibrage" else "croisière","."))))
  })
  output$c3_transfer_actions <- renderUI({
    r <- c3_computation()
    phase_ok <- identical(input$c3_monthly_phase,"calibrage") || identical(input$c3_monthly_phase,"croisiere")
    div(class="saga-component-actions",
      actionButton("c3_to_monthly","Utiliser dans Manuel vs Agentique",disabled=!r$valid || !phase_ok),
      actionButton("c3_to_ctp","Utiliser dans Diagnostic d’Investissement (CTP)",disabled=!r$valid))
  })
  c3_transfer <- function(destination) {
    r <- c3_computation()
    if(!r$valid) { showNotification(r$error,type="warning");return(invisible(FALSE)) }
    if(destination=="monthly") {
      phase <- input$c3_monthly_phase
      if(length(phase)!=1L || !phase %in% c("calibrage","croisiere")) {
        showNotification("Choisissez la phase du report mensuel.",type="warning");return(invisible(FALSE))
      }
      h <- if(phase=="calibrage") r$h1 else r$h2
      updateNumericInput(session,"maint_h",value=h)
      updateNumericInput(session,"cost_h",value=r$w)
      label <- "Manuel vs Agentique"
      message <- paste0("C3 reporté : ",h," h/mois en ",phase,". Coût horaire commun au manuel et au dispositif : ",money(r$w,2),"/h. Volume conservé.")
    } else {
      updateNumericInput(session,"ctp_h1",value=r$h1)
      updateNumericInput(session,"ctp_h2",value=r$h2)
      updateNumericInput(session,"ctp_w",value=r$w)
      label <- "Diagnostic d'Investissement (CTP)"
      message <- "C3 reporté : heures de calibrage et de croisière, et coût horaire. Volume, durée du calibrage et horizon conservés."
    }
    bslib::nav_select("saga_nav",selected=label,session=session)
    showNotification(message,type="message",duration=8)
    invisible(TRUE)
  }
  observeEvent(input$c3_to_monthly,{c3_transfer("monthly")},ignoreInit=TRUE)
  observeEvent(input$c3_to_ctp,{c3_transfer("ctp")},ignoreInit=TRUE)
  output$plot_c3_asym <- renderPlotly({
    r <- c3_computation();validate(need(r$valid,r$error))
    df <- data.frame(Phase=c("Calibrage","Croisière"),Cout=c(r$h1,r$h2)*r$w)
    plot_ly(df,x=~Cout,y=~Phase,type="bar",orientation="h",marker=list(color=c("#D4850F","#779FCB")),
      text=vapply(df$Cout,money,character(1),digits=2),textposition="outside",cliponaxis=FALSE,
      hovertemplate="%{y}<br>%{x:.2f} €/mois<extra></extra>") %>%
      layout(font=list(color="white",family="system-ui, sans-serif"),plot_bgcolor="transparent",paper_bgcolor="transparent",
        xaxis=list(title="Coût humain mensuel (€)",range=c(0,max(1,max(df$Cout)*1.35))),
        yaxis=list(title="",autorange="reversed"),margin=list(l=90,r=30,t=15,b=60)) %>% config(displayModeBar=FALSE)
  })

  # -- Onglet CTP : exploitation, investissement et valeur par phase --
  ctp_inputs <- reactive({
    x <- setNames(lapply(ctp_input_names,function(id) input[[id]]),ctp_input_names)
    # Les anciennes radios utilisaient une chaîne ; le nouveau champ reste numérique.
    if (!is.null(x$ctp_kappa)) x$ctp_kappa <- suppressWarnings(as.numeric(x$ctp_kappa))
    x
  })
  ctp_res <- reactive({
    tryCatch(compute_ctp_scenario(ctp_inputs()),error=function(e) validate(need(FALSE,conditionMessage(e))))
  })
  ctp_balance <- reactive({
    tryCatch(compute_ctp_balance(ctp_res(),ctp_inputs()),error=function(e) validate(need(FALSE,conditionMessage(e))))
  })
  observeEvent(input$load_ctp_example, {
    x <- read_ctp_example()$inputs
    for (id in setdiff(ctp_input_names,"ctp_detailed")) updateNumericInput(session,id,value=x[[id]])
    updateCheckboxInput(session,"ctp_detailed",value=x$ctp_detailed)
    showNotification("Exemple Veille — CTP à 6 mois chargé. Tous les paramètres restent modifiables.",type="message")
  })
  ctp_fmt <- function(x,digits=NULL) {
    if (length(x)!=1 || is.na(x)) return("Non déterminé")
    if (is.null(digits)) digits <- if (abs(x-round(x)) < 1e-8) 0 else 2
    formatC(x,format="f",digits=digits,big.mark="\u202f",decimal.mark=",")
  }
  ctp_eur <- function(x) if (length(x)!=1 || is.na(x)) "Non déterminé" else paste0(ctp_fmt(x),"\u00a0€")
  output$ctp_c2_hint <- renderText({
    r <- ctp_res();x <- ctp_inputs()
    if (isTRUE(x$ctp_detailed)) paste0("Total retenu : ",ctp_eur(r$effective_c2),"/mois, sans majoration.")
    else paste0("Base ",ctp_eur(x$ctp_orch)," × ",ctp_fmt(x$ctp_kappa,2)," = ",ctp_eur(r$effective_c2),"/mois retenus.")
  })
  output$ctp_summary <- renderUI({
    r <- ctp_res();x <- ctp_inputs()
    metric <- function(label,value,id) div(class="monthly-metric",span(label),
      strong(ctp_eur(value),id=id,`data-value`=if(is.na(value)) "unknown" else value))
    tagList(p(strong(paste0("T = ",x$ctp_t," mois depuis le démarrage"))),
      div(class="monthly-metrics",
        metric("CTP d’exploitation",r$CTP,"ctp-exploitation"),
        metric("Investissement initial",r$investment,"ctp-investment"),
        metric("CTP du projet",r$project,"ctp-project")),
      if(is.na(r$investment)) p("Investissement inconnu : le coût d’exploitation reste calculable ; le CTP du projet et le solde après investissement ne sont pas déterminés.")
      else p(paste0(ctp_eur(r$CTP)," d’exploitation + ",ctp_eur(r$investment)," d’investissement initial = ",ctp_eur(r$project)," pour le projet.")))
  })
  output$ctp_breakdown <- renderTable({
    r <- ctp_res();x <- ctp_inputs()
    data.frame(Poste=c("C1 — Utilisation des modèles","C2 — Infrastructure logicielle","C3 — Travail humain","CTP d’exploitation","Investissement initial","CTP du projet"),
      Calcul=c(paste0(ctp_eur(x$ctp_c1_month)," × ",x$ctp_t," mois"),
        paste0(ctp_eur(r$effective_c2)," × ",x$ctp_t," mois"),
        paste0("(",r$calibration_months," × ",ctp_fmt(x$ctp_h1)," h + ",r$cruise_months," × ",ctp_fmt(x$ctp_h2)," h) × ",ctp_eur(x$ctp_w),"/h"),
        "C1 + C2 + C3","Une seule fois au démarrage","Exploitation + investissement"),
      `Montant sur T`=vapply(c(r$C1,r$C2,r$C3,r$CTP,r$investment,r$project),ctp_eur,character(1)),check.names=FALSE)
  },striped=TRUE,spacing="s",width="100%",rownames=FALSE)
  output$ctp_phase_hint <- renderText({
    r <- ctp_res();x <- ctp_inputs()
    if (x$ctp_calibration==0) return(paste0("Aucun calibrage simulé : croisière du mois 1 au mois ",x$ctp_t,"."))
    if (r$cruise_months==0) return(paste0("Tout l’horizon étudié est en calibrage (",r$calibration_months," mois). La croisière se situe après T."))
    paste0("Calibrage : mois 1 à ",r$calibration_months," ; croisière : mois ",r$calibration_months+1," à ",x$ctp_t,".")
  })
  output$plot_ctp_line <- renderPlotly({
    df <- ctp_res()$monthly
    df$Phase <- factor(df$Phase,levels=c("Calibrage","Croisière"))
    plot_ly(df,x=~Mois,y=~Total,color=~Phase,colors=c("#D4850F","#779FCB"),type="bar",
      hovertemplate="Mois %{x}<br>%{fullData.name} : %{y:.2f} €<extra></extra>") %>%
      layout(barmode="stack",font=list(color="white",family="system-ui, sans-serif"),
        plot_bgcolor="transparent",paper_bgcolor="transparent",margin=list(t=15,b=70,l=70,r=15),
        xaxis=list(title="Mois depuis le démarrage",dtick=1),yaxis=list(title="Coût du mois (€)",rangemode="tozero"),
        legend=list(orientation="h",x=0,y=-.3,title=list(text=""))) %>% config(displayModeBar=FALSE)
  })
  output$plot_ctp_cumulative <- renderPlotly({
    r <- ctp_res();m <- c(0,r$monthly$Mois)
    p <- plot_ly(x=m,y=c(0,r$monthly$Cumul_exploitation),type="scatter",mode="lines+markers",
      name="Exploitation",line=list(color="#779FCB"),hovertemplate="Mois %{x} : %{y:.2f} €<extra>Exploitation</extra>")
    if(!is.na(r$investment)) p <- add_trace(p,x=m,y=c(r$investment,r$monthly$Cumul_projet),
      name="Projet, investissement inclus",line=list(color="#D4850F"),hovertemplate="Mois %{x} : %{y:.2f} €<extra>Projet</extra>")
    layout(p,font=list(color="white",family="system-ui, sans-serif"),plot_bgcolor="transparent",paper_bgcolor="transparent",
      margin=list(t=15,b=75,l=70,r=15),xaxis=list(title="Mois — 0 : investissement initial",dtick=1),
      yaxis=list(title="Coût cumulé (€)",rangemode="tozero"),legend=list(orientation="h",x=0,y=-.3)) %>% config(displayModeBar=FALSE)
  })
  output$ctp_balance_summary <- renderUI({
    b <- ctp_balance();r <- ctp_res()
    tagList(p(paste0(ctp_fmt(b$manual_hours)," h manuelles − ",ctp_fmt(b$human_hours)," h avec le dispositif = ",ctp_fmt(b$net_hours)," h nettes sur T.")),
      p(paste0(ctp_fmt(b$reallocated_hours)," h réaffectées ; valeur conventionnelle : ",ctp_eur(b$value),".")),
      if (b$penalty>0) p(paste0("Surcharge dans certaines phases : ",ctp_eur(b$penalty)," de pénalité, comptée intégralement avant de sommer les phases.")),
      div(class="monthly-metric",span(paste0("Solde conventionnel sur ",ctp_inputs()$ctp_t," mois, après investissement")),
        strong(ctp_eur(b$balance),id="ctp-balance",`data-value`=if(is.na(b$balance)) "unknown" else b$balance)),
      if(is.na(r$investment)) p(paste0("Investissement inconnu. Solde avant investissement uniquement : ",ctp_eur(b$before_investment),"."))
      else p(paste0(ctp_eur(b$value)," de valeur réaffectée − ",ctp_eur(b$penalty)," de surcharge − ",ctp_eur(b$nonhuman)," de C1/C2 − ",ctp_eur(r$investment)," d’investissement = ",ctp_eur(b$balance),".")),
      p("C3 est déjà pris en compte dans le temps net : il n’est pas soustrait une seconde fois."))
  })
  output$ctp_balance_table <- renderTable({
    b <- ctp_balance();m <- b$monthly
    df <- data.frame(Mois=m$Mois,Phase=m$Phase,`Temps net (h)`=m$Capacite_nette,
      `Réaffecté (h)`=m$Heures_reaffectees,`Valeur (€)`=m$Valeur_reaffectee,
      `Surcharge (€)`=m$Penalite_surcharge,`Solde avant investissement (€)`=m$Solde_avant_investissement,check.names=FALSE)
    df[-c(1,2)] <- lapply(df[-c(1,2)],function(v) vapply(v,ctp_fmt,character(1)))
    df
  },striped=TRUE,digits=2,spacing="s",rownames=FALSE)
  output$ctp_monthly_table <- renderTable({
    m <- ctp_res()$monthly
    df <- data.frame(Mois=m$Mois,Phase=m$Phase,`Humain (h)`=m$Heures,`C1 (€)`=m$C1,`C2 (€)`=m$C2,
      `C3 (€)`=m$C3,`Total du mois (€)`=m$Total,`Exploitation cumulée (€)`=m$Cumul_exploitation,
      `Projet cumulé (€)`=m$Cumul_projet,check.names=FALSE)
    df[-c(1,2)] <- lapply(df[-c(1,2)],function(v) vapply(v,ctp_fmt,character(1)))
    df
  },striped=TRUE,digits=2,spacing="s",na="Non déterminé",rownames=FALSE)


}
