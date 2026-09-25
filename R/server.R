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
    df_roi <- compute_roi(cost_manual_task(), cost_ia_task(), input$vol, input$build_ia, input$build_manual)
    
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
  
  pricing_data <- reactive({
    if (file.exists("data/pricing_models.csv")) {
      read.csv("data/pricing_models.csv", stringsAsFactors = FALSE)
    } else {
      data.frame(Identifiant = character(), Fournisseur = character(), p_in_1M = numeric(), p_out_1M = numeric())
    }
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
      temps_reprise_minutes = input$c3_t_reprise
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
      kappa = as.numeric(input$ctp_kappa),
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
      kappa = as.numeric(input$ctp_kappa),
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
  
  # -- Onglet 3 : Télémétrie --
  
  telemetry <- reactiveValues(df = NULL, vol = 0, ps = 0, ctask = 0, c_infra = 0, c_tokens = 0, c_maint = 0)
  # Logic for dynamic dropdowns
  base_telemetry_dir <- 'telemetry'
  observe({
    if(dir.exists(base_telemetry_dir)){
      squads <- list.dirs(base_telemetry_dir, recursive=FALSE, full.names=FALSE)
      updateSelectInput(session, 'squad_dir', choices = squads)
    }
  })
  
  observeEvent(input$squad_dir, {
    if(input$squad_dir != '') {
      squad_path <- file.path(base_telemetry_dir, input$squad_dir)
      months <- list.dirs(squad_path, recursive=FALSE, full.names=FALSE)
      updateSelectInput(session, 'month_dir', choices = months)
    }
  })
  
  observeEvent(input$process_logs, {
    req(input$squad_dir, input$month_dir)
    
    target_dir <- file.path(base_telemetry_dir, input$squad_dir, input$month_dir)
    if(!dir.exists(target_dir)) return(NULL)
    
    bill_files <- list.files(target_dir, pattern = 'cout_carbone_.*\\.md$', full.names = TRUE)
    comp_files <- list.files(target_dir, pattern = '.*_squad_.*\\.md$', full.names = TRUE)
    
    # Aggregation billing
    list_df <- lapply(bill_files, parse_billing_md)
    # Keep only non-nulls and non-empties
    list_df <- list_df[sapply(list_df, function(x) !is.null(x) && nrow(x) > 0)]
    
    if(length(list_df) == 0) return(NULL)
    
    # Remove TOTAL rows and bind rows to aggregate
    df_all <- do.call(rbind, lapply(list_df, function(df) df[!grepl('^TOTAL', df[['Rôle (Task)']], ignore.case=TRUE), ]))
    
    # Group by Role and Model to sum metrics
    library(dplyr)
    library(dplyr)
    df_agg <- df_all %>% 
      group_by(`Rôle (Task)`, `Modèle`) %>%
      summarise(
        Reqs = sum(Reqs, na.rm=TRUE),
        `Prompt (In)` = sum(`Prompt (In)`, na.rm=TRUE),
        `Cache (In)` = sum(`Cache (In)`, na.rm=TRUE),
        Output = sum(Output, na.rm=TRUE),
        Thinking = sum(Thinking, na.rm=TRUE),
        .groups = 'drop'
      ) %>% 
      ungroup()
      
    list_comp <- lapply(comp_files, parse_compliance_md)
    total_vol <- 0
    sum_vol_ps <- 0
    for(res in list_comp){
      total_vol <- total_vol + res$volume
      sum_vol_ps <- sum_vol_ps + (res$volume * res$success_rate)
    }
    avg_ps <- if(total_vol > 0) sum_vol_ps / total_vol else 0
    
    if (nrow(df_agg) > 0) {
      tot_row <- data.frame(
        `Rôle (Task)` = "TOTAL GÉNÉRAL",
        `Modèle` = "",
        Reqs = sum(df_agg$Reqs, na.rm = TRUE),
        `Prompt (In)` = sum(df_agg$`Prompt (In)`, na.rm = TRUE),
        `Cache (In)` = sum(df_agg$`Cache (In)`, na.rm = TRUE),
        Output = sum(df_agg$Output, na.rm = TRUE),
        Thinking = sum(df_agg$Thinking, na.rm = TRUE),
        check.names = FALSE
      )
      
      tot_in <- tot_row$`Prompt (In)` + (tot_row$`Cache (In)` * 0.25)
      tot_out <- tot_row$Output + tot_row$Thinking
      
      equiv_row <- data.frame(
        `Rôle (Task)` = "ÉQUIVALENT IN/OUT (BATCH)",
        `Modèle` = "",
        Reqs = NA,
        `Prompt (In)` = tot_in,
        `Cache (In)` = NA,
        Output = tot_out,
        Thinking = NA,
        check.names = FALSE
      )
      
      equiv_unit <- data.frame(
        `Rôle (Task)` = "ÉQUIVALENT IN/OUT (UNITAIRE)",
        `Modèle` = "Copier vers C1 / CTP ->",
        Reqs = NA,
        `Prompt (In)` = if (total_vol > 0) tot_in / total_vol else tot_in,
        `Cache (In)` = NA,
        Output = if (total_vol > 0) tot_out / total_vol else tot_out,
        Thinking = NA,
        check.names = FALSE
      )
      
      df_agg <- rbind(df_agg, tot_row, equiv_row, equiv_unit)
    }
    
    # Aggregation compliance
    telemetry$df <- df_agg
    telemetry$vol <- total_vol
    telemetry$ps <- round(avg_ps, 1)
    
    if(nrow(df_agg) > 0) {
      compute_api_row <- function(mod, p_in, c_in, out, thk) {
        if (is.na(p_in)) p_in <- 0
        if (is.na(c_in)) c_in <- 0
        if (is.na(out)) out <- 0
        if (is.na(thk)) thk <- 0
        
        if (grepl('pro', mod, ignore.case=TRUE)) {
          prix_in <- 1.25; prix_out <- 5.00
        } else if (grepl('flash', mod, ignore.case=TRUE)) {
          prix_in <- 0.075; prix_out <- 0.30
        } else {
          prix_in <- 1.00; prix_out <- 4.00
        }
        
        cost_in <- (p_in * prix_in + c_in * (prix_in * 0.25)) / 1000000
        cost_out <- ((out + thk) * prix_out) / 1000000
        cost_in + cost_out
      }
      
      compute_rows <- df_agg[!grepl('TOTAL GÉNÉRAL|ÉQUIVALENT', df_agg[['Rôle (Task)']], ignore.case=TRUE), ]
      total_api_cost <- sum(mapply(
        compute_api_row,
        compute_rows[['Modèle']],
        as.numeric(compute_rows[['Prompt (In)']]),
        as.numeric(compute_rows[['Cache (In)']]),
        as.numeric(compute_rows[['Output']]),
        as.numeric(compute_rows[['Thinking']])
      ))
      
      c_infra <- input$cost_orch / max(1, telemetry$vol)
      c_tokens_unitaire <- total_api_cost / max(1, telemetry$vol)
      c_maint <- (input$maint_h * input$cost_h) / max(1, telemetry$vol)
      
      telemetry$c_infra <- c_infra
      telemetry$c_tokens <- c_tokens_unitaire
      telemetry$c_maint <- c_maint
      
      telemetry$ctask <- compute_cost(
        c_tokens = c_tokens_unitaire, 
        c_infra = c_infra, 
        c_revue_humaine = c_maint, 
        p_s = max(0.01, telemetry$ps/100)
      )
    }
  })
  
  output$real_vol <- renderUI({ telemetry$vol })
  output$real_ps <- renderUI({ paste0(telemetry$ps, " %") })
  output$real_ctask <- renderUI({ sprintf("%.2f €", telemetry$ctask) })
  
  output$real_breakdown <- renderUI({
    if (telemetry$vol == 0) return(tags$span("En attente de données..."))
    HTML(sprintf(
      "<div style='font-size: 0.35em; line-height: 1.2; color: #FFFFFF; font-weight: normal;'>
       <strong>C\u2081 (API) :</strong> %.2f €<br/>
       <strong>C\u2082 (Infra) :</strong> %.2f €<br/>
       <strong>C\u2083 (Maint) :</strong> %.2f €<br/>
       <strong>P<sub>s</sub> (Succès) :</strong> %.2f<br/>
       <hr style='margin: 4px 0; border-color: rgba(255,255,255,0.2);'/>
       <i>(%.2f + %.2f + %.2f) &divide; %.2f</i>
       </div>",
       telemetry$c_tokens, 
       telemetry$c_infra,
       telemetry$c_maint,
       telemetry$ps / 100,
       telemetry$c_tokens,
       telemetry$c_infra,
       telemetry$c_maint,
       telemetry$ps / 100
    ))
  })
  
  output$table_billing <- renderDT({
    req(telemetry$df)
    datatable(telemetry$df, options = list(pageLength = 15, dom = 't'))
  })
}
