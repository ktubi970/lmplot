analysis_observations <- function(result) {
  records <- result$model_brain$observations[seq_len(result$model_brain$n)]
  stopifnot(length(records) == nrow(result$data),
    identical(vapply(records, `[[`, integer(1), "index"), seq_len(nrow(result$data))))
  records
}

analysis_display_data <- function(result) {
  records <- analysis_observations(result)
  data <- result$display %||% result$data
  stopifnot(nrow(data) == length(records))
  data$.fitted <- vapply(records, `[[`, numeric(1), "prediction")
  data$.residual <- vapply(records, `[[`, numeric(1), "residual")
  data$.prediction_mode <- vapply(records, `[[`, character(1), 'prediction_mode')
  data$.response_unit <- result$model_brain$units$z %||% 'unit not specified'
  data$.x_unit <- result$model_brain$units$x %||% 'unit not specified'
  if ('Y' %in% names(result$data)) data$.y_unit <- result$model_brain$units$y %||% 'unit not specified'
  data$.observed_response_label <- result$model_brain$labels$z
  data$.fitted_response_label <- paste('Fitted mean:', result$labels$z)
  data
}

analysis_prediction_context <- function(result) {
  if (result$model_type == 'glmm') {
    return(paste('Observed-row fitted values are conditional on estimated group random intercepts;',
      'response residuals are observed minus these conditional fitted values.',
      'The Overview surface is the fixed-effects population mean, without random intercepts.'))
  }
  'Fitted values are model mean responses; response residuals are observed minus fitted values.'
}

data_provenance_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(shiny::h2("Data & provenance"), shiny::uiOutput(ns("provenance")),
    shiny::downloadButton(ns("download"), "Download enriched CSV"), DT::DTOutput(ns("table")),
    shiny::h3("Reproducible R code"),
    shiny::p("Run this code with the LM Plot Explorer R helpers loaded from the project folder."),
    shiny::div(class = "repro-code-card", shiny::verbatimTextOutput(ns("code"))))
}

data_provenance_server <- function(id, result, successful_request = shiny::reactive(NULL),
    display_data = analysis_display_data) {
  stopifnot(is.function(result), is.function(successful_request), is.function(display_data))
  shiny::moduleServer(id, function(input, output, session) {
    displayed <- shiny::reactive({ shiny::req(result()); display_data(result()) })
    output$table <- DT::renderDT({ DT::datatable(displayed(), rownames = FALSE,
      filter = "top", options = list(pageLength = 10, scrollX = TRUE),
      caption = paste('Committed observations.', analysis_prediction_context(result()),
        'Response unit:', result()$model_brain$units$z %||% 'unit not specified')) })
    output$download <- shiny::downloadHandler(filename = function() "lmplot-enriched-data.csv",
      content = function(file) utils::write.csv(displayed(), file, row.names = FALSE, na = "NA"))
    output$code <- shiny::renderText({ shiny::req(result()); result()$code })
    output$provenance <- shiny::renderUI({
      value <- result()
      if (is.null(value)) return(shiny::p("No analysis yet. Generate a model to inspect its data and provenance."))
      if (is.null(value$example)) {
        request <- successful_request()
        return(shiny::tagList(shiny::h3("Simulated data"), shiny::p("Rows: ", nrow(value$data)),
          shiny::p("Synthetic observations illustrate model behavior; they are not empirical evidence."),
          if (!is.null(request)) shiny::tags$dl(lapply(names(request$simulation), function(key)
            shiny::tagList(shiny::tags$dt(key), shiny::tags$dd(as.character(request$simulation[[key]])))))))
      }
      metadata <- value$example$metadata
      fields <- c(publication_url = "Publication", publication_doi = "Publication DOI", source_url = "Source",
        license_name = "License", license_url = "License URL", source_sha256 = "Source SHA-256 checksum", preprocessing_summary = "Preparation",
        adaptation_note = "Adaptation and limitations", observed_response_label = 'Observed response (Z)',
        response_label = 'Predicted mean response', response_unit = 'Response unit', response_source = "Response source column",
        predictor_x_label = "Predictor X", predictor_x_source = "X source column",
        predictor_y_label = "Predictor Y", predictor_y_source = "Y source column", group_source = "Group source column")
      shiny::div(class = "example-provenance", shiny::h3(metadata$title), shiny::p("Rows: ", nrow(value$data)),
        shiny::tags$dl(
          shiny::tags$dt("Model family"), shiny::tags$dd(model_config(value$model_type)$label),
          shiny::tags$dt("Fitted link"), shiny::tags$dd(value$link),
          shiny::tags$dt("Literature-backed default link"), shiny::tags$dd(metadata$default_link),
          if (nzchar(metadata$group_source)) shiny::tagList(shiny::tags$dt("Group"),
            shiny::tags$dd(tools::toTitleCase(gsub("_", " ", metadata$group_source, fixed = TRUE)))),
          lapply(intersect(names(fields), names(metadata)), function(key)
          shiny::tagList(shiny::tags$dt(fields[[key]]), shiny::tags$dd(metadata[[key]])))))
    })
  })
}
