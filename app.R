library(shiny)
library(bslib)
library(plotly)
library(DT)

app_root <- if (file.exists(file.path("R", "config.R"))) "." else ".."
source(file.path(app_root, "R", "config.R"), local = TRUE)
source(file.path(app_root, "R", "mod_model.R"), local = TRUE)
source(file.path(app_root, "R", "mod_simulation.R"), local = TRUE)
source(file.path(app_root, "R", "mod_visualization.R"), local = TRUE)
source(file.path(app_root, "R", "mod_examples.R"), local = TRUE)

model_choices <- stats::setNames(
  model_ids(),
  vapply(MODEL_REGISTRY, `[[`, character(1), "label")
)

scientific_variable_definition <- function(label, source) {
  shiny::tagList(
    label,
    " (source: ",
    shiny::tags$code(source),
    ")"
  )
}

ui <- bslib::page_sidebar(
  title = shiny::div(
    "LM Plot Explorer ",
    shiny::span(APP_VERSION, class = "version-badge")
  ),
  theme = bslib::bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#2563eb"
  ),
  sidebar = bslib::sidebar(
    shiny::selectInput(
      "model_type", "Model",
      choices = model_choices,
      selected = "lm_3d"
    ),
    shiny::radioButtons(
      "data_source", "Data source",
      choices = c("Simulation" = "simulation", "Real data" = "real"),
      selected = "simulation", inline = TRUE
    ),
    shiny::uiOutput("example_info"),
    shiny::uiOutput("link_ui"),
    shiny::conditionalPanel(
      "input.data_source === 'simulation'",
      sim_ui("simulation")
    ),
    shiny::actionButton(
      "generate", "Generate & Fit",
      class = "btn-primary w-100"
    ),
    shiny::uiOutput("surface_ui"),
    shiny::downloadButton(
      "download_data", "Download enriched CSV",
      class = "w-100"
    )
  ),
  shiny::tags$head(
    shiny::tags$link(
      rel = "stylesheet",
      type = "text/css",
      href = "style.css"
    )
  ),
  bslib::layout_column_wrap(
    width = 1,
    bslib::card(
      full_screen = TRUE,
      bslib::card_header("Visualization"),
      plotly::plotlyOutput("main_plot", height = "480px")
    ),
    bslib::layout_column_wrap(
      width = 1 / 2,
      bslib::card(
        bslib::card_header("Model summary"),
        shiny::verbatimTextOutput("model_summary")
      ),
      bslib::card(
        bslib::card_header("Simulation code"),
        shiny::verbatimTextOutput("sim_code")
      ),
      bslib::navset_card_tab(
        title = "Diagnostics & data",
        bslib::nav_panel(
          "Diagnostics",
          shiny::plotOutput("diag_plots", height = "380px")
        ),
        bslib::nav_panel("Data", DT::DTOutput("data_table"))
      )
    )
  )
)

