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
  
  output$plot_ctask <- renderPlot({
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
    
    ggplot(df_plot, aes(x = Scenario, y = C_task, fill = Type)) +
      geom_col(width = 0.5) +
      geom_text(aes(label = sprintf("%.2f €", C_task)), vjust = -0.5, color = "white", size = 5) +
      scale_fill_manual(values = c("Humain" = "#555555", "Agent IA" = "#D4850F")) +
      labs(y = "Coût Complet par Tâche (€)", x = "") +
      theme_minimal(base_size = 14) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background = element_rect(fill = "transparent", color = NA),
        text = element_text(color = "white"),
        axis.text = element_text(color = "white"),
        legend.position = "none"
      )
  }, bg = "transparent")
  
  output$plot_roi <- renderPlot({
    df_roi <- compute_roi(cost_manual_task(), cost_ia_task(), input$vol)
    
    ggplot(df_roi, aes(x = Mois, y = Cout_Cumule, color = Type)) +
      geom_line(linewidth = 1.5) +
      geom_point(size = 3) +
      scale_color_manual(values = c("Manuel" = "#555555", "Agent IA" = "#D4850F")) +
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
  }, bg = "transparent")
  
  # -- Onglet 2 : Télémétrie --
  
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
    
    # Aggregation compliance
    list_comp <- lapply(comp_files, parse_compliance_md)
    total_vol <- 0
    sum_vol_ps <- 0
    for(res in list_comp){
      total_vol <- total_vol + res$volume
      sum_vol_ps <- sum_vol_ps + (res$volume * res$success_rate)
    }
    avg_ps <- if(total_vol > 0) sum_vol_ps / total_vol else 0
    
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
      
      total_api_cost <- sum(mapply(
        compute_api_row,
        df_agg[['Modèle']],
        as.numeric(df_agg[['Prompt (In)']]),
        as.numeric(df_agg[['Cache (In)']]),
        as.numeric(df_agg[['Output']]),
        as.numeric(df_agg[['Thinking']])
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
    datatable(telemetry$df, options = list(pageLength = 5, dom = 't'))
  })
}
