# helper-browser.R: Configure Chromote for robust headless browser execution.
# On busy CI environments (such as GitHub Actions Windows runners), launching the
# Shiny background process and completing Page.navigate can take more than Chromote's
# default 10-second command timeout. We raise default_timeout to 60 seconds so
# Page.navigate does not prematurely fail before shinytest2's load_timeout (100s).

configure_chromote_timeout <- function(timeout = 60) {
  if (requireNamespace("chromote", quietly = TRUE)) {
    try({
      chromote:::Chromote$set("public", "default_timeout", timeout, overwrite = TRUE)
      if (chromote:::has_default_chromote_object()) {
        chromote::default_chromote_object()$default_timeout <- timeout
      }
    }, silent = TRUE)
  }
}

configure_chromote_timeout(60)
