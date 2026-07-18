library(testthat)
library(lme4)

source('../app.R')

test_that("generate_data returns correct structures", {
  # 2D LM
  df2d <- generate_data(100, type = "lm_2d")
  expect_equal(nrow(df2d), 100)
  expect_true("X" %in% names(df2d))
  
  # Logistic GLM
  df_log <- generate_data(100, type = "glm_logistic")
  expect_true(all(df_log$Z %in% c(0, 1)))
  
  # Poisson GLM
  df_poi <- generate_data(100, type = "glm_poisson")
  expect_true(all(df_poi$Z >= 0))
  expect_true(all(df_poi$Z == round(df_poi$Z)))
  
  # GLMM
  df_mm <- generate_data(100, type = "glmm")
  expect_true("Group" %in% names(df_mm))
  expect_equal(length(unique(df_mm$Group)), 5)

  df_mm_uneven <- generate_data(103, type = "glmm")
  expect_equal(nrow(df_mm_uneven), 103)
  expect_equal(length(unique(df_mm_uneven$Group)), 5)
})

test_that("fit_model returns correct model classes", {
  expect_s3_class(fit_model(generate_data(100, "lm_3d"), "lm_3d"), "lm")
  expect_s3_class(fit_model(generate_data(100, "glm_logistic"), "glm_logistic"), "glm")
  expect_s3_class(fit_model(generate_data(100, "glm_poisson"), "glm_poisson"), "glm")
  expect_s4_class(fit_model(generate_data(100, "glmm"), "glmm"), "lmerMod")
})

test_that("app includes stylesheet for current plot output", {
  rendered_ui <- htmltools::renderTags(ui)
  ui_html <- paste(
    as.character(rendered_ui$html),
    as.character(rendered_ui$head),
    collapse = "\n"
  )
  css <- readLines("../www/style.css", warn = FALSE)

  expect_true(grepl("style.css", ui_html, fixed = TRUE))
  expect_true(any(grepl("#main_plot", css, fixed = TRUE)))
})
