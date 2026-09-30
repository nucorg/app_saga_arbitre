saga_server <- function(input, output, session) {
  
  # -- Onglet 1 : Simulateur --
  
  # Stockage des scenarios
  scenarios_rv <- reactiveValues(data = list())
  
  # Calcul du cout humain unitaire
  cost_manual_task <- reactive({
    (input$time_h / 60) * input$cost_h
  })
  
  # Calcul du cout IA unitaire
  cost_ia_task <- reactive({
    if (is.null(input$vol) || input$vol <= 0) return(0)
    compute_cost(
      c_tokens = input$cost_tokens,
      c_infra = input$cost_orch / input$vol,
      c_revue_humaine = (input$maint_h * input$cost_h) / input$vol,
      p_s = input$ps / 100
    )
  })
  
  observeEvent(input$add_scen, {
    scen_id <- paste("Scénario", length(scenarios_rv$data) + 1)
    
    new_scen <- data.frame(
      Scenario = scen_id,
      C_task = cost_ia_task(),
      Type = "Agent IA"
    )
    scenarios_rv$data[[scen_id]] <- new_scen
  })
  
  output$plot_ctask <- renderPlotly({
    baselines <- data.frame(
      Scenario = c("Manuel"),
      C_task = c(cost_manual_task()),
      Type = c("Humain")
    )
    
    if (length(scenarios_rv$data) > 0) {
      scen_df <- bind_rows(scenarios_rv$data)
      df_plot <- bind_rows(baselines, scen_df)
    } else {
      df_plot <- baselines
      # Ajout du scenario en cours de simulation meme si non sauvegardé
      current <- data.frame(
        Scenario = "Simulation",
        C_task = cost_ia_task(),
        Type = "Agent IA"
      )
      df_plot <- bind_rows(df_plot, current)
    }
    
    p <- ggplot(df_plot, aes(x = Scenario, y = C_task, fill = Type)) +
      geom_col(width = 0.5) +
      geom_text(aes(label = sprintf("%.2f €", C_task)), vjust = -0.5, color = "white", size = 5) +
      scale_fill_manual(values = c("Humain" = "#FFFFFF", "Agent IA" = "#D4850F")) +
      labs(y = "Coût Complet par Tâche (€)", x = "") +
      theme_minimal(base_size = 14) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background = element_rect(fill = "transparent", color = NA),
        text = element_text(color = "white"),
        axis.text = element_text(color = "white"),
        legend.position = "none"
      )
    ggplotly(p, tooltip = c("x", "y")) %>% layout(plot_bgcolor="transparent", paper_bgcolor="transparent")
  })
  
  output$plot_roi <- renderPlotly({
    df_roi <- compute_roi(cost_manual_task(), cost_ia_task(), input$vol * input$ps / 100, input$build_ia, input$build_manual)
    
    p <- ggplot(df_roi, aes(x = Mois, y = Cout_Cumule, color = Type)) +
      geom_line(linewidth = 1.5) +
      geom_point(size = 3) +
      scale_color_manual(values = c("Manuel" = "#FFFFFF", "Agent IA" = "#D4850F")) +
      scale_x_continuous(breaks = 1:12) +
      labs(y = "Coût Cumulé (€)", x = "Mois") +
      theme_minimal(base_size = 14) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background = element_rect(fill = "transparent", color = NA),
        text = element_text(color = "white"),
        axis.text = element_text(color = "white"),
        legend.position = "bottom",
        legend.title = element_blank()
      )
    ggplotly(p, tooltip = c("x", "y")) %>% layout(
      plot_bgcolor="transparent", 
      paper_bgcolor="transparent",
      legend = list(orientation = "h", x = 0.5, y = -0.3, xanchor = "center", title = list(text = "")),
      margin = list(b = 60)
    )
  })
  
  # -- Onglet C1 --
  
  rv_pricing_trigger <- reactiveVal(0)
  
  pricing_data <- reactive({
    rv_pricing_trigger() # dependency
    read_api_pricing("data/pricing_models.csv")
  })
  
  # -- Onglet Prix API --
  rv_pricing_edit <- reactiveVal(isolate(read_api_pricing("data/pricing_models.csv")))
  
  output$table_pricing_edit <- renderDT({
    datatable(
      isolate(rv_pricing_edit()),
      editable = TRUE,
      rownames = FALSE,
      selection = "single",
      options = list(pageLength = 100, dom = "tip", scrollX = TRUE)
    )
  })
  
  proxy_pricing_edit <- dataTableProxy("table_pricing_edit")
  
  observeEvent(input$add_row, {
    df <- rv_pricing_edit()
    new_row <- data.frame(
      Identifiant = "Nouveau Modèle",
      Fournisseur = "",
      p_in_1M = 0,
      p_out_1M = 0,
      p_cache_1M = NA_real_,
      date_verification = Sys.Date(),
      stringsAsFactors = FALSE
    )
    # Remplir avec des NAs pour correspondre au dataframe
    for (col in names(df)) {
      if (!col %in% names(new_row)) new_row[[col]] <- NA
    }
    new_row <- new_row[, names(df), drop = FALSE]
    
    # Insérer en HAUT (ligne 1) pour qu'il soit immédiatement visible
    new_df <- rbind(new_row, df)
    rv_pricing_edit(new_df)
    replaceData(proxy_pricing_edit, new_df, resetPaging = FALSE, rownames = FALSE)
  })
  
  observeEvent(input$delete_row, {
    selected <- input$table_pricing_edit_rows_selected
    if (length(selected) > 0) {
      df <- rv_pricing_edit()
      new_df <- df[-selected, , drop = FALSE]
      rv_pricing_edit(new_df)
      replaceData(proxy_pricing_edit, new_df, resetPaging = FALSE, rownames = FALSE)
    } else {
      showNotification("Veuillez sélectionner une ligne à supprimer.", type = "warning")
    }
  })
  
  observeEvent(input$table_pricing_edit_cell_edit, {
    info <- input$table_pricing_edit_cell_edit
    edit_data <- rv_pricing_edit()
    edit_data[info$row, info$col + 1] <- DT::coerceValue(info$value, edit_data[info$row, info$col + 1])
    rv_pricing_edit(edit_data)
    replaceData(proxy_pricing_edit, edit_data, resetPaging = FALSE, rownames = FALSE)
  })
  
  observeEvent(input$save_pricing, {
    save_api_pricing(rv_pricing_edit(), "data/pricing_models.csv")
    rv_pricing_trigger(rv_pricing_trigger() + 1)
    showNotification("Fichier CSV Prix API mis à jour avec succès !", type = "message")
  })
  
  observe({
    models <- sort(pricing_data()$Identifiant)
    if (length(models) > 0) {
      updateSelectInput(session, "c1_mod_a", choices = models, selected = models[1])
      updateSelectInput(session, "c1_mod_b", choices = models, selected = models[min(2, length(models))])
      updateSelectInput(session, "c1_mod_c", choices = models, selected = models[min(3, length(models))])
    }
  })
  
  output$table_c1_pricing <- renderDT({
    df <- pricing_data()
    req(input$c1_usd_eur)
    
    # Create display dataframe with EUR conversion
    df_disp <- df
    df_disp$p_in_1M <- df_disp$p_in_1M * input$c1_usd_eur
    df_disp$p_out_1M <- df_disp$p_out_1M * input$c1_usd_eur
    
    # Rename columns to clearly state currency
    names(df_disp)[names(df_disp) == "p_in_1M"] <- "p_in_1M (\u20ac)"
    names(df_disp)[names(df_disp) == "p_out_1M"] <- "p_out_1M (\u20ac)"
    
    datatable(df_disp, options = list(pageLength = 5, dom = 'tip', order = list(list(1, 'asc')))) %>%
      formatRound(columns = c("p_in_1M (\u20ac)", "p_out_1M (\u20ac)"), digits = 3)
  })
  
  output$plot_c1_compare <- renderPlotly({
    req(input$c1_mod_a, input$c1_mod_b, input$c1_mod_c, input$c1_usd_eur)
    df_price <- pricing_data()
    
    calc_c1 <- function(mod_id) {
      row <- df_price[df_price$Identifiant == mod_id, ]
      if(nrow(row) == 0) return(0)
      cost_usd <- (row$p_in_1M * input$c1_n_in + row$p_out_1M * input$c1_n_out) / 1000000
      cost_usd * input$c1_usd_eur
    }
    
    res <- data.frame(
      Scenario = c("A", "B", "C"),
      Modele = c(input$c1_mod_a, input$c1_mod_b, input$c1_mod_c),
      C1 = c(calc_c1(input$c1_mod_a), calc_c1(input$c1_mod_b), calc_c1(input$c1_mod_c))
    )
    res$Label <- paste0(res$Scenario, " : ", res$Modele)
    
    p <- ggplot(res, aes(x = Label, y = C1, fill = Scenario)) +
      geom_col(width = 0.5) +
      scale_fill_manual(values = c("A" = "#D4850F", "B" = "#FFFFFF", "C" = "#F5B041")) +
      labs(y = "Coût C1 par tâche (€)", x = "") +
      theme_minimal(base_size = 14) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background = element_rect(fill = "transparent", color = NA),
        text = element_text(color = "white"),
        axis.text = element_text(color = "white"),
        legend.position = "none"
      )
    ggplotly(p, tooltip = c("y")) %>% layout(plot_bgcolor="transparent", paper_bgcolor="transparent")
  })
  
  # -- Onglet C2 (Test Infra) --
  
  infra_data <- reactive({
    if (file.exists("data/pricing_infra.csv")) {
      read.csv("data/pricing_infra.csv", stringsAsFactors = FALSE)
    } else {
      data.frame(Pilier=character(), Service=character(), Type_Facturation=character(), Prix_USD=numeric(), Unite=character())
    }
  })
  
  observe({
    df <- infra_data()
    df_fixe <- df[df$Type_Facturation == "Fixe", ]
    df_var <- df[df$Type_Facturation == "Variable", ]
    
    if (nrow(df) > 0) {
      choices_fixe <- setNames(df_fixe$Service, paste0(df_fixe$Service, " (~$", df_fixe$Prix_USD, "/", df_fixe$Unite, ")"))
      choices_var <- setNames(df_var$Service, paste0(df_var$Service, " (~$", df_var$Prix_USD, "/", df_var$Unite, ")"))
      
      output$ui_c2_fixed_choices <- renderUI({
        checkboxGroupInput("c2_fixed_sel", "Services Fixes (Base) :", choices = choices_fixe, selected = df_fixe$Service)
      })
      
      output$ui_c2_var_choices <- renderUI({
        checkboxGroupInput("c2_var_sel", "Services Variables (Par Tâche) :", choices = choices_var, selected = df_var$Service)
      })
    }
  })
  
  output$table_c2_pricing <- renderDT({
    df <- infra_data()
    req(input$c2_usd_eur)
    df$Prix_EUR <- df$Prix_USD * input$c2_usd_eur
    datatable(df, options = list(pageLength = 10, dom = 'tip')) %>%
      formatRound(columns = c("Prix_USD", "Prix_EUR"), digits = 3)
  })
  
  c2_computation <- reactive({
    df <- infra_data()
    req(input$c2_usd_eur, input$c2_v)
    
    # Filter selected
    df_selected_fixe <- df[df$Service %in% input$c2_fixed_sel, ]
    df_selected_var <- df[df$Service %in% input$c2_var_sel, ]
    
    # Computed in EUR
    total_fixe_eur <- sum(df_selected_fixe$Prix_USD, na.rm=TRUE) * input$c2_usd_eur
    total_var_unit_eur <- sum(df_selected_var$Prix_USD, na.rm=TRUE) * input$c2_usd_eur
    total_var_month_eur <- total_var_unit_eur * input$c2_v
    
    total_month <- total_fixe_eur + total_var_month_eur
    
    # Breakdown for plotting
    df_selected <- rbind(df_selected_fixe, df_selected_var)
    df_selected$Cost_Mensuel_USD <- ifelse(df_selected$Type_Facturation == "Fixe", df_selected$Prix_USD, df_selected$Prix_USD * input$c2_v)
    df_selected$Cost_Mensuel_EUR <- df_selected$Cost_Mensuel_USD * input$c2_usd_eur
    
    df_agg <- aggregate(Cost_Mensuel_EUR ~ Pilier, data = df_selected, sum)
    
    list(fixe = total_fixe_eur, var_month = total_var_month_eur, total = total_month, df_agg = df_agg)
  })
  
  output$vb_c2_fixe_val <- renderUI({ h3(sprintf("%.2f €", c2_computation()$fixe)) })
  output$vb_c2_var_val <- renderUI({ h3(sprintf("%.2f €", c2_computation()$var_month)) })
  output$vb_c2_total_val <- renderUI({ h2(sprintf("%.2f €", c2_computation()$total), style="margin:0;") })
  
  output$plot_c2_breakdown <- renderPlotly({
    req(c2_computation()$df_agg)
    df_plot <- c2_computation()$df_agg
    p <- ggplot(df_plot, aes(x = Pilier, y = Cost_Mensuel_EUR)) +
      geom_col(fill = "#D4850F") +
      labs(y = "Coût C2 Mensuel (€)", x = "") +
      theme_minimal(base_size = 14) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background = element_rect(fill = "transparent", color = NA),
        text = element_text(color = "white"),
        axis.text = element_text(color = "white"),
        axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "none"
      )
    ggplotly(p, tooltip = c("y")) %>% layout(plot_bgcolor="transparent", paper_bgcolor="transparent")
  })
  
  # -- Onglet C3 (Test Humain) --
  
  c3_computation <- reactive({
    req(input$c3_v, input$c3_h1_input, input$c3_escalade, input$c3_t_reprise)
    
    h1_val <- input$c3_h1_input
    h2_val <- compute_h2_cruise(
      volume_mensuel = input$c3_v,
      taux_escalade = as.numeric(input$c3_escalade) / 100,
      temps_reprise_minutes = input$c3_t_reprise,
      review_minutes = input$c3_review, governance_hours = input$c3_governance
    )
    
    list(h1 = h1_val, h2 = h2_val, w = input$c3_w)
  })
  
  output$vb_c3_h1 <- renderUI({ h3(sprintf("%.1f h", c3_computation()$h1)) })
  output$vb_c3_h2 <- renderUI({ h3(sprintf("%.1f h", c3_computation()$h2)) })
  
  output$plot_c3_asym <- renderPlotly({
    res <- c3_computation()
    
    df_plot <- data.frame(
      Phase = c("Phase 1 : Calibrage (M1-M3)", "Phase 2 : Croisière (M4+)"),
      Heures = c(res$h1, res$h2),
      Cout_Eur = c(res$h1 * res$w, res$h2 * res$w)
    )
    df_plot$Label <- paste0(df_plot$Phase, "\n", df_plot$Heures, "h/mois")
    
    p <- ggplot(df_plot, aes(x = Phase, y = Cout_Eur, fill = Phase)) +
      geom_col(width = 0.5) +
      scale_fill_manual(values = c("Phase 1 : Calibrage (M1-M3)" = "#D4850F", "Phase 2 : Croisière (M4+)" = "#FFFFFF")) +
      labs(y = "Coût C3 Mensuel (€)", x = "") +
      theme_minimal(base_size = 14) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background = element_rect(fill = "transparent", color = NA),
        text = element_text(color = "white"),
        axis.text = element_text(color = "white"),
        legend.position = "none"
      )
    ggplotly(p, tooltip = c("y")) %>% layout(plot_bgcolor="transparent", paper_bgcolor="transparent")
  })
  
  # -- Onglet CTP --
  
  ctp_res <- reactive({
    compute_ctp_totals(
      c = input$ctp_c,
      v = input$ctp_v,
      t_horizon = input$ctp_t,
      c_orch = input$ctp_orch,
      kappa = if (isTRUE(input$ctp_detailed)) 1 else as.numeric(input$ctp_kappa),
      w = input$ctp_w,
      h1 = input$ctp_h1,
      h2 = input$ctp_h2
    )
  })
  
  output$vb_c1_val <- renderUI({ h3(sprintf("%.0f €", ctp_res()$C1)) })
  output$vb_c2_val <- renderUI({ h3(sprintf("%.0f €", ctp_res()$C2)) })
  output$vb_c3_val <- renderUI({ h3(sprintf("%.0f €", ctp_res()$C3)) })
  output$vb_ctp_val <- renderUI({ h2(sprintf("%.0f €", ctp_res()$CTP), style="margin:0;") })
  
  output$plot_ctp_donut <- renderPlotly({
    res <- ctp_res()
    df <- data.frame(
      Couche = c("C1 - API", "C2 - Infra", "C3 - Humain"),
      Cout = c(res$C1, res$C2, res$C3)
    )
    plot_ly(df, labels = ~Couche, values = ~Cout, type = 'pie', textinfo = 'label+percent',
            marker = list(colors = c("#D4850F", "#FFFFFF", "#F5B041")),
            hole = 0.4) %>%
      layout(showlegend = FALSE, plot_bgcolor='transparent', paper_bgcolor='transparent',
             margin = list(t = 20, b = 20, l = 20, r = 20))
  })
  
  output$plot_ctp_line <- renderPlotly({
    df_monthly <- compute_ctp_monthly(
      c = input$ctp_c,
      v = input$ctp_v,
      t_horizon = input$ctp_t,
      c_orch = input$ctp_orch,
      kappa = if (isTRUE(input$ctp_detailed)) 1 else as.numeric(input$ctp_kappa),
      w = input$ctp_w,
      h1 = input$ctp_h1,
      h2 = input$ctp_h2
    )
    
    p <- ggplot(df_monthly, aes(x = Mois, y = Total)) +
      geom_line(color = "#D4850F", linewidth = 1.5) +
      geom_point(color = "#D4850F", size = 3) +
      {if(input$ctp_t > 3) geom_vline(xintercept = 3.5, linetype = "dashed", color = "gray50")} +
      labs(x = "Mois", y = "Coût Mensuel (€)") +
      scale_x_continuous(breaks = 1:input$ctp_t) +
      theme_minimal(base_size = 14) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background = element_rect(fill = "transparent", color = NA),
        text = element_text(color = "white"),
        axis.text = element_text(color = "white"),
        panel.grid.minor = element_blank()
      )
    ggplotly(p, tooltip = c("x", "y")) %>% layout(plot_bgcolor="transparent", paper_bgcolor="transparent")
  })
  
  # -- Cas de référence, mêmes définitions pour les deux visions --
  observeEvent(input$case_preset, {
    enterprise <- identical(input$case_preset, "enterprise")
    vals <- if (enterprise) list(volume=1200, accepted=1200, manual=30, review=5,
      rework=.2, rework_min=15, governance=40, hourly=60, api=.5, infra=2400,
      investment=36000, amort=24, alpha=.5, value=60, calibration=3, h1=300, horizon=12)
    else list(volume=150, accepted=150, manual=45, review=5, rework=.1,
      rework_min=15, governance=4, hourly=15, api=.05, infra=218,
      investment=0, amort=24, alpha=.5, value=15, calibration=3, h1=30, horizon=12)
    for (name in names(vals)) updateNumericInput(session, paste0("case_", name), value=vals[[name]])
  })
  case_result <- reactive({
    req(!is.null(input$case_volume), input$case_amort, input$case_horizon, cancelOutput = FALSE)
    tryCatch(compute_scenario(volume=input$case_volume, accepted=input$case_accepted,
      manual_minutes=input$case_manual, review_minutes=input$case_review,
      rework_rate=input$case_rework, rework_minutes=input$case_rework_min,
      governance_hours=input$case_governance, hourly_cost=input$case_hourly,
      api_per_input=input$case_api, infra_month=input$case_infra,
      investment=input$case_investment, amort_months=input$case_amort,
      horizon=input$case_horizon, alpha=input$case_alpha, value_hour=input$case_value,
      calibration_months=input$case_calibration, calibration_hours=input$case_h1),
      error=function(e) { validate(need(FALSE, conditionMessage(e))) })
  })
  output$case_results <- renderTable({
    r <- case_result()
    data.frame(Indicateur=c("Manuel h/mois", "Humain résiduel h/mois", "Temps net h/mois",
      "Temps réaffectable h/mois", "C1 EUR/mois", "C2 analytique EUR/mois", "C3 EUR/mois",
      "CTP analytique EUR/mois", "EUR / résultat accepté", "Solde conventionnel EUR/mois",
      "Solde conventionnel sur horizon EUR", "Coût sur horizon EUR (investissement inclus une fois)"),
      Valeur=unlist(r[c("h0","h2","net_hours","reallocated_hours","C1","C2","C3","CTP",
        "cost_accepted","balance","horizon_balance","horizon_cost")]))
  }, digits=2)
  output$case_coverage <- renderText({
    if (!case_result()$comparable_coverage)
      "Couverture incomplète : le solde ne démontre pas une équivalence de service avec le manuel."
    else "Couverture nominale identique supposée ; qualité finale à vérifier sur un lot indépendant."
  })

  # -- Télémétrie : pas de prix deviné, ni de zéro substitué à une donnée manquante --
  raw_telemetry <- reactiveVal(list(billing=NULL, compliance=list(), error=NULL))
  observe({
    if (dir.exists("telemetry")) updateSelectInput(session, "squad_dir",
      choices=list.dirs("telemetry", recursive=FALSE, full.names=FALSE))
  })
  observeEvent(input$squad_dir, {
    req(input$squad_dir)
    updateSelectInput(session, "month_dir", choices=list.dirs(file.path("telemetry", input$squad_dir), recursive=FALSE, full.names=FALSE))
    raw_telemetry(list(billing=NULL, compliance=list(), error=NULL))
  })
  observeEvent(input$month_dir, { raw_telemetry(list(billing=NULL, compliance=list(), error=NULL)) })
  observeEvent(input$process_logs, {
    req(input$squad_dir, input$month_dir)
    target <- file.path("telemetry", input$squad_dir, input$month_dir)
    bills <- list.files(target, pattern="cout_carbone_.*[.]md$", full.names=TRUE)
    comps <- list.files(target, pattern=".*_squad_.*[.]md$", full.names=TRUE)
    tryCatch({
      if (anyDuplicated(unname(tools::md5sum(bills))) || anyDuplicated(unname(tools::md5sum(comps))))
        stop("Journaux identiques détectés : dédoublonner avant calcul.")
      dfs <- lapply(bills, parse_billing_md)
      if (any(vapply(dfs, is.null, logical(1)))) stop("Un journal de facturation est illisible.")
      raw_telemetry(list(billing=if (length(dfs)) do.call(rbind, dfs) else NULL,
        compliance=lapply(comps, parse_compliance_md), error=NULL))
    }, error=function(e) raw_telemetry(list(billing=NULL, compliance=list(), error=conditionMessage(e))))
  })
  telemetry_result <- reactive({
    raw <- raw_telemetry()
    res <- compute_telemetry(raw$billing, raw$compliance, pricing_data(),
      usd_eur_rate=input$telemetry_fx, cache_ratio=input$cache_discount,
      infra_eur=input$cost_orch, human_hours=input$maint_h, hourly_cost=input$cost_h,
      confirmed=isTRUE(input$telemetry_confirm),
      prompt_includes_cache=isTRUE(input$telemetry_prompt_cache),
      output_includes_thinking=isTRUE(input$telemetry_output_thinking))
    if (!is.null(raw$error)) res$status <- raw$error
    if (any(vapply(raw$compliance, function(x) identical(x$basis, "legacy_rate_estimate"), logical(1))))
      res$status <- paste(res$status, "Acceptés estimés d'après le taux historique arrondi, à confirmer comme taux final.")
    res
  })
  fmt <- function(x, unit="") {
    if (length(x) != 1 || is.na(x)) "Données manquantes"
    else if (!is.finite(x)) "Non fini : aucun accepté"
    else paste0(format(round(x, 2), trim=TRUE), unit)
  }
  output$real_vol <- renderUI({ fmt(telemetry_result()$volume) })
  output$real_ps <- renderUI({ fmt(100 * telemetry_result()$ps, " %") })
  output$real_ctask <- renderUI({ fmt(telemetry_result()$ctask, " EUR") })
  output$telemetry_status <- renderText({ telemetry_result()$status })
  output$real_breakdown <- renderUI({
    r <- telemetry_result()
    tags$p(paste("Totaux période : API", fmt(r$api_eur, " EUR"), "; C2", fmt(r$infra_eur, " EUR"),
      "; humain", fmt(r$human_eur, " EUR"), "; acceptés", fmt(r$accepted)))
  })
  output$table_billing <- renderDT({
    req(raw_telemetry()$billing)
    datatable(raw_telemetry()$billing, options=list(pageLength=15, dom="t"))
  })
}
