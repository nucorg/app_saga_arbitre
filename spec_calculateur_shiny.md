# 📋 Spécifications pour l'Agent Plombier-R (Calculateur IA / Shiny : SAGA Arbitre)

**Rôle :** Tu es le Plombier-R, expert en développement R, Shiny et `bslib`.
**Mission :** Développer une application Shiny moderne servant de tableau de bord et de calculateur de rentabilité pour le déploiement d'agents IA (Formation SAGA-IA). Le code doit être structuré, propre, et utiliser `ggplot2`, `dplyr`, et `stringr`.

L'application doit reposer sur l'équivalence économique du calcul du **Coût Complet par Tâche ($C_{task}$)** et permettre de confronter la théorie à la réalité de nos fichiers de logs.

## 1. Architecture de l'Interface (UI)
L'application doit utiliser un layout fluide (type `bslib::page_navbar` ou orienté tabs) avec un thème moderne (couleur principale Qognito : `#D4850F`, fond sombre ou clair très épuré). 
Elle comportera 3 onglets principaux :

### 🟢 Onglet 1 : Simulateur & Comparaison de Scénarios
- **Sidebar (Inputs) :** Permet à l'utilisateur de configurer un scénario. L'astuce est de proposer un bouton "Sauvegarder comme Scénario A, B ou C", ou de mettre les `sliderInput` et `numericInput` dans des colonnes côte à côte.
- Les inputs requis (tirés du calculateur M2) :
  - **Volume mensuel (V)** de la tâche.
  - **Temps unitaire (T)** d'une tâche humaine en minutes.
  - **Coût marginal humain** (par heure libérée).
  - **Coût d'orchestration / Infra (C_orch).**
  - **Taux de succès / Fiabilité Composée ($P_s$).**
- **Main Panel (Dataviz) :** 
  - Un Bar chart (`ggplot2`) comparant le $C_{task}$ du Scénario 1, Scénario 2 et du traitement manuel.
  - Un graphique en ligne illustrant le point mort (ROI cumulé sur 12 mois), mettant en évidence que le scénario hybride est souvent perdant les 3 premiers mois.

### 🔵 Onglet 2 : Télémétrie du Terrain (Import Compliance H4E)
- **Inputs :** `fileInput` ou saisie de chemin pour lire deux types de rapports locaux simultanément : 
  1. Rapport de facturation : `cout_carbone_et_computation_YYYY-MM-DD.md`
  2. Rapport de conformité : `YYYY-MM-DD_squad_X.md`
- **Traitements attendus :**
  - Le serveur devra parser la table Markdown du fichier de facturation pour récupérer les totaux d'inférence (In, Out, Cache, Thinking) et les convertir dynamiquement en coûts en euros selon une grille de tarification LLM préconçue (Gemini Pro/Flash).
  - Le serveur devra parser l'Indice de Santé (Regex : `Total de Livrables jugés : (\d+)` et `Fiabilité Composée \(Ps\)  : (\d+) %`) pour extraire le volume et le taux de succès.
- **Main Panel :** Tableaux interactifs (`DT::dataTableOutput`) et des KPI (`bslib::value_box`) reflétant le véritable $C_{task}$ issu des logs (vs. le théorique du Scénario !).

### 🟡 Onglet 3 : Référentiel Pédagogique (Formules & Doctrine)
- Contenu statique en Markdown `shiny::markdown()` rappelant la rationalité mathématique (afin que l'apprenant ou le dirigeant comprenne ce qui est calculé).
- Le Plombier doit inclure le code HTML/MathJax pour les 3 définitions suivantes :
  1. **Le paradoxe franco-américain :** *La substitution d'un salaire en inférence transforme des charges taxées (masse salariale) en OpEx purs sans cotisations.*
  2. **La Fiabilité Composée :** $P_s = (p)^N$ (Où N est le nombre d'étapes d'une chaîne agentique).
  3. **Le Coût par Tâche Acceptée ($C_{task}$) :** 
     $$C_{task} = \frac{\sum (C_{tokens}) + C_{infra} + C_{revue\_humaine}}{P_s}$$

---

## 2. Exigences Techniques (Modélisation Serveur)

### A. La logique de comparaison (Scénarios)
Au lieu de dédoubler massivement le code `server`, crée une logique réactive (ex: `reactiveValues(scenarios = list())`). Lorsqu'on clique sur "Ajouter Scénario", l'état actuel des inputs est figé dans une liste (Scénario 1, 2, etc.) qui est ensuite dépilée dans un `bind_rows()` pour être nourrie à un seul et même script `ggplot2` avec un mapping `fill = Scenario`.

### B. Moteur de Parsing des fichiers H4E
Tu (le PlombierR) devras écrire deux fonctions helper dédiées (ex: `parse_billing_md(path)` et `parse_compliance_md(path)`). 
- *Fichier Facturation :* C'est une table Markdown. Utilise `readLines` pour trouver la ligne `| :--- |...` et extrait les données qui suivent avec une regex (`stringr::str_split_1(x, "\\|")`). Attention à bien nettoyer les espaces et convertir les nombres (ignorer les espaces dans `1 637 613`).
- *Fichier Compliance :* C'est un rapport brut. Extrait avec des Regex ciblées, ex : `str_extract(text, "Livrables conformes\\s*:\\s*(\\d+)")`.

### C. Règles de Code
- Interdiction stricte de coder le rendu UI "en dur" avec l'antique syntaxe `fluidPage(style="...")`. Utilise **`bslib`** et ses abstractions modernes (`page_sidebar()`, `value_box()`, `card()`).
- Séparation des préoccupations : Le calcul mathématique `compute_roi()` doit être une fonction pure séparée du réactif Shiny pour faciliter les tests.

***

### Pourquoi cette stratégie est efficace pour le Plombier-R :
1. **Verrouillage mathématique :** Il n'essaiera pas d'inventer la notion du $C_{task}$, tu lui donnes la formule exacte.
2. **Guidage sur le parsing (la zone de danger) :** Analyser du texte issu de LLM pour en extraire des dataframes R est infernal s'il ne sait pas *exactement* quelles regex cibler. En lui listant les motifs des fichiers de logs (`| Rôle |...` avec des espaces dans les chiffres), il va utiliser la bonne astuce `gsub(" ", "", text)` avant le `as.numeric()`.
3. **Agilité de l'Architecture (Comparatifs) :** En lui explicitant la notion de `reactiveValues` pour stocker plusieurs instances d'inputs comme "Scénarios", tu l'empêches de coder un mur d'inputs de type `input$var1_scenario1`, `input$var1_scenario2`, ce qui alourdirait massivement la dette technique de l'application et casserait la maintenabilité.
