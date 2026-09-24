# ⚖️ SAGA Arbitre - Simulateur FinOps IA Agentique

**SAGA Arbitre** est une application web interactive propulsée par R/Shiny. Elle est conçue pour les architectes IA et les directions financières souhaitant évaluer avec une précision chirurgicale le **Coût Total de Possession (CTP)** et le **Retour sur Investissement (ROI)** d'une architecture agentique autonome face à un traitement humain traditionnel.

Cette application matérialise les standards empiriques FinOps, dissociant les coûts en trois dimensions fondamentales (Inférence, Infrastructure, et Humain) pour éliminer les illusions financières souvent liées aux déploiements LLM.

---

## ✨ Fonctionnalités Principales

Le simulateur adopte une approche ascendante ("Bottom-Up") répartie sur plusieurs modules de diagnostic :

- **📊 Télémétrie du Terrain** : Ingestion dynamique de fichiers journaux (logs métier) de squads d'agents en production. Calcule l'équivalence financière des jetons (*Prompt, Cache contextuel, Output*) et déduit un coût moyen par tâche réelle.
- **🧠 1. Microscope Inférence (C1)** : Simulateur API inter-fournisseurs (Google, Anthropic, OpenAI). Intègre la conversion dynamique USD/EUR et la comparaison par scénarios selon les tailles de contexte.
- **🏗️ 2. Microscope Infrastructure (C2)** : Conception à la carte du "corps" de l'agent. Différenciation stricte entre le CAPEX (coûts fixes mensuels : hébergement, Vector DB) et l'OPEX (coûts variables : APIs de recherche, Observabilité LLMOps, parsers).
- **🙋 3. Microscope Humain (C3)** : Modélisation asymétrique du *Human-in-the-Loop*. Met en évidence le coût lourd de la "Phase de Calibrage" (Mois 1 à 3) face au régime résiduel de la "Phase de Croisière" (Escalade métier).
- **🎯 4. Diagnostic d'Investissement (CTP)** : L'agrégateur macroscopique top-down. Projette la somme temporelle des modules dans des graphiques croisés pour identifier avec exactitude le "Genou de rentabilité" (Point Mort) face au process manuel historique.

---

## 🚀 Installation & Lancement

Le socle logiciel repose sur le langage **R** et bénéficie d'une gestion stricte de ses dépendances via le moteur `renv`.

### Prérequis
- R (version >= 4.1.0)
- Le package `renv` installé globalement.

### Initialisation de l'environnement

1. Clonez le dépôt et naviguez dans le dossier du projet :
   ```bash
   cd /chemin/vers/app_saga_arbitre
   ```

2. Restaurez les bibliothèques figées :
   ```R
   # Depuis la console R
   renv::restore()
   ```

3. Lancez l'application Shiny :
   ```R
   shiny::runApp()
   ```

---

## 📂 Architecture du Projet

```text
app_saga_arbitre/
├── app.R                  # Point d'entrée de l'application (charge l'UI et Server)
├── R/
│   ├── ui.R               # Définition de l'interface utilisateur (Shiny layout)
│   ├── server.R           # Cœur réactif et logique de calculs FinOps
│   ├── logic_maths.R      # Fonctions mathématiques pures (indépendantes du UI)
│   └── logic_parsers.R    # Parseurs syntaxiques des fichiers de Télémétrie Markdown
├── data/                  # Fichiers sources (catalogues d'inputs non-code)
│   ├── pricing_models.csv # Tarification des modèles LLM (USD)
│   └── pricing_infra.csv  # Tarification des briques cloud/LLMOps C2 (USD)
├── telemetry/             # Répertoires de données dynamiques injectées par les agents locaux
│   └── [nom_du_squad]/
│       └── [mois_annee]/
└── tests/
    └── testthat/          # Suite stricte de tests de non-régression mathématique et parsing
```

---

## 💡 Workflow d'Ingénierie & "Règle d'Or FinOps"

Pour utiliser SAGA Arbitre de manière optimale, il est recommandé de suivre le flux d'analyse séquentiel :

1. Entrez vos propres volumes physiques dans les **Onglets C1, C2, et C3**.
2. Copiez manuellement les synthèses produites (Coût C1 par tâche, Coût Total Mensuel C2, et Heures $h_1$/$h_2$ C3).
3. Collez ces données dans les paramètres de la barre latérale du module final **Diagnostic CTP**.

> **⚠️ Avertissement de Complexité ($\kappa$)** : 
> L'onglet macroscopique CTP dispose d'un multiplicateur budgétaire théorique "$\kappa$". Si vous y injectez vos totaux financiers ultra-précis issus du microscope C2 (qui contiennent déjà le cumul détaillé de votre architecture multi-agents), **vous devez impérativement sécuriser le curseur sur "Agent Simple ($\kappa = 1$)"**. Dans le cas contraire, vous appliquerez un double-effet multiplicateur biaisant drastiquement le tracé de votre ROI.

---

## 🔬 Stratégie de Qualité & Tests

L'ensemble des fonctions noyaux (équivalences financières du *context cache*, amortissements $h_1$/$h_2$, sommes partielles) sont purgées des effets de bords de l'interface *Shiny* et extraites dans `R/logic_maths.R`.
Ces noyaux sont protégés intégralement par des Tests Unitaires automatisés s'appuyant sur le framework de référence `testthat` de l'écosystème R.

**Exécuter les tests localement :**
```R
testthat::test_dir("tests/testthat/")
```

---
*Développé pour orchestrer la gouvernance financière et l'audit probabiliste en contexte d'Intelligence Artificielle d'entreprise.*
