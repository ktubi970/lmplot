fetch_path <- file.path("..", "scripts", "fetch_real_examples.R")
if (file.exists(fetch_path)) source(fetch_path)

test_that("SHA-256 helper hashes file bytes", {
  file <- tempfile()
  on.exit(unlink(file), add = TRUE)
  writeBin(charToRaw("abc"), file)
  expect_identical(
    sha256_file(file),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
})

test_that("all reviewed sources exist and match the manifest", {
  specs <- source_specs("..")
  expect_equal(nrow(specs), 5L) # Adélie is shared by two examples.
  for (row in seq_len(nrow(specs))) {
    path <- file.path("..", "data", "real", "sources", specs$source_file[[row]])
    expect_true(file.exists(path), info = specs$source_file[[row]])
    expect_silent(verify_source_file(path, specs$source_sha256[[row]]))
  }
})
