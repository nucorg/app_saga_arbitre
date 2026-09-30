# Rscript scripts/deploy-public.R          : vérification seule
# Rscript scripts/deploy-public.R --publish : mise à jour de l'application existante
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 0L || identical(args, "--publish"))
script_arg <- grep("^--file=", commandArgs(), value = TRUE)
stopifnot(length(script_arg) == 1L)
app_dir <- dirname(dirname(normalizePath(sub("^--file=", "", script_arg))))
stopifnot(basename(app_dir) == "app_saga_arbitre")
record <- read.dcf(file.path(app_dir, "rsconnect/shinyapps.io/qognito/app_saga_arbitre.dcf"))
expected_url <- "https://qognito.shinyapps.io/app_saga_arbitre/"
stopifnot(record[1, "appId"] == "18052078",
          record[1, "account"] == "qognito",
          record[1, "server"] == "shinyapps.io",
          record[1, "url"] == expected_url)
files <- rsconnect::listDeploymentFiles(app_dir)
allowed <- files %in% c(".Rprofile", "app.R", "renv.lock") |
  grepl("^(R|data|www)/", files)
stopifnot(all(allowed), "app.R" %in% files,
          !any(grepl("(^|/)telemetry(/|$)", files)))
cat("Application : 18052078\nURL :", expected_url, "\nFichiers :\n")
cat(files, sep = "\n")
cat("\n")
if (identical(args, "--publish")) {
  apps <- rsconnect::applications(account = "qognito", server = "shinyapps.io")
  app <- apps[as.character(apps$id) == "18052078", , drop = FALSE]
  stopifnot(nrow(app) == 1L, app$name == "app_saga_arbitre", app$url == expected_url)
  rsconnect::deployApp(
    appDir = app_dir, appFiles = files, appId = "18052078",
    account = "qognito", server = "shinyapps.io", launch.browser = FALSE
  )
} else {
  cat("Vérification terminée. Aucune publication effectuée.\n")
}
