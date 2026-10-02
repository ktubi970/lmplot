#!/usr/bin/env Rscript
# Run with --vanilla: native renv activation does not apply to browser R.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: Rscript --vanilla scripts/export_shinylive.R DESTINATION", call. = FALSE)
script_arg <- grep("^--file=", commandArgs(), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", script_arg), mustWork = TRUE)))
destination <- args[[1L]]
if (file.exists(destination) && (!dir.exists(destination) ||
    length(list.files(destination, all.files = TRUE, no.. = TRUE)))) {
  stop("Export destination must be empty or not exist.", call. = FALSE)
}
if (!requireNamespace("shinylive", quietly = TRUE) || packageVersion("shinylive") != "0.5.0") {
  stop("Install shinylive 0.5.0 in the build library before exporting.", call. = FALSE)
}
source(file.path(root, "scripts", "shinylive_bundle.R"))
stage <- tempfile("lmplot-public-app-")
tryCatch({
  stage_shinylive_app(root, stage)
  shinylive::export(stage, destination, assets_version = "0.10.12",
                   wasm_packages = TRUE, max_filesize = 100 * 1024^2,
                   quiet = FALSE, template_params = list(title = "LM Plot Explorer"))
  file.create(file.path(destination, ".nojekyll"))
}, finally = unlink(stage, recursive = TRUE))
