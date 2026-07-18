library(shiny)
library(bslib)
library(plotly)
library(DT)

app_root <- if (file.exists(file.path("R", "config.R"))) "." else ".."
source(file.path(app_root, "R", "config.R"), local = TRUE)
source(file.path(app_root, "R", "mod_model.R"), local = TRUE)
source(file.path(app_root, "R", "mod_simulation.R"), local = TRUE)
source(file.path(app_root, "R", "mod_visualization.R"), local = TRUE)

model_choices <- stats::setNames(
  model_ids(),
  vapply(MODEL_REGISTRY, `[[`, character(1), "label")
)

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
    shiny::uiOutput("link_ui"),
    sim_ui("simulation"),
    shiny::actionButton(
      "generate", "Generate & Fit",
      class = "btn-primary w-100"
    ),
    shiny::checkboxInput(
      "show_surface", "Show fitted surface", TRUE
    ),
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
  output$link_ui <- shiny::renderUI({
    config <- model_config(input$model_type)
    if (length(config$links) == 1L) {
      return(shiny::div(
        style = "display:none;",
        shiny::selectInput(
          "link_sel", NULL,
          choices = config$links,
          selected = config$default_link
        )
      ))
    }
    shiny::selectInput(
      "link_sel", "Link",
      choices = config$links,
      selected = config$default_link
    )
  })

  link_selection <- shiny::reactiveVal(NULL)

  shiny::observeEvent(input$model_type, {
    config <- model_config(input$model_type)
    link_selection(list(
      model_type = input$model_type,
      link = config$default_link,
      awaiting_default_ack = TRUE
    ))
    shiny::updateSelectInput(
      session,
      "link_sel",
      choices = config$links,
      selected = config$default_link
    )
  }, ignoreInit = FALSE, priority = 100)

  shiny::observeEvent(input$link_sel, {
    state <- link_selection()
    shiny::req(state)
    default_link <- model_config(input$model_type)$default_link
    if (isTRUE(state$awaiting_default_ack)) {
      if (identical(input$link_sel, default_link)) {
        link_selection(list(
          model_type = input$model_type,
          link = default_link,
          awaiting_default_ack = FALSE
        ))
      }
      return()
    }
    if (
      identical(state$model_type, input$model_type) &&
      input$link_sel %in% valid_links(input$model_type)
    ) {
      link_selection(list(
        model_type = input$model_type,
        link = input$link_sel,
        awaiting_default_ack = FALSE
      ))
    }
  }, ignoreInit = TRUE)

  selected_link <- shiny::reactive({
    state <- link_selection()
    shiny::req(state, identical(state$model_type, input$model_type))
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
      generated <- simulation()
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
    build_main_plot(
      result$data,
      result$fit,
      result$model_type,
      input$show_surface %||% TRUE
    )
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
  output$data_table <- DT::renderDT({
    result <- last_result()
    shiny::req(result)
    DT::datatable(
      enrich_data(result$data, result$fit),
      options = list(pageLength = 8)
    )
  })
  output$download_data <- shiny::downloadHandler(
    filename = function() paste0("lmplot-", Sys.Date(), ".csv"),
    content = function(file) {
      result <- last_result()
      shiny::req(result)
      utils::write.csv(
        enrich_data(result$data, result$fit),
        file,
        row.names = FALSE
      )
    }
  )
}

shiny::shinyApp(ui, server)
