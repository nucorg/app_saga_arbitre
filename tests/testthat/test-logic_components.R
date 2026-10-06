source("../../R/logic_maths.R")
source("../../R/logic_components.R")
test_that("C1 distingue coût par appel, appels par entrée et budget mensuel", {
  withr::with_dir("../..", {
    x <- read_component_example("c1")$inputs
    prices <- read.csv("data/pricing_models.csv")
    r <- compute_inference_scenario(x,prices)
    expect_equal(r$selected$Par_appel,.0044)
    expect_equal(r$total,10.56)
    x$c1_selected <- "B"
    expect_equal(compute_inference_scenario(x,prices)$total,52.8)
    x$c1_calls <- 0
    expect_equal(compute_inference_scenario(x,prices)$total,0)
    for(id in c("c1_n_in","c1_n_out","c1_usd_eur","c1_v","c1_calls")) {
      y <- x;y[[id]] <- NA_real_;expect_error(compute_inference_scenario(y,prices),"Renseignez")
      y[[id]] <- -1;expect_error(compute_inference_scenario(y,prices),"invalide")
    }
    x$c1_selected <- "absent";expect_error(compute_inference_scenario(x,prices),"Choisissez")
    x$c1_selected <- "A";x$c1_mod_a <- "absent";expect_error(compute_inference_scenario(x,prices),"catalogue")
  })
})
test_that("C3 distingue calibrage et décomposition de croisière sans horizon fixe", {
  withr::with_dir("../..", {
    x <- read_component_example("c3")$inputs
    r <- compute_human_scenario(x)
    expect_equal(r$h1,300);expect_equal(r$h2,200)
    expect_equal(c(r$review,r$reprise,r$governance),c(100,60,40))
    expect_equal(r$h2*r$w,12000)
    for(id in c3_input_names) {
      y <- x;y[[id]] <- NA_real_;expect_error(compute_human_scenario(y),"Renseignez")
      y[[id]] <- -1;expect_error(compute_human_scenario(y),"invalide")
    }
    x$c3_escalade <- 100;expect_equal(compute_human_scenario(x)$h2,440)
    x$c3_escalade <- 101;expect_error(compute_human_scenario(x),"invalide")
    x <- setNames(as.list(rep(0,length(c3_input_names))),c3_input_names)
    expect_equal(compute_human_scenario(x)$h2,0)
  })
})
