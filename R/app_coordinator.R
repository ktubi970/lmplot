log_analysis_error <- function(error) {
  cat("Analysis error: ", conditionMessage(error), "\nCall: ",
    paste(deparse(conditionCall(error)), collapse = " "), "\n", file = stderr(), sep = "")
}

create_app_coordinator <- function(services, trusted_local = FALSE, root = ".",
    request_constructor = new_analysis_request, run_analysis = run_analysis_usecase,
    logger = log_analysis_error) {
  validate_simulation_trust(trusted_local)
  stopifnot(is.function(request_constructor), is.function(run_analysis), is.function(logger))
  state <- shiny::reactiveVal(list(result = NULL, successful_request = NULL,
    warnings = character(), public_error = NULL, stale = FALSE, running = FALSE, generation = 0L))
  analyze <- function(payload) {
    before <- shiny::isolate(state())
    if (before$running) return(invisible(FALSE))
    current <- before; current$running <- TRUE; current$public_error <- NULL
    state(current)
    on.exit({ current <- shiny::isolate(state()); current$running <- FALSE; state(current) }, add = TRUE)
    success <- tryCatch({
      request <- request_constructor(payload, trusted_local = trusted_local)
      result <- run_analysis(request, services, root)
      stopifnot(inherits(result, "analysis_result"), is.data.frame(result$data),
        is.data.frame(result$coefficients), is.list(result$metrics), is.list(result$diagnostics),
        is.data.frame(result$prediction_grid), is.list(result$model_brain),
        identical(result$model_brain$schema_version, "model-brain/1.0"),
        result$model_brain$n == nrow(result$data))
      # The use case validated Model Brain once. Check presentation alignment, not the schema again.
      analysis_display_data(result)
      state(list(result = result, successful_request = request,
        warnings = result$warnings, public_error = NULL, stale = FALSE,
        running = FALSE, generation = before$generation + 1L))
      TRUE
    }, error = function(error) {
      before$public_error <- "Analysis failed. Review the settings and try again."
      before$stale <- !is.null(before$result); before$running <- FALSE
      state(before)
      tryCatch(logger(error), error = function(logging_error) {
        cat("Analysis error logging failed.\n", file = stderr())
      })
      FALSE
    })
    invisible(success)
  }
  list(result = shiny::reactive(state()$result),
    successful_request = shiny::reactive(state()$successful_request),
    warnings = shiny::reactive(state()$warnings), public_error = shiny::reactive(state()$public_error),
    stale = shiny::reactive(state()$stale), running = shiny::reactive(state()$running),
    generation = shiny::reactive(state()$generation), analyze = analyze)
}

coordinator_status_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(shiny::div(role = "status", `aria-live` = "polite", shiny::textOutput(ns("status"))),
    shiny::div(role = "alert", shiny::textOutput(ns("error"))))
}

coordinator_status_server <- function(id, coordinator) {
  shiny::moduleServer(id, function(input, output, session) {
    output$error <- shiny::renderText(coordinator$public_error() %||% "")
    output$status <- shiny::renderText({
      if (coordinator$running()) return("Analysis running.")
      if (coordinator$stale()) return("Showing the last successful analysis. The latest analysis failed.")
      if (is.null(coordinator$result())) return("Choose settings and select Generate & fit model.")
      if (length(coordinator$warnings())) return("Analysis complete with warnings. Review Diagnostic evidence and model limitations.")
      "Analysis complete. Inspect the results and diagnostic evidence."
    })
  })
}
