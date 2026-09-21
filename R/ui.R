saga_ui <- function() {
  page_navbar(
    title = "SAGA Arbitre - Calculateur IA",
    theme = bs_theme(
      bg = "#1E1E1E", fg = "#FFFFFF", primary = "#D4850F",
      base_font = font_google("Inter", local = FALSE)
    ),
    
    # Activation de MathJax pour les formules
    header = tags$head(
      tags$script(src = "https://polyfill.io/v3/polyfill.min.js?features=es6"),
      tags$script(id = "MathJax-script", async = NA, src = "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js")
    ),
    
    nav_panel("Simulateur & Comparaison",
      layout_sidebar(
        sidebar = sidebar(
          title = "Paramètres de la Tâche",
          numericInput("vol", "Volume mensuel (V) :", value = 1000, min = 1),
          numericInput("time_h", "Temps unitaire manuel (min) :", value = 15, min = 1),
          numericInput("cost_h", "Coût marginal humain (/h) :", value = 30, min = 1),
          numericInput("cost_orch", "Coût d'orchestration (C_orch) :", value = 500, min = 0),
          numericInput("cost_tokens", "Coût des tokens par tâche :", value = 0.05, min = 0, step = 0.01),
          sliderInput("ps", "Taux de succès (P_s) % :", min = 1, max = 100, value = 90),
          actionButton("add_scen", "Sauvegarder Scénario", class = "btn-primary")
        ),
        card(
          card_header("Comparatif des Coûts par Tâche ($C_{task}$)"),
          plotOutput("plot_ctask")
        ),
        card(
          card_header("Point Mort & ROI Cumulé"),
          plotOutput("plot_roi")
        )
      )
    ),
    
    nav_panel("Télémétrie du Terrain",
      layout_columns(
        col_widths = c(4, 8),
        card(
          card_header("Import des logs H4E"),
          fileInput("file_bill", "1. Rapport de facturation (.md)"),
          fileInput("file_comp", "2. Rapport de conformité (.md)"),
          actionButton("process_logs", "Analyser la Télémétrie", class = "btn-primary", width = "100%")
        ),
        card(
          card_header("Résultats Réels vs Théorie"),
          layout_columns(
            value_box("Volume Réel", uiOutput("real_vol"), theme_color = "primary"),
            value_box("Succès Réel", uiOutput("real_ps"), theme_color = "primary"),
            value_box("C_task Réel", uiOutput("real_ctask"), theme_color = "primary")
          ),
          markdown("#### Données brutes de facturation (Extrait)"),
          DTOutput("table_billing")
        )
      )
    ),
    
    nav_panel("Référentiel Pédagogique",
      card(
        card_header("Formules & Doctrine"),
        shiny::markdown("
### 1. Le paradoxe franco-américain
*La substitution d'un salaire en inférence transforme des charges taxées (masse salariale) en OpEx purs sans cotisations.*

### 2. La Fiabilité Composée
$$P_{s} = (p)^N$$
(Où N est le nombre d'étapes d'une chaîne agentique).

### 3. Le Coût par Tâche Acceptée ($C_{task}$)
$$C_{task} = \\frac{\\sum (C_{tokens}) + C_{infra} + C_{revue\\_humaine}}{P_{s}}$$
        ")
      )
    )
  )
}
