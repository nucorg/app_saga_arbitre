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
    
    nav_panel("Manuel vs Agentique",
      layout_sidebar(
        sidebar = sidebar(
          title = "Paramètres de la Tâche",
          numericInput("vol", "Volume de tâches mensuel :", value = 50, min = 1),
          numericInput("time_h", "Temps unitaire manuel (min) :", value = 15, min = 1),
          numericInput("cost_h", "Coût marginal humain (€/h) :", value = 15, min = 1),
          numericInput("cost_tokens", "C\u2081 : Co\u00fbt des tokens par t\u00e2che :", value = 0.05, min = 0, step = 0.01),
          numericInput("cost_orch", "C\u2082 : Orchestration mensuelle (\u20ac) :", value = 0, min = 0),
          numericInput("maint_h", "C\u2083 : Maintenance IA mensuelle (heures) :", value = 2, min = 0),
          sliderInput("ps", HTML("Taux de succ\u00e8s (P<sub>s</sub>) % :"), min = 1, max = 100, value = 90),
          numericInput("build_ia", "Premier mois Agentique (\u20ac) :", value = 1200, min = 0),
          numericInput("build_manual", "Premier mois Manuel (\u20ac) :", value = 3500, min = 0),
          actionButton("add_scen", "Sauvegarder Scénario", class = "btn-primary")
        ),
        card(
          card_header(HTML("Comparatif des Coûts par Tâche (C<sub>task</sub>)")),
          plotlyOutput("plot_ctask")
        ),
        card(
          card_header("Point Mort & ROI Cumulé"),
          plotlyOutput("plot_roi")
        )
      )
    ),
    
    nav_panel("Télémétrie du Terrain",
      layout_columns(
        col_widths = c(4, 8),
        card(
          card_header("Import des logs"),
          selectInput("squad_dir", "1. Squad ciblé :", choices = NULL),
          selectInput("month_dir", "2. Période (Mois) :", choices = NULL),
          actionButton("process_logs", "Analyser la Télémétrie mensuelle", class = "btn-primary", width = "100%")
        ),
        card(
          card_header("Résultats Réels vs Théorie"),
          layout_columns(
            value_box("Volume Réel", uiOutput("real_vol"), theme_color = "primary"),
            value_box("Succès Réel", uiOutput("real_ps"), theme_color = "primary"),
            value_box("C_task Réel", uiOutput("real_ctask"), theme_color = "primary"),
            value_box("Décomposition", uiOutput("real_breakdown"), theme_color = "secondary")
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
