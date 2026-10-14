testthat::test_that("the UI uses local assets and no remote executable resources", {
  source("../../R/ui.R")
  html <- htmltools::renderTags(saga_ui())$html
  testthat::expect_false(grepl("polyfill.io|cdn.jsdelivr.net|fonts.googleapis.com", html))
  testthat::expect_true(file.exists("../../LICENSE"))
})
