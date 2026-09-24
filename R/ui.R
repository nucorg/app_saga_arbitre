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

    nav_panel("C1 - Test Inférence",
      layout_sidebar(
        sidebar = sidebar(
          title = "Paramètres de la Tâche",
          numericInput("c1_n_in", "Jetons en Entrée (n_in) :", value = 8000, min = 1),
          numericInput("c1_n_out", "Jetons en Sortie (n_out) :", value = 1500, min = 1),
          numericInput("c1_usd_eur", "Taux (1 USD en EUR) :", value = 0.88, min = 0, step = 0.01),
          hr(),
          p(strong("Configuration des Scénarii")),
          selectInput("c1_mod_a", "Modèle A :", choices = NULL),
          selectInput("c1_mod_b", "Modèle B :", choices = NULL),
          selectInput("c1_mod_c", "Modèle C :", choices = NULL)
        ),
        card(
          card_header("Comparatif Brut de l'Inférence (C1) par Tâche"),
          plotlyOutput("plot_c1_compare")
        ),
        card(
          card_header("Grille Tarifaire Locale"),
          DTOutput("table_c1_pricing")
        )
      )
    ),

    nav_panel("Diagnostic d'Investissement (CTP)",
      layout_sidebar(
        sidebar = sidebar(
          title = "Paramètres du Dispositif",
          sliderInput("ctp_t", "Horizon temporel (mois) :", min = 1, max = 24, value = 6),
          numericInput("ctp_v", "Volume de tâches mensuel :", value = 500, min = 1),
          numericInput("ctp_c", "Co\u00fbt par tentative (C\u2081) :", value = 0.05, min = 0, step = 0.01),
          numericInput("ctp_orch", "C\u2082 : Orchestration/mois (\u20ac) :", value = 0, min = 0),
          radioButtons("ctp_kappa", "Complexit\u00e9 (\u03ba) :", choices = c("Agent simple (\u03ba=1)" = 1, "Multi-outils (\u03ba=4)" = 4, "Multi-agents (\u03ba=12)" = 12), selected = 1),
          numericInput("ctp_w", "Co\u00fbt horaire humain (w) :", value = 15, min = 1),
          numericInput("ctp_h1", "Heures/mois (Calibrage h\u2081) :", value = 10, min = 0),
          numericInput("ctp_h2", "Heures/mois (Croisi\u00e8re h\u2082) :", value = 2, min = 0)
        ),
        layout_columns(
          col_widths = c(3, 3, 3, 3),
          value_box("Total C\u2081 (API)", uiOutput("vb_c1_val"), theme = "secondary"),
          value_box("Total C\u2082 (Infra)", uiOutput("vb_c2_val"), theme = "secondary"),
          value_box("Total C\u2083 (Humain)", uiOutput("vb_c3_val"), theme = "secondary"),
          value_box("CTP Global", uiOutput("vb_ctp_val"), theme = "primary")
        ),
        layout_columns(
          col_widths = c(6, 6),
          card(
            card_header("L'Iceberg des Coûts (Répartition)"),
            plotlyOutput("plot_ctp_donut")
          ),
          card(
            card_header("Le Genou du Mois 3 (Coût Mensuel)"),
            plotlyOutput("plot_ctp_line")
          )
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
