source("../../R/logic_infra.R")

test_that("le budget distingue absence, invalidité et zéro", {
  empty <- compute_infra_budget(list())
  expect_false(empty$complete); expect_equal(empty$count,0); expect_true(is.na(empty$total))
  x <- setNames(as.list(rep(0,6)),infra_input_names)
  expect_true(compute_infra_budget(x)$complete)
  expect_equal(compute_infra_budget(x)$total,0)
  for(value in list(NULL,NA_real_,"",-1,Inf,NaN,"abc",TRUE,1.001,c(1,2))) {
    y <- x; y[1] <- list(value); r <- compute_infra_budget(y)
    expect_false(r$complete); expect_true(is.na(r$total))
  }
})
test_that("les centimes et l'exemple pédagogique sont conservés", {
  x <- setNames(as.list(c(.1,.2,.03,10.99,0,100)),infra_input_names)
  expect_equal(compute_infra_budget(x)$total,111.32)
  withr::with_dir("../..", {
    ex <- read_infra_example()
    expect_equal(compute_infra_budget(ex$inputs)$total,2400)
    ex$inputs$c2_sources <- 710.25
    expect_equal(compute_infra_budget(ex$inputs)$total,2410.25)
  })
})
