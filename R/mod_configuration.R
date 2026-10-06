configuration_ui <- function(id, trusted_local = FALSE,
    model_choices = stats::setNames(model_ids(), vapply(MODEL_REGISTRY, `[[`, character(1), "label"))) {
  ns <- shiny::NS(id)
  shiny::tagList(shiny::h2("Configuration"),
    shiny::selectInput(ns("model_type"), "Model", model_choices),
    shiny::selectInput(ns("data_source"), "Data source", c("Simulation" = "simulation", "Real data" = "real")),
    shiny::uiOutput(ns("link_ui")),
    shiny::conditionalPanel("input.data_source === 'simulation'", ns = ns,
      shiny::tags$details(class = "simulation-settings", shiny::tags$summary("Simulation settings"),
        sim_ui(ns("simulation"), trusted_local))),
    shiny::uiOutput(ns("example_preview")),
    shiny::p(class = "configuration-hint", "Results update automatically."))
}

configuration_server <- function(id, trusted_local = FALSE, root = ".",
    request_constructor = new_analysis_request, registry = MODEL_REGISTRY,
    example_lookup = example_config, example_for = example_for_model) {
  validate_simulation_trust(trusted_local)
  stopifnot(is.function(request_constructor), is.function(example_lookup), is.function(example_for))
  shiny::moduleServer(id, function(input, output, session) {
    model <- shiny::reactive(input$model_type %||% "lm_2d")
    source <- shiny::reactive(input$data_source %||% "simulation")
    example <- shiny::reactive({
      if (source() != "real") return(NULL)
      example_lookup(example_for(model(), root), root)
    })
    link_spec <- shiny::reactive({
      config <- registry[[model()]]
      shiny::req(config)
      default <- if (source() == "real") example()$default_link else config$default_link
      choices <- config$links
      if (source() == "real") names(choices) <- paste0(choices,
        ifelse(choices == default, " (literature-backed)", " (exploratory)"))
      list(default = default, choices = choices)
    })
    link_selection <- shiny::reactiveVal(NULL)
    shiny::observeEvent(list(model(), source()), {
      spec <- link_spec()
      # Shiny does not resend an unchanged select value. A shared default is
      # already acknowledged; different old values still wait for the reset.
      awaiting_ack <- !identical(shiny::isolate(input$link_sel), spec$default)
      link_selection(list(model = model(), source = source(), link = spec$default,
        awaiting_default_ack = awaiting_ack))
      shiny::updateSelectInput(session, "link_sel", choices = spec$choices, selected = spec$default)
    }, priority = 100)
    shiny::observeEvent(input$link_sel, {
      state <- link_selection(); shiny::req(state)
      if (state$awaiting_default_ack) {
        if (identical(input$link_sel, link_spec()$default)) {
          state$awaiting_default_ack <- FALSE; link_selection(state)
        }
        return()
      }
      if (identical(state$model, model()) && identical(state$source, source()) &&
          input$link_sel %in% registry[[model()]]$links) {
        state$link <- input$link_sel; link_selection(state)
      }
    }, ignoreInit = TRUE)
    selected_link <- shiny::reactive({
      state <- link_selection()
      if (is.null(state) || !identical(state$model, model()) || !identical(state$source, source())) return(link_spec()$default)
      state$link
    })
    output$link_ui <- shiny::renderUI({
      spec <- link_spec()
      if (length(spec$choices) == 1L) return(shiny::tagList(
        shiny::p("Link: ", spec$default),
        shiny::tags$input(id = session$ns("link_sel"), type = "hidden", value = spec$default)))
      shiny::selectInput(session$ns("link_sel"), "Link function", spec$choices, selected = spec$default)
    })
    output$example_preview <- shiny::renderUI({
      metadata <- example()
      if (is.null(metadata)) return(NULL)
      shiny::p(metadata$title, " — ", metadata$expected_rows, " prepared rows.")
    })
    simulation <- sim_server("simulation", model, selected_link, trusted_local)
    payload <- shiny::reactive({
      out <- list(schema_version = "lmplot-analysis-request/1.0", model_type = model(),
        data_source = source(), link = selected_link(), grid_length_out = 30L)
      if (source() == "real") out$example_id <- example_for(model(), root) else {
        values <- simulation()
        out$simulation <- values$parameters; out$expert <- values$expert
      }
      validated <- request_constructor(out, trusted_local = trusted_local)
      # Browser controls can acknowledge whole values with different numeric
      # types. Normalize both integer and real parameters before deduplication.
      if (source() == "simulation") {
        out$simulation <- validated$simulation
        for (key in setdiff(names(out$simulation), c("n", "seed", "groups", "pattern"))) {
          out$simulation[[key]] <- as.double(out$simulation[[key]])
        }
      }
      out
    })
    ready <- shiny::reactive({
      state <- link_selection()
      !is.null(input$model_type) && !is.null(state) && identical(state$model, model()) &&
        identical(state$source, source()) &&
        (length(registry[[model()]]$links) == 1L || !state$awaiting_default_ack)
    })
    list(payload = payload, ready = ready)
  })
}
