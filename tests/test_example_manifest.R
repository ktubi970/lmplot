source(file.path("..", "R", "mod_model.R"))

test_that("real-data manifest covers the six beta models exactly", {
  manifest <- utils::read.csv(
    file.path("..", "data", "real", "manifest.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_equal(nrow(manifest), 6L)
  expect_setequal(manifest$model_type, model_ids())
  expect_identical(anyDuplicated(manifest$example_id), 0L)
  expect_identical(anyDuplicated(manifest$model_type), 0L)
  required <- c(
    "example_id", "model_type", "title", "source_file", "source_url",
    "source_sha256", "source_doi", "publication_url", "publication_doi",
    "license_name", "license_url", "default_link", "response_source",
    "predictor_x_source", "predictor_y_source", "group_source",
    "response_label", "predictor_x_label", "predictor_y_label",
    "expected_rows", "adaptation_note"
  )
  expect_setequal(names(manifest), required)
  expect_true(all(nzchar(manifest$source_url)))
  expect_true(all(grepl("^[0-9a-f]{64}$", manifest$source_sha256)))
  expect_true(all(nzchar(manifest$license_name)))
  expect_true(all(nzchar(manifest$publication_url)))
  expect_identical(
    stats::setNames(manifest$expected_rows, manifest$model_type),
    c(lm_2d = 151L, lm_3d = 425L, glm_binomial = 146L,
      glm_poisson = 4177L, glm_gamma = 270L, glmm = 4059L)
  )
})
