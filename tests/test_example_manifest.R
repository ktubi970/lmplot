source(file.path("..", "R", "mod_model.R"))

test_that("real-data manifest covers the seven models exactly", {
  manifest <- utils::read.csv(
    file.path("..", "data", "real", "manifest.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_equal(nrow(manifest), 7L)
  expect_setequal(manifest$model_type, model_ids())
  expect_identical(anyDuplicated(manifest$example_id), 0L)
  expect_identical(anyDuplicated(manifest$model_type), 0L)
  required <- c(
    "example_id", "model_type", "title", "source_file", "source_url",
    "source_sha256", "source_doi", "publication_url", "publication_doi",
    "license_name", "license_url", "default_link", "response_source",
    "predictor_x_source", "predictor_y_source", "group_source",
    "response_label", "predictor_x_label", "predictor_y_label",
    "expected_rows", "adaptation_note", "preprocessing_summary"
  )
  expect_setequal(names(manifest), required)
  if ("preprocessing_summary" %in% names(manifest)) {
    expect_true(all(nzchar(trimws(manifest$preprocessing_summary))))
  }
  expect_true(all(nzchar(manifest$source_url)))
  expect_true(all(grepl("^[0-9a-f]{64}$", manifest$source_sha256)))
  expect_true(all(nzchar(manifest$license_name)))
  expect_true(all(nzchar(manifest$publication_url)))
  expect_identical(
    stats::setNames(manifest$expected_rows, manifest$model_type),
    c(lm_2d = 151L, lm_3d = 425L, glm_binomial_2d = 146L, glm_binomial = 146L,
      glm_poisson = 4177L, glm_gamma = 270L, glmm = 4059L)
  )
})

test_that("real-data manifest records deterministic preprocessing summaries", {
  manifest <- utils::read.csv(
    file.path("..", "data", "real", "manifest.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  skip_if_not(
    "preprocessing_summary" %in% names(manifest),
    "preprocessing_summary is not implemented yet"
  )
  expected <- c(
    lm_2d = paste(
      "From 152 Ad\u00e9lie source rows, retain complete finite flipper",
      "length and body mass values; remove 1 incomplete row, retain 151",
      "rows, and apply no unit conversion."
    ),
    lm_3d = paste(
      "Verify and extract Concrete_Data.xls, retain rows with age exactly",
      "28 days, and map cement, water, and compressive strength; retain",
      "425 rows with kg/m\u00b3 and MPa unchanged."
    ),
    glm_binomial_2d = paste(
      "From 152 Ad\u00e9lie source rows, retain finite culmen length",
      "with Sex equal to FEMALE or MALE, sort by Sample Number, and encode",
      "FEMALE = 1 and MALE = 0; retain 146 rows."
    ),
    glm_binomial = paste(
      "From 152 Ad\u00e9lie source rows, retain finite culmen length and",
      "body mass with Sex equal to FEMALE or MALE, sort by Sample Number,",
      "and encode FEMALE = 1 and MALE = 0; retain 146 rows (73/73)."
    ),
    glm_poisson = paste(
      "Retain all 4,177 source rows, convert normalized Length and",
      "Shell_weight by \u00d7200 to millimetres and grams, and keep integer",
      "Rings unchanged."
    ),
    glm_gamma = paste(
      "From 517 source rows, retain area > 0, remove 247 zero-area rows,",
      "and retain 270 rows; temperature (\u00b0C), relative humidity (%),",
      "and area (ha) remain unchanged."
    ),
    glmm = paste(
      "Verify and extract Exam.rda, retain all 4,059 rows, order and",
      "factor school into 65 levels, and map standLRT, schavg, and",
      "normexam; apply no unit conversion."
    )
  )
  expect_identical(
    stats::setNames(manifest$preprocessing_summary, manifest$model_type),
    expected
  )
})
