# Run from the project root after renv::restore(). Does not deploy or write user data.
stopifnot(file.exists("app.R"), file.exists("data/pricing_models.csv"))
env <- new.env(parent = globalenv())
app <- source("app.R", local = env)$value
stopifnot(inherits(app, "shiny.appobj"))
html <- htmltools::renderTags(saga_ui())
stopifnot(!grepl("polyfill.io|fonts.googleapis.com|cdn.jsdelivr.net", html$html))
cat("Application chargée :", R.version.string, "\n")
