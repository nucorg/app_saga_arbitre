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
    id = "saga_nav",
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

        .saga-c2-actions { display: flex; flex-wrap: wrap; gap: .6rem; }
        .saga-c2-actions .btn { white-space: normal; text-align: left; max-width: 100%; }
        .saga-c2-actions .btn, #clear_c2 { color: #FFFFFF; border-color: #D4850F; background: transparent; }
        .saga-c2-actions .btn:hover:not(:disabled), #clear_c2:hover { color: #091F35; background: #D4850F; }
        .saga-c2-actions .btn:disabled { opacity: .5; }
        .saga-c2-metric { flex: 0 0 auto; }
        .saga-c2-note { font-size: .9rem; }
        .saga-component-actions { display: flex; flex-wrap: wrap; gap: .6rem; }
        .saga-component-actions .btn { color: #FFFFFF; border-color: #D4850F; background: transparent; white-space: normal; text-align: left; max-width: 100%; }
        .saga-component-actions .btn:hover:not(:disabled) { color: #091F35; background: #D4850F; }
        .saga-component-actions .btn:disabled { opacity: .5; }
        .saga-component-note { font-size: .9rem; }
        #c1_selected input[type=radio]:checked, #c3_monthly_phase input[type=radio]:checked { background-color: #FFAE42 !important; }
        .saga-component-actions .btn:focus-visible, #c1_selected input:focus-visible, #c3_monthly_phase input:focus-visible { outline: 2px solid #FFFFFF; outline-offset: 3px; }
        #table_c1_pricing { overflow-x: auto; }
        .saga-c2-bars { list-style: none; margin: 0; padding: 0; }
        .saga-c2-bars li { margin-bottom: 1rem; }
        .saga-c2-bar-label { display: flex; flex-wrap: wrap; justify-content: space-between; gap: .3rem .8rem; }
        .saga-c2-track { background: #263c55; height: .55rem; margin-top: .3rem; border-radius: .25rem; }
        .saga-c2-bar { background: #D4850F; height: 100%; border-radius: .25rem; }
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
          helpText("Serveurs, orchestration, stockage, abonnements et accès aux sources. Hors investissement initial. Vous pouvez reporter le budget depuis C2 - Infra."),
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
      layout_sidebar(fillable=FALSE, fill=FALSE,
        sidebar=sidebar(title="Votre budget d’inférence",width=370,class="monthly-sidebar",gap="0.5rem",padding="1rem",
          actionButton("load_c1_example","Charger l’exemple d’estimation C1",class="btn-primary"),
          helpText("Paramètres illustratifs ; utilise les tarifs actifs de votre session."),
          h5("1. Taille moyenne d’un appel"),
          numericInput("c1_n_in","Jetons en entrée par appel",8000,min=0,step=1),
          numericInput("c1_n_out","Jetons en sortie par appel",1500,min=0,step=1),
          helpText("Un jeton est une unité de texte facturée par le modèle. Utilisez des volumes représentatifs de vos appels."),
          numericInput("c1_usd_eur","Taux de change — euros pour 1 dollar",.88,min=.0001,step=.01),
          h5("2. Activité mensuelle"),
          numericInput("c1_v","Nombre d’entrées à traiter par mois",1200,min=0,step=1),
          numericInput("c1_calls","Nombre moyen d’appels par entrée",1,min=0,step=.1),
          helpText("Incluez les étapes successives et les nouvelles tentatives. Le même modèle et la même taille moyenne d’appel sont supposés pour tous ces appels."),
          h5("3. Comparer puis choisir"),
          selectInput("c1_mod_a","Modèle A",choices=NULL),
          selectInput("c1_mod_b","Modèle B",choices=NULL),
          selectInput("c1_mod_c","Modèle C",choices=NULL),
          radioButtons("c1_selected","Modèle retenu pour le budget",choices=c("A","B","C"),selected="A",inline=TRUE)
        ),
        div(class="monthly-workspace",
          h3("Estimer le budget mensuel des modèles"),
          p("Comparez trois modèles sur les mêmes hypothèses, puis choisissez celui dont le budget sera reporté."),
          card(id="c1-result-card",card_header("C1 — Estimation retenue"),uiOutput("c1_summary"),
            p("Le report remplace uniquement le budget C1 mensuel. Le volume de la destination est conservé ; ce budget y reste fixe lorsque le volume change."),
            uiOutput("c1_transfer_actions"),
            p(class="saga-component-note","Après une modification, cliquez de nouveau pour reporter le budget. Aucun onglet n’est synchronisé automatiquement.")),
          card(card_header("Comparer le coût mensuel des trois modèles"),plotlyOutput("plot_c1_compare",height="310px")),
          tags$details(class="monthly-details",tags$summary("Tarifs actifs et périmètre de l’estimation"),
            p("Les prix du catalogue local sont convertis en euros par million de jetons au taux saisi. L’onglet Prix API permet de modifier puis d’appliquer vos tarifs à cette session."),
            DTOutput("table_c1_pricing"),
            p("Cette estimation ne modélise pas les réductions de cache ou de traitement par lots, les appels à des outils ni les taxes. Pour plusieurs modèles ou un budget issu de factures, renseignez le montant global dans Manuel vs Agentique ou dans le CTP."))
        )
      )
    ),

    nav_panel("C2 - Infra",
      layout_sidebar(
        fillable=FALSE, fill=FALSE,
        sidebar=sidebar(title="Votre budget C2 mensuel", width=370,
          class="monthly-sidebar", gap="0.5rem", padding="1rem",
          actionButton("load_c2_example", "Charger l’exemple — Veille, C2 à 2 400 €/mois", class="btn-primary"),
          helpText("Remplace les six montants de cet onglet. Hypothèses pédagogiques, pas des tarifs fournisseurs."),
          p("Renseignez les montants mensualisés attribués au projet. Comptez chaque dépense une seule fois. Un champ vide reste inconnu ; indiquez zéro si le poste est nul."),
          lapply(seq_len(nrow(infra_posts)), function(i) tagList(
            numericInput(infra_posts$id[i], paste0(infra_posts$label[i], " (€/mois)"), value=NA_real_, min=0, step=.01),
            helpText(infra_posts$help[i]))),
          actionButton("clear_c2", "Effacer les montants"),
          helpText("Vos montants restent disponibles pendant cette session uniquement.")
        ),
        tags$div(class="monthly-workspace",
          h3("Construire le budget mensuel d’infrastructure"),
          p("Additionnez les moyens logiciels récurrents nécessaires au dispositif. Ce budget ne se redimensionne pas automatiquement avec le volume."),
          card(id="c2-result-card",card_header("C2 — Budget mensuel du dispositif"),
            uiOutput("c2_budget"),
            p("Le report remplace C2 dans l’onglet choisi. Les autres paramètres sont conservés."),
            uiOutput("c2_transfer_actions"),
            p(class="saga-c2-note", "Après une modification du budget, cliquez de nouveau pour le reporter. Aucun onglet n’est synchronisé automatiquement.")),
          tags$details(class="monthly-details",
            tags$summary("Que compter dans ce budget ?"),
            p("C2 couvre les ressources logicielles récurrentes, y compris les outils de supervision et de tests. Les appels aux modèles restent en C1 ; le temps des personnes reste en C3 ; la conception et l’intégration initiales relèvent de l’investissement."),
            p("Pour un abonnement annuel, utilisez son équivalent mensuel. Pour une ressource partagée, retenez seulement la part attribuée au projet selon une répartition justifiée. Évaluez les consommations variables avant de les intégrer au montant mensuel du poste."),
            p("Une même base fiscale doit être utilisée pour tous les montants comparés. Les factures, contrats et relevés d’usage servent à étayer les hypothèses."))
        )
      )
    ),

    nav_panel("C3 - Humain",
      layout_sidebar(fillable=FALSE, fill=FALSE,
        sidebar=sidebar(title="Votre charge humaine",width=370,class="monthly-sidebar",gap="0.5rem",padding="1rem",
          actionButton("load_c3_example","Charger l’exemple — Veille, C3",class="btn-primary"),
          helpText("Remplace les hypothèses de cet onglet uniquement."),
          h5("1. Activité et coût horaire"),
          numericInput("c3_v","Nombre d’entrées à traiter par mois",NA_real_,min=0,step=1),
          numericInput("c3_w","Coût horaire humain de référence (€/h)",NA_real_,min=0),
          h5("2. Calibrage — mise au point"),
          numericInput("c3_h1_input","Travail humain total en calibrage (h/mois)",NA_real_,min=0),
          helpText("Incluez revue, corrections, supervision et maintenance pendant la mise au point du dispositif."),
          h5("3. Croisière — fonctionnement courant"),
          numericInput("c3_review","Revue systématique par entrée (minutes)",NA_real_,min=0),
          numericInput("c3_escalade","Part des entrées à reprendre (%)",NA_real_,min=0,max=100,step=.5),
          numericInput("c3_t_reprise","Temps de reprise par entrée concernée (minutes)",NA_real_,min=0),
          numericInput("c3_governance","Supervision et maintenance fixes (h/mois)",NA_real_,min=0),
          helpText("Un champ vide reste inconnu. Saisissez zéro seulement si le travail correspondant est effectivement nul."),
          h5("4. Phase du calcul mensuel"),
          radioButtons("c3_monthly_phase","Heures à reporter dans Manuel vs Agentique",choices=c("Croisière"="croisiere","Calibrage"="calibrage"),selected="croisiere"),
          helpText("Le report CTP utilise toujours les deux phases. Leur durée se règle dans le CTP.")
        ),
        div(class="monthly-workspace",
          h3("Construire la charge humaine du dispositif"),
          p("Distinguez l’effort de mise au point de celui du fonctionnement courant. La croisière additionne revue systématique, reprises et supervision."),
          card(id="c3-result-card",card_header("C3 — Heures et coûts par phase"),uiOutput("c3_summary"),
            p("Vers Manuel vs Agentique : remplace les heures du dispositif pour la phase choisie et le coût horaire commun au manuel et au dispositif. Vers le CTP : remplace les heures des deux phases et le coût horaire. Les volumes, la durée du calibrage et l’horizon sont conservés."),
            uiOutput("c3_transfer_actions"),
            p(class="saga-component-note","Les reports sont ponctuels. Cliquez de nouveau après une modification de vos hypothèses.")),
          conditionalPanel("output.c3_ready === 'yes'",card(card_header("Comparer le coût humain mensuel des deux phases"),plotlyOutput("plot_c3_asym",height="310px"))),
          tags$details(class="monthly-details",tags$summary("Comment lire ces hypothèses ?"),
            p("Le calibrage désigne la mise au point du dispositif. La croisière désigne son fonctionnement courant une fois les premiers réglages effectués ; elle conserve une charge humaine."),
            p("La revue porte sur toutes les entrées. Le temps de reprise concerne uniquement la part qui nécessite une correction ou une intervention humaine. La supervision et la maintenance sont ajoutées comme un forfait mensuel, sans les compter à nouveau dans les autres postes."),
            p("Le CTP tient compte de la durée de chaque phase sur son horizon T, fixé à six mois par défaut. Le taux horaire doit utiliser la même convention dans toutes les comparaisons."))
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
          helpText("Le bouton de report de C2 - Infra renseigne ce montant comme total déjà évalué, sans majoration."),
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