server <- function(input, output, session) {
  output$surface_ui <- shiny::renderUI({
    shiny::req(input$model_type)
    if (identical(input$model_type, "lm_2d")) return(NULL)
    shiny::checkboxInput(
      "show_surface", "Show fitted surface", TRUE
    )
  })

  link_spec <- shiny::reactive({
    config <- model_config(input$model_type)
    real <- identical(input$data_source, "real")
    default <- config$default_link
    choices <- config$links
    if (real) {
      example_id <- example_for_model(input$model_type, root = app_root)
      example <- example_config(
        example_id,
        root = app_root
      )
      default <- example$default_link
      choices <- stats::setNames(
        config$links,
        ifelse(
          config$links == default,
          paste0(config$links, " (literature-backed)"),
          paste0(config$links, " (exploratory)")
        )
      )
    }
    list(
      config = config,
      default = default,
      choices = choices
    )
  })

  output$link_ui <- shiny::renderUI({
    spec <- link_spec()
    if (length(spec$config$links) == 1L) {
      return(shiny::tags$input(
        id = "link_sel", type = "hidden", value = spec$default
      ))
    }
    shiny::selectInput(
      "link_sel", "Link",
      choices = spec$choices,
      selected = spec$default
    )
  })

  output$example_info <- shiny::renderUI({
    shiny::req(identical(input$data_source, "real"))
    metadata <- example_config(
      example_for_model(input$model_type, root = app_root),
      root = app_root
    )
    config <- model_config(metadata$model_type)
    publication_label <- if (nzchar(metadata$publication_doi)) {
      metadata$publication_doi
    } else {
      metadata$publication_url
    }
    bslib::card(
      class = "example-provenance",
      bslib::card_header(metadata$title),
      shiny::tags$dl(
        shiny::tags$dt("Model family"),
        shiny::tags$dd(config$label),
        shiny::tags$dt("Literature-backed default link"),
        shiny::tags$dd(metadata$default_link),
        shiny::tags$dt("Publication"),
        shiny::tags$dd(shiny::tags$a(
          href = metadata$publication_url,
          target = "_blank", publication_label
        )),
        shiny::tags$dt("Dataset"),
        shiny::tags$dd(shiny::tags$a(
          href = metadata$source_url,
          target = "_blank", metadata$source_doi
        )),
        shiny::tags$dt("License"),
        shiny::tags$dd(shiny::tags$a(
          href = metadata$license_url,
          target = "_blank", metadata$license_name
        )),
        shiny::tags$dt("Rows"),
        shiny::tags$dd(format(metadata$expected_rows, big.mark = ",")),
        shiny::tags$dt("Response"),
        shiny::tags$dd(scientific_variable_definition(
          metadata$response_label,
          metadata$response_source
        )),
        shiny::tags$dt("Predictor X"),
        shiny::tags$dd(scientific_variable_definition(
          metadata$predictor_x_label,
          metadata$predictor_x_source
        )),
        if (nzchar(metadata$predictor_y_source)) shiny::tagList(
          shiny::tags$dt("Predictor Y"),
          shiny::tags$dd(scientific_variable_definition(
            metadata$predictor_y_label,
            metadata$predictor_y_source
          ))
        ),
        if (nzchar(metadata$group_source)) shiny::tagList(
          shiny::tags$dt("Group"),
          shiny::tags$dd(scientific_variable_definition(
            tools::toTitleCase(gsub(
              "_", " ", metadata$group_source, fixed = TRUE
            )),
            metadata$group_source
          ))
        ),
        shiny::tags$dt("Preprocessing"),
        shiny::tags$dd(metadata$preprocessing_summary),
        shiny::tags$dt("Interpretation / pedagogical adaptation"),
        shiny::tags$dd(metadata$adaptation_note)
      )
    )
  })

  link_selection <- shiny::reactiveVal(NULL)

  shiny::observeEvent(list(input$model_type, input$data_source), {
    spec <- link_spec()
    link_selection(list(
      model_type = input$model_type,
      data_source = input$data_source,
      link = spec$default,
      awaiting_default_ack = TRUE
    ))
    shiny::updateSelectInput(
      session,
      "link_sel",
      choices = spec$choices,
      selected = spec$default
    )
  }, ignoreInit = FALSE, priority = 100)

  shiny::observeEvent(input$link_sel, {
    state <- link_selection()
    shiny::req(state)
    default_link <- link_spec()$default
    if (isTRUE(state$awaiting_default_ack)) {
      if (identical(input$link_sel, default_link)) {
        link_selection(list(
          model_type = input$model_type,
          data_source = input$data_source,
          link = default_link,
          awaiting_default_ack = FALSE
        ))
      }
      return()
    }
    if (
      identical(state$model_type, input$model_type) &&
      identical(state$data_source, input$data_source) &&
      input$link_sel %in% valid_links(input$model_type)
    ) {
      link_selection(list(
        model_type = input$model_type,
        data_source = input$data_source,
        link = input$link_sel,
        awaiting_default_ack = FALSE
      ))
    }
  }, ignoreInit = TRUE)

  selected_link <- shiny::reactive({
    state <- link_selection()
    shiny::req(
      state,
      identical(state$model_type, input$model_type),
      identical(state$data_source, input$data_source)
    )
    validate_model_link(state$model_type, state$link)
  })

  simulation <- sim_server(
    "simulation",
    shiny::reactive(input$model_type),
    selected_link,
    shiny::reactive(input$generate)
  )
  last_result <- shiny::reactiveVal(NULL)

  shiny::observeEvent(input$generate, {
    tryCatch({
      if (identical(input$data_source, "real")) {
        model_type <- input$model_type
        link <- selected_link()
        example <- load_real_example(
          example_for_model(
            model_type,
            root = app_root
          ),
          root = app_root
        )
        generated <- list(
          data = example$analysis,
          display = example$display,
          example = example,
          model_type = model_type,
          link = link,
          code = paste0(
            "example <- load_real_example(\"",
            example$id,
            "\")\n",
            "fit <- fit_model(example$analysis, \"",
            model_type,
            "\", \"",
            link,
            "\")"
          )
        )
      } else {
        simulated <- simulation()
        generated <- list(
          data = simulated$data,
          display = simulated$data,
          example = NULL,
          model_type = simulated$model_type,
          link = simulated$link,
          code = simulated$code
        )
      }
      fit <- withCallingHandlers(
        fit_model(
          generated$data,
          generated$model_type,
          generated$link
        ),
        warning = function(warning) {
          showNotification(conditionMessage(warning), type = "warning")
          invokeRestart("muffleWarning")
        }
      )
      last_result(list(
        data = generated$data,
        display = generated$display,
        example = generated$example,
        fit = fit,
        model_type = generated$model_type,
        link = generated$link,
        code = generated$code
      ))
    }, error = function(error) {
      showNotification(conditionMessage(error), type = "error")
    })
  }, ignoreInit = TRUE)

  output$main_plot <- plotly::renderPlotly({
    result <- last_result()
    shiny::req(result)
    if (!is.null(result$example)) {
      example_plot(
        result$example,
        result$fit,
        input$show_surface %||% TRUE
      )
    } else {
      build_main_plot(
        result$data,
        result$fit,
        result$model_type,
        input$show_surface %||% TRUE
      )
    }
  })
  output$model_summary <- shiny::renderPrint({
    result <- last_result()
    shiny::req(result)
    summary(result$fit)
  })
  output$sim_code <- shiny::renderText({
    result <- last_result()
    shiny::req(result)
    result$code
  })
  output$diag_plots <- shiny::renderPlot({
    result <- last_result()
    shiny::req(result)
    print(build_diagnostic_plot(result$fit))
  })

  display_result <- function(result) {
    if (!is.null(result$example)) {
      enrich_real_example(result$example, result$fit)
    } else {
      enrich_data(result$data, result$fit)
    }
  }

  output$data_table <- DT::renderDT({
    result <- last_result()
    shiny::req(result)
    DT::datatable(
      display_result(result),
      options = list(pageLength = 8)
    )
  })
  output$download_data <- shiny::downloadHandler(
    filename = function() paste0("lmplot-", Sys.Date(), ".csv"),
    content = function(file) {
      result <- last_result()
      shiny::req(result)
      utils::write.csv(
        display_result(result),
        file,
        row.names = FALSE
      )
    }
  )
}

shiny::shinyApp(ui, server)
