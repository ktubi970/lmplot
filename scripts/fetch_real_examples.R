sha256_file <- function(path) {
  paste(as.character(digest::digest(path, algo = "sha256", file = TRUE)), collapse = "")
}

manifest_path <- function(root = ".") file.path(root, "data", "real", "manifest.csv")

source_specs <- function(root = ".") {
  manifest <- utils::read.csv(manifest_path(root), stringsAsFactors = FALSE,
                              check.names = FALSE)
  specs <- unique(manifest[c("source_file", "source_url", "source_sha256")])
  specs[order(specs$source_file), , drop = FALSE]
}

verify_source_file <- function(path, expected) {
  if (!file.exists(path)) stop("Missing reviewed source: ", path, call. = FALSE)
  actual <- sha256_file(path)
  if (!identical(tolower(actual), tolower(expected))) {
    stop("SHA-256 mismatch for ", basename(path), ": expected ", expected,
         ", got ", actual, call. = FALSE)
  }
  invisible(path)
}

fetch_real_sources <- function(destination = file.path("data", "real", "sources"),
                               root = ".") {
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  specs <- source_specs(root)
  for (row in seq_len(nrow(specs))) {
    target <- file.path(destination, specs$source_file[[row]])
    temporary <- tempfile(pattern = paste0(specs$source_file[[row]], "."))
    on.exit(unlink(temporary), add = TRUE)
    utils::download.file(specs$source_url[[row]], temporary,
                         mode = "wb", method = "libcurl", quiet = FALSE)
    verify_source_file(temporary, specs$source_sha256[[row]])
    if (!file.copy(temporary, target, overwrite = TRUE)) {
      stop("Could not install reviewed source: ", target, call. = FALSE)
    }
    verify_source_file(target, specs$source_sha256[[row]])
  }
  invisible(specs$source_file)
}

if (sys.nframe() == 0L) fetch_real_sources()
