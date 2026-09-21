library(shiny)
library(bslib)
library(ggplot2)
library(dplyr)
library(stringr)
library(DT)
library(markdown)

# The R/ folder is automatically sourced by shinyApp() if they are in standard order, 
# but to be completely safe in all loading contexts (like renv/rsconnect), we can source them:
source("R/logic_maths.R")
source("R/logic_parsers.R")
source("R/ui.R")
source("R/server.R")

shinyApp(ui = saga_ui(), server = saga_server)
