#!/usr/bin/env Rscript

if (!file.exists("renv.lock") || !file.exists("renv/activate.R")) {
  stop("Run this explicit bootstrap from the LM Plot Explorer project root.", call. = FALSE)
}

# This separate command is the only local process authorized to fetch packages.
# Normal R, Shiny, and CLI startup leave the flag unset and never bootstrap.
Sys.setenv(LMPLOT_EXPLICIT_BOOTSTRAP = "1")
source("renv/activate.R")
renv::restore(prompt = FALSE)
if (!isTRUE(renv::status()$synchronized)) {
  stop("The restored project library does not match renv.lock.", call. = FALSE)
}
cat("Bootstrap complete.\n")
