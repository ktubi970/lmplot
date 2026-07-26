source(file.path("..", "R", "mod_model.R"))
source(file.path("..", "R", "mod_simulation.R"))
source(file.path("..", "R", "mod_visualization.R"))
source(file.path("..", "R", "mod_examples.R"))

test_that("all six examples have complete offline artifacts", {
  ids <- example_ids(root = "..")
  expect_equal(length(ids), 6L)

  for (id in ids) {
    example <- load_real_example(id, root = "..")
    metadata <- example$metadata
    readme <- file.path("..", "data", "real", id, "README.md")
    png <- file.path(
      "..", "artifacts", "real-examples", paste0(id, ".png")
    )

    expect_true(file.exists(readme), info = id)
    if (!file.exists(readme)) {
      next
    }

    text <- paste(readLines(readme, warn = FALSE), collapse = "\n")
    expect_match(text, metadata$publication_url, fixed = TRUE, info = id)
    expect_match(text, metadata$source_url, fixed = TRUE, info = id)
    expect_match(text, metadata$license_url, fixed = TRUE, info = id)
    expect_true(file.exists(png), info = id)
    expect_gt(file.info(png)$size, 10000)

    fit <- fit_model(
      example$analysis,
      metadata$model_type,
      metadata$default_link
    )
    expect_s3_class(example_plot(example, fit), "plotly")
  }
})
