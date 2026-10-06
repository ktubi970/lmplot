Sys.unsetenv("LMPLOT_TRUSTED_LOCAL")
stopifnot(getRversion() == "4.6.0", isTRUE(renv::status()$synchronized))
shiny::runApp(".", host = "127.0.0.1", port = 3839, launch.browser = FALSE)
