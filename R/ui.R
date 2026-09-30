saga_ui <- function() {
  # Configuration du chemin d'accès aux assets (logo)
  if (dir.exists("www")) {
    shiny::addResourcePath("assets", normalizePath("www"))
  }
  
  logo_file <- if (file.exists("www/LOGO_Q.png")) {
    "www/LOGO_Q.png"
  } else {
    NULL
  }
  
  logo_src <- if (!is.null(logo_file) && requireNamespace("base64enc", quietly = TRUE)) {
    base64enc::dataURI(file = logo_file, mime = "image/png")
  } else {
    "LOGO_Q.png"
  }

  page_navbar(
    title = tags$span(
      tags$img(
        src = logo_src,
        height = "32px",
        style = "margin-right: 10px; vertical-align: middle;",
        alt = "Logo Qognito"
      ),
      "SAGA Arbitre"
    ),
    theme = bs_theme(
      bg = "#0F2035", fg = "#FFFFFF", primary = "#D4850F",
      base_font = font_google("Inter", local = FALSE)
    ),
    
    # Activation de MathJax pour les formules et styles du thème Qognito
    header = tags$head(
      tags$style(HTML("
        /* Brand / Titre principal en haut à gauche */
        .navbar-brand,
        .navbar-brand > span,
        .navbar-brand a {
          color: #D4850F !important;
          font-weight: 700;
          display: inline-flex;
          align-items: center;
        }

        /* Variables bslib / Bootstrap pour la barre de navigation */
        .navbar {
          --bs-navbar-color: #D4850F !important;
          --bs-navbar-hover-color: #FFAE42 !important;
          --bs-navbar-active-color: #D4850F !important;
          --bs-navbar-brand-color: #D4850F !important;
        }

        /* Tous les titres d'onglets (inactifs & actifs) en orange */
        .navbar-nav .nav-link,
        .navbar-nav > li > a,
        .nav-tabs .nav-link,
        .nav-underline .nav-link,
        .nav-underline > li > a,
        .nav-link {
          color: #D4850F !important;
          font-weight: 600 !important;
        }

        /* Onglet actif : orange avec indicateur de soulignement */
        .navbar-nav .nav-link.active,
        .navbar-nav > li.active > a,
        .nav-tabs .nav-link.active,
        .nav-underline .nav-link.active,
        .nav-underline > li.active > a,
        .nav-link.active {
          color: #D4850F !important;
          border-bottom: 2px solid #D4850F !important;
          font-weight: 700 !important;
        }

        /* Survol des onglets */
        .navbar-nav .nav-link:hover,
        .navbar-nav > li > a:hover,
        .nav-link:hover {
          color: #FFAE42 !important;
        }

        /* Formulaires, valeurs et typographie */
        .shiny-input-container label, .control-label, .form-group label { color: #FFFFFF !important; }
        input, select, .form-control { 
          color: #FFFFFF !important; 
          background-color: #0F2035 !important; 
          border: 1px solid #D4850F !important;
        }
        #pricing-import-control .btn-file {
          color: #FFFFFF;
          background-color: #495057;
          border-color: #6c757d;
        }
        .value-box-value, .value-box-title { color: #FFFFFF !important; }
        p, h1, h2, h3, h4, h5, h6 { color: #FFFFFF !important; }
      ")),
      tags$script(src = "https://polyfill.io/v3/polyfill.min.js?features=es6"),
      tags$script(id = "MathJax-script", async = NA, src = "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js")
    ),
    
    nav_panel("Manuel vs Agentique",
      layout_sidebar(
        sidebar = sidebar(
          title = "Paramètres de la Tâche",
          numericInput("vol", "Volume entrant mensuel :", value = 50, min = 1),
          numericInput("time_h", "Temps unitaire manuel (min) :", value = 15, min = 1),
          numericInput("cost_h", "Coût humain conventionnel (€/h) :", value = 15, min = 1),
          numericInput("cost_tokens", "C\u2081 : Co\u00fbt des tokens par t\u00e2che :", value = 0.05, min = 0, step = 0.01),
          numericInput("cost_orch", "C\u2082 : Orchestration mensuelle (\u20ac) :", value = 0, min = 0),
          numericInput("maint_h", "C\u2083 : Maintenance IA mensuelle (heures) :", value = 2, min = 0),
          sliderInput("ps", HTML("Taux de succ\u00e8s (P<sub>s</sub>) % :"), min = 1, max = 100, value = 90),
          numericInput("build_ia", "Investissement initial Agentique (\u20ac) :", value = 1200, min = 0),
          numericInput("build_manual", "Investissement initial Manuel (\u20ac) :", value = 0, min = 0),
          actionButton("add_scen", "Sauvegarder Scénario", class = "btn-primary")
        ),
        card(
          card_header(HTML("Comparatif des Coûts par Tâche (C<sub>task</sub>)")),
          plotlyOutput("plot_ctask")
        ),
        card(
          card_header("Coûts cumulés à couverture finale équivalente"),
          plotlyOutput("plot_roi")
        )
      )
    ),

    nav_panel("C1 - Inférence",
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

    nav_panel("C2 - Infra",
      layout_sidebar(
        sidebar = sidebar(
          title = "Paramètres d'Infrastructure",
          numericInput("c2_v", "Volume mensuel de tâches (V) :", value = 500, min = 1),
          numericInput("c2_usd_eur", "Taux (1 USD en EUR) :", value = 0.88, min = 0, step = 0.01),
          hr(),
          p(strong("Architecture C2 (Cochez) :")),
          uiOutput("ui_c2_fixed_choices"),
          hr(),
          uiOutput("ui_c2_var_choices")
        ),
        layout_columns(
          col_widths = c(6, 6),
          value_box("C2: Socle Fixe (Mensuel)", uiOutput("vb_c2_fixe_val"), theme = "secondary", class = "mb-3"),
          value_box("C2: Charge Variable (× V)", uiOutput("vb_c2_var_val"), theme = "secondary", class = "mb-3")
        ),
        layout_columns(
          col_widths = c(8, 4),
          card(
            card_header("Distribution Mensuelle selon les Piliers de la Taxonomie"),
            plotlyOutput("plot_c2_breakdown")
          ),
          value_box(title = HTML("<span>Total C<sub>2</sub> Mensuel (à copier dans CTP)</span>"), value = uiOutput("vb_c2_total_val"), theme = "primary")
        ),
        card(
          card_header("Catalogue FinOps de l'Infrastructure"),
          DTOutput("table_c2_pricing")
        )
      )
    ),

    nav_panel("C3 - Humain",
      layout_sidebar(
        sidebar = sidebar(
          title = "Inducteurs Humains (C3)",
          numericInput("c3_v", "Volume mensuel de tâches (V) :", value = 31, min = 1),
          numericInput("c3_w", "Coût horaire conventionnel (€/h) :", value = 15, min = 1),
          hr(),
          p(strong("Phase 1: Calibrage (Build Étendu)")),
          numericInput("c3_h1_input", "Effort Forfaitaire (h/mois) :", value = 15, min = 0),
          hr(),
          p(strong("Phase 2: Croisière (Run)")),
          sliderInput("c3_escalade", "Taux d'escalade (%) :", min = 0, max = 50, value = 10, step = 0.5),
          numericInput("c3_t_reprise", "Temps de reprise (minutes/tâche) :", value = 15, min = 0),
          numericInput("c3_review", "Revue systématique (minutes/document) :", value = 0, min = 0),
          numericInput("c3_governance", "Gouvernance et entretien (h/mois) :", value = 0, min = 0),
          p("Zéro est une hypothèse : compléter la revue et la gouvernance avant de conclure.")
        ),
        layout_columns(
          col_widths = c(6, 6),
          value_box("h1 (Calibrage) - Mois 1 à 3", uiOutput("vb_c3_h1"), theme = "secondary", class = "mb-3",
                    p("Heures copier/coller -> CTP")),
          value_box("h2 (Croisière) - Mois 4+", uiOutput("vb_c3_h2"), theme = "primary", class = "mb-3",
                    p("Heures copier/coller -> CTP"))
        ),
        card(
          card_header("Effort Asymétrique de Maintenance (Mois 1-3 vs Mois 4+)"),
          plotlyOutput("plot_c3_asym")
        )
      )
    ),

    nav_panel("Diagnostic d'Investissement (CTP)",
      layout_sidebar(
        sidebar = sidebar(
          title = "Paramètres du Dispositif",
          sliderInput("ctp_t", "Horizon temporel (mois) :", min = 1, max = 24, value = 6),
          numericInput("ctp_v", "Volume entrant mensuel :", value = 500, min = 1),
          numericInput("ctp_c", "Co\u00fbt par tentative (C\u2081) :", value = 0.05, min = 0, step = 0.01),
          numericInput("ctp_orch", "C\u2082 : Orchestration/mois (\u20ac) :", value = 218, min = 0),
          checkboxInput("ctp_detailed", "C2 est déjà le total détaillé (κ = 1)", value = TRUE),
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
            card_header("Coût mensuel — hypothèse de calibrage de trois mois"),
            plotlyOutput("plot_ctp_line")
          )
        )
      )
    ),
    
    nav_panel("Prix API",
      layout_columns(
        col_widths = 12,
        card(
          card_header("Mes tarifs pour cette simulation"),
          p("Vos modifications concernent uniquement votre session. Exportez vos tarifs pour les conserver."),
          p("Double-cliquez sur une cellule pour la modifier, puis cliquez sur « Appliquer à ma simulation » pour utiliser ces tarifs dans C1. Prix en USD par million de jetons ; dates au format AAAA-MM-JJ."),
          layout_columns(
            col_widths = c(4, 4, 4), fill = FALSE, fillable = FALSE,
            actionButton("add_row", "Ajouter un Modèle", icon = icon("plus"), class = "btn-secondary"),
            actionButton("delete_row", "Supprimer la sélection", icon = icon("trash"), class = "btn-warning"),
            actionButton("apply_pricing", "Appliquer à ma simulation", class = "btn-primary", icon = icon("check"))
          ),
          hr(),
          layout_columns(
            col_widths = c(4, 4, 4), fill = FALSE, fillable = FALSE,
            div(
              fileInput("import_pricing", "Importer mes tarifs", accept = c(".csv", "text/csv"),
                        buttonLabel = "Parcourir…", placeholder = "Aucun fichier sélectionné"),
              id = "pricing-import-control"
            ),
            downloadButton("export_pricing", "Exporter mes tarifs", class = "btn-secondary"),
            actionButton("reset_pricing", "Rétablir les tarifs de référence", icon = icon("rotate-left"), class = "btn-secondary")
          ),
          tags$details(
            tags$summary("Import, export et format des fichiers CSV"),
            p("L’import remplace la table affichée et attend votre application. L’export conserve cette table, y compris les modifications non appliquées. Le rétablissement remet immédiatement la table et les calculs aux tarifs de référence."),
            p("CSV UTF-8 : séparateur virgule ou point-virgule. Identifiant, p_in_1M et p_out_1M sont requis ; Fournisseur, p_cache_1M et date_verification sont facultatifs. Un tarif cache ou une date inconnus peuvent rester vides.")
          ),
          hr(),
          div(textOutput("pricing_status"), role = "status", `aria-live` = "polite"),
          div(textOutput("pricing_error"), class = "text-danger", role = "alert"),
          DTOutput("table_pricing_edit")
        )
      )
    )
  )
}
