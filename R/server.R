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
      c_revue_humaine = 0, # Simplification
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
  
  telemetry <- reactiveValues(df = NULL, vol = 0, ps = 0, ctask = 0)
  
  observeEvent(input$process_logs, {
    req(input$file_bill, input$file_comp)
    
    df_bill <- parse_billing_md(input$file_bill$datapath)
    comp_res <- parse_compliance_md(input$file_comp$datapath)
    
    telemetry$df <- df_bill
    telemetry$vol <- comp_res$volume
    telemetry$ps <- comp_res$success_rate
    
    # Calcul mock up du Ctask si on a des données de billing
    if (!is.null(df_bill) && nrow(df_bill) > 0 && ncol(df_bill) >= 2) {
      # On cherche la colonne contenant le cout. On assume que c'est la dernière ou l'avant dernière avec des chiffres.
      # Pour faire simple, on essaie de sommer la derniere colonne.
      cost_col <- ncol(df_bill)
      total_tokens_cost <- sum(as.numeric(df_bill[[cost_col]]), na.rm = TRUE)
      
      c_infra <- input$cost_orch / max(1, telemetry$vol) # on utilise C_orch configuré dans l'onglet 1
      
      telemetry$ctask <- compute_cost(
        c_tokens = total_tokens_cost / max(1, telemetry$vol), 
        c_infra = c_infra, 
        c_revue_humaine = 0, 
        p_s = max(0.01, telemetry$ps/100)
      )
    }
  })
  
  output$real_vol <- renderUI({ telemetry$vol })
  output$real_ps <- renderUI({ paste0(telemetry$ps, " %") })
  output$real_ctask <- renderUI({ paste0(round(telemetry$ctask, 4), " €") })
  
  output$table_billing <- renderDT({
    req(telemetry$df)
    datatable(telemetry$df, options = list(pageLength = 5, dom = 't'))
  })
}
