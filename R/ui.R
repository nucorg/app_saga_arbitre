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

        .monthly-workspace, .monthly-sidebar { font-family: Inter, system-ui, sans-serif; }
        .monthly-sidebar { font-size: .9rem; }
        .monthly-sidebar h5 { margin-top: .9rem; margin-bottom: .2rem; }
        .monthly-workspace { display: grid; grid-template-columns: minmax(0, 1fr); gap: 1rem; min-width: 0; }
        .monthly-workspace .card { flex: none; }
        .monthly-workspace > * { min-width: 0; }
        #monthly_breakdown { overflow-x: auto; }
        .monthly-workspace h3 { margin-bottom: 0; }
        .monthly-metrics { display: flex; flex-wrap: wrap; gap: 1rem; }
        .monthly-metric { flex: 1 1 180px; padding: .8rem; border-left: 3px solid #D4850F; }
        .monthly-metric strong { display: block; white-space: nowrap; font-size: 1.6rem; color: #FFAE42; }
        .monthly-details { padding: 1rem; border: 1px solid #67798c; border-radius: .5rem; }
        .monthly-details summary { cursor: pointer; font-weight: 600; }
        .monthly-details[open] summary { margin-bottom: 1rem; }
        .monthly-workspace td, .monthly-workspace th { vertical-align: middle; }
        .monthly-workspace .table { --bs-table-bg: transparent; --bs-table-color: #fff; }
        .monthly-workspace .table tr:last-child { font-weight: 700; }
        #ctp_balance_table tr:last-child, #ctp_monthly_table tr:last-child { font-weight: normal; }
        .monthly-number { white-space: nowrap; }
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
        fillable = FALSE, fill = FALSE,
        sidebar = sidebar(
          title = "Votre mois de référence", width = 370,
          class = "monthly-sidebar", gap = "0.5rem", padding = "1rem",
          actionButton("load_monthly_example", "Charger l’exemple — Veille, Section 1", class = "btn-primary"),
          helpText("Le chargement remplace les paramètres de cet onglet. Ils restent modifiables."),
          h5("1. Activité"),
          numericInput("vol", "Nombre d’entrées à traiter par mois", value = 50, min = 1),
          numericInput("ps", "Part des résultats finalement acceptés (%)", value = 90, min = 0, max = 100),
          helpText("Après les éventuelles reprises, et non au premier essai."),
          h5("2. Référence manuelle"),
          numericInput("time_h", "Temps de traitement manuel par résultat (minutes)", value = 15, min = 0),
          numericInput("cost_h", "Coût horaire humain de référence (€/h)", value = 15, min = 0),
          helpText("Coût horaire commun au manuel et au travail humain avec le dispositif."),
          h5("3. Dispositif"),
          numericInput("cost_c1_month", "C1 — Utilisation des modèles (€/mois)", value = 2.5, min = 0, step = 0.01),
          textOutput("monthly_c1_hint"),
          helpText("Ce montant inclut les nouvelles tentatives. Il reste fixe si le volume change."),
          numericInput("cost_orch", "C2 — Infrastructure logicielle (€/mois)", value = 0, min = 0),
          helpText("Serveurs, orchestration, stockage, abonnements et accès aux sources. Hors investissement initial."),
          numericInput("maint_h", "C3 — Travail humain avec le dispositif (h/mois)", value = 2, min = 0),
          helpText("Revue, corrections, supervision et maintenance humaine."),
          textOutput("monthly_c3_hint"),
          h5("4. Investissement"),
          numericInput("build_ia", "Investissement initial du dispositif (€)", value = 1200, min = 0),
          numericInput("amort_months", "Durée de répartition analytique (mois)", value = 24, min = 1, step = 1),
          helpText("Une convention de comparaison mensuelle ; ce n’est pas l’horizon T du CTP."),
          tags$details(tags$summary("Paramètre complémentaire"),
            numericInput("build_manual", "Investissement initial manuel (€)", value = 0, min = 0),
            helpText("Même durée de répartition analytique pour les deux modes.")),
          actionButton("add_scen", "Ajouter à la comparaison — session"),
          helpText("Les hypothèses sont conservées pendant cette session uniquement.")
        ),
        tags$div(class = "monthly-workspace",
          h3("Comparer un mois de croisière"),
          p("Un mois de fonctionnement stabilisé, comparé au manuel pour le même nombre de résultats finalement acceptés."),
          card(id = "monthly-result-card", full_screen = TRUE,
            card_header("Du fonctionnement courant au coût mensuel analytique"),
            uiOutput("monthly_summary"),
            tableOutput("monthly_breakdown"),
            p("La part d’investissement sert à la lecture analytique : elle ne représente pas une nouvelle dépense chaque mois.")),
          card(card_header("Comparaison par résultat finalement accepté"),
            conditionalPanel("input.ps > 0", plotlyOutput("plot_ctask", height = "310px")),
            conditionalPanel("input.ps == 0", p("Aucun résultat accepté : comparaison par résultat non définie.", id = "monthly-ratio-unavailable"))),
          tags$details(class = "monthly-details",
            tags$summary("Hypothèses des comparaisons ajoutées à cette session"),
            uiOutput("monthly_saved")),
          tags$details(class = "monthly-details",
            tags$summary("Projection cumulée à charge constante"),
            p("Cette projection suppose une charge humaine constante. Le CTP du cours distingue calibrage et croisière."),
            selectInput("projection_months", "Horizon de projection (mois)", choices = c("6 mois" = 6, "12 mois" = 12), selected = 6),
            p("L’investissement est compté une seule fois au démarrage, puis seuls les coûts courants sont cumulés."),
            conditionalPanel("input.ps > 0", plotlyOutput("plot_roi", height = "330px")),
            conditionalPanel("input.ps == 0", p("Aucun résultat accepté : projection comparative non définie.")))
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
      layout_sidebar(fillable=FALSE, fill=FALSE,
        sidebar=sidebar(title="Votre projet sur T mois", width=370,
          class="monthly-sidebar", gap="0.5rem", padding="1rem",
          actionButton("load_ctp_example", "Charger l’exemple — Veille, CTP à 6 mois", class="btn-primary"),
          helpText("Charge tous les paramètres de cet onglet, y compris ceux du solde. Les autres onglets restent indépendants."),
          h5("1. Période et activité"),
          numericInput("ctp_t", "Horizon étudié T, depuis le démarrage (mois)", 6, min=1, max=24, step=1),
          numericInput("ctp_v", "Nombre d’entrées à traiter par mois", 500, min=1),
          h5("2. Fonctionnement"),
          numericInput("ctp_c1_month", "C1 — Utilisation des modèles (€/mois)", 25, min=0, step=.01),
          helpText("Toutes les tentatives sont comprises. Le budget saisi reste constant si le volume change."),
          numericInput("ctp_orch", "C2 — Infrastructure logicielle (€/mois)", 218, min=0),
          textOutput("ctp_c2_hint"),
          tags$details(tags$summary("Estimation avancée de C2"),
            checkboxInput("ctp_detailed", "C2 est un total mensuel déjà évalué", TRUE),
            conditionalPanel("!input.ctp_detailed",
              helpText("Le montant C2 saisi devient une base à majorer. Choisissez un coefficient justifié par votre scénario ; ce n’est pas une mesure automatique de complexité."),
              numericInput("ctp_kappa", "Coefficient appliqué à la base C2", 1, min=1, step=.1))),
          h5("3. Travail humain"),
          numericInput("ctp_w", "Coût horaire humain de référence (€/h)", 15, min=0),
          numericInput("ctp_calibration", "Durée du calibrage (mois)", 3, min=0, max=120, step=1),
          helpText("Une hypothèse à confronter au fonctionnement observé, pas une garantie de stabilisation."),
          numericInput("ctp_h1", "Travail humain pendant le calibrage (h/mois)", 10, min=0),
          numericInput("ctp_h2", "Travail humain en croisière (h/mois)", 2, min=0),
          helpText("Revue, corrections, supervision et maintenance. Les heures de calibrage remplacent celles de croisière ; elles ne s’y ajoutent pas."),
          h5("4. Investissement"),
          numericInput("ctp_investment", "Investissement initial du dispositif (€)", NA_real_, min=0),
          helpText("Laissez vide s’il est inconnu. Saisissez zéro seulement s’il est nul. Il est compté une seule fois au démarrage, sans répartition analytique sur 24 mois.")
        ),
        tags$div(class="monthly-workspace",
          h3("Du fonctionnement au coût total du projet"),
          p("Tous les montants cumulés portent sur l’horizon T, depuis le démarrage. C1 et C2 restent constants chaque mois ; la charge humaine suit les deux phases choisies."),
          card(id="ctp-result-card",card_header("Coût total de possession sur l’horizon choisi"),
            uiOutput("ctp_summary"),
            div(tableOutput("ctp_breakdown"), style="overflow-x:auto")),
          card(card_header("Coût de fonctionnement de chaque mois"),
            textOutput("ctp_phase_hint"), plotlyOutput("plot_ctp_line",height="290px")),
          card(card_header("Coût cumulé depuis le démarrage"),
            p("Au mois zéro : l’investissement initial. Ensuite : les coûts de fonctionnement, sans ajouter de parts analytiques."),
            plotlyOutput("plot_ctp_cumulative",height="300px")),
          tags$details(id="ctp-balance-panel",class="monthly-details",
            tags$summary("Temps libéré et solde conventionnel"),
            p("Comparaison à périmètre et qualité finale équivalents supposés. Le manuel de référence ne comporte ici aucun nouvel investissement."),
            layout_columns(col_widths=c(4,4,4),fill=FALSE,fillable=FALSE,
              numericInput("ctp_manual_minutes","Temps manuel par résultat (minutes)",30,min=0),
              numericInput("ctp_alpha","Part du temps libéré réaffectée (%)",50,min=0,max=100),
              numericInput("ctp_value_hour","Valeur d’une heure réaffectée (€/h)",15,min=0)),
            p("La valeur d’une heure réaffectée peut différer du coût horaire humain. La part réaffectée doit correspondre à un usage effectif du temps disponible."),
            uiOutput("ctp_balance_summary"),
            div(tableOutput("ctp_balance_table"),style="overflow-x:auto"),
            p("Une surcharge est valorisée mois par mois à son coût humain complet, sans réduction par le taux de réaffectation. Le solde ne démontre pas une économie automatique de trésorerie et ne constitue pas un verdict de rentabilité.")),
          tags$details(class="monthly-details",tags$summary("Vérifier les opérations mois par mois"),
            div(tableOutput("ctp_monthly_table"),style="overflow-x:auto"))
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
