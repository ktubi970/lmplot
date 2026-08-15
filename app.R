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
source(file.path(app_root, "R", "mod_eli5.R"), local = TRUE)

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
    class = "d-flex align-items-center justify-content-between w-100 py-1",
    shiny::div(
      class = "d-flex align-items-center gap-2",
      shiny::span("🔬 LM Plot Explorer", class = "fw-bold fs-5 text-primary-emphasis"),
      shiny::span(APP_VERSION, class = "version-badge")
    ),
    shiny::span(
      "Scientific Statistical Cockpit • LM / GLM / GLMM",
      class = "badge bg-light text-secondary border rounded-pill px-3 py-1 fw-normal d-none d-md-inline-block"
    )
  ),
  theme = bslib::bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#2563eb"
  ),
  sidebar = bslib::sidebar(
    width = 320,
    bslib::accordion(
      id = "sidebar_controls",
      open = TRUE,
      multiple = TRUE,
      bslib::accordion_panel(
        "⚙️ Model & Link Specification",
        shiny::selectInput(
          "model_type", "Model Family",
          choices = model_choices,
          selected = "lm_2d"
        ),
        shiny::uiOutput("link_ui")
      ),
      bslib::accordion_panel(
        "📂 Data Context",
        shiny::radioButtons(
          "data_source", "Data Source",
          choices = c("Simulation" = "simulation", "Real data" = "real"),
          selected = "simulation", inline = TRUE
        ),
        shiny::uiOutput("example_info")
      ),
      bslib::accordion_panel(
        "🎛️ Simulation Parameters",
        shiny::conditionalPanel(
          "input.data_source === 'simulation'",
          sim_ui("simulation")
        )
      ),
      bslib::accordion_panel(
        "🛠️ Actions & Export",
        shiny::actionButton(
          "generate", "⚡ Generate & Fit Model",
          class = "btn-primary w-100 fw-bold mb-2"
        ),
        shiny::uiOutput("surface_ui"),
        shiny::downloadButton(
          "download_data", "📥 Download Enriched CSV",
          class = "btn-outline-secondary w-100"
        )
      )
    )
  ),
  shiny::tags$head(
    shiny::tags$link(
      rel = "stylesheet",
      type = "text/css",
      href = "style.css"
    )
  ),
  bslib::navset_card_tab(
    id = "main_nav_tabs",
    title = shiny::div(
      class = "d-flex align-items-center gap-2",
      shiny::span("📊 Explorer Cockpit", class = "fw-bold")
    ),
    bslib::nav_panel(
      title = shiny::div("📈 Main Plot"),
      value = "tab_main_plot",
      bslib::card(
        full_screen = TRUE,
        bslib::card_header(
          shiny::div(
            shiny::span("LEVEL 1", class = "level-badge"),
            "Main Plot (Response Surface & Observed Data)"
          )
        ),
        plotly::plotlyOutput("main_plot", height = "580px")
      )
    ),
    bslib::nav_panel(
      title = shiny::div("📊 Metrics & Summary"),
      value = "tab_metrics_summary",
      bslib::layout_column_wrap(
        width = 1,
        # ELI5 Natural Language Assistant Card
        eli5_ui("eli5_explainer"),

        # Status Overview (Executive Cockpit Banner)
        shiny::uiOutput("kpi_banner"),

        # Educational Metric Guide & Scientific Benchmarks Card
        shiny::tags$details(
          class = "mb-3 p-3 border rounded bg-white shadow-sm kpi-benchmark-guide",
          shiny::tags$summary(
            class = "fw-bold text-dark cursor-pointer d-flex align-items-center justify-content-between",
            shiny::span("💡 Guide d'Interprétation des Métriques & Seuils de Référence (Attendu vs Réel)", class = "fs-6 text-primary"),
            shiny::span(class = "badge bg-primary-subtle text-primary small", "Documentation Scientifique")
          ),
          shiny::div(
            class = "mt-3",
            shiny::div(
              class = "row g-3",
              shiny::div(
                class = "col-md-6 col-lg-3",
                shiny::div(
                  class = "p-3 border rounded bg-light h-100",
                  shiny::div(class = "fw-bold text-slate-800 mb-1", "📊 R² (Variance Expliquée)"),
                  shiny::div(class = "small text-secondary mb-2", shiny::tags$strong("Rôle : "), "Proportion de la variance de Z expliquée par le modèle."),
                  shiny::div(class = "small text-dark mb-1", shiny::tags$strong("Valeur attendue :"), " >70% (Fort), 50-70% (Bon), 20-50% (Modéré), <20% (Faible)."),
                  shiny::div(class = "small text-muted", shiny::tags$strong("Interprétation : "), "Un R² faible (ex. <15%) indique un effet réel mais une grande variabilité inexpliquée.")
                )
              ),
              shiny::div(
                class = "col-md-6 col-lg-3",
                shiny::div(
                  class = "p-3 border rounded bg-light h-100",
                  shiny::div(class = "fw-bold text-slate-800 mb-1", "⚖️ Critères AIC / BIC"),
                  shiny::div(class = "small text-secondary mb-2", shiny::tags$strong("Rôle : "), "Arbitrage entre qualité d'ajustement (LogLik) et parcimonie."),
                  shiny::div(class = "small text-dark mb-1", shiny::tags$strong("Valeur attendue :"), " Pas de seuil absolu. Plus le score est BAS, meilleur est le modèle."),
                  shiny::div(class = "small text-muted", shiny::tags$strong("Interprétation : "), "Sert à comparer des modèles concurrents (ex. 2D vs 3D) sur les mêmes données.")
                )
              ),
              shiny::div(
                class = "col-md-6 col-lg-3",
                shiny::div(
                  class = "p-3 border rounded bg-light h-100",
                  shiny::div(class = "fw-bold text-slate-800 mb-1", "🎯 Erreur Résiduelle (RSE)"),
                  shiny::div(class = "small text-secondary mb-2", shiny::tags$strong("Rôle : "), "Écart-type moyen des erreurs autour de la régression."),
                  shiny::div(class = "small text-dark mb-1", shiny::tags$strong("Valeur attendue :"), " Proche du bruit théorique (ex. ~1.000) ; ratio GLM ~1.0."),
                  shiny::div(class = "small text-muted", shiny::tags$strong("Interprétation : "), "Valide l'homogénéité de la variance et donne la marge d'erreur en unités de Z.")
                )
              ),
              shiny::div(
                class = "col-md-6 col-lg-3",
                shiny::div(
                  class = "p-3 border rounded bg-light h-100",
                  shiny::div(class = "fw-bold text-slate-800 mb-1", "🩺 Santé & Échantillon (N)"),
                  shiny::div(class = "small text-secondary mb-2", shiny::tags$strong("Rôle : "), "Taille d'échantillon N et stabilité de l'estimation."),
                  shiny::div(class = "small text-dark mb-1", shiny::tags$strong("Valeur attendue :"), " N ≥ 30 et statut CONVERGED (OK) impératif."),
                  shiny::div(class = "small text-muted", shiny::tags$strong("Interprétation : "), "Garantit la précision des p-values et l'absence de matrice singulière.")
                )
              )
            )
          )
        ),

        # Model Parameters & Coefficient Estimates
        bslib::card(
          bslib::card_header(
            shiny::div(
              shiny::span("LEVEL 2", class = "level-badge"),
              "Model Parameters & Coefficient Estimates"
            )
          ),
          shiny::uiOutput("var_mapping_legend"),
          shiny::uiOutput("coef_table_ui"),
          shiny::tags$details(
            class = "mt-2 p-2 border rounded bg-light small",
            shiny::tags$summary(shiny::tags$strong("📄 Raw R Console Summary Output")),
            shiny::verbatimTextOutput("model_summary")
          )
        )
      )
    ),
    bslib::nav_panel(
      title = shiny::div("🔍 Diagnostics"),
      value = "tab_diagnostics",
      bslib::card(
        full_screen = TRUE,
        bslib::card_header(
          shiny::div(
            shiny::span("LEVEL 3", class = "level-badge"),
            shiny::uiOutput("diag_header_title", inline = TRUE)
          )
        ),
        shiny::plotOutput("diag_plots", height = "560px"),
        shiny::tags$details(
          class = "mt-2 p-3 border rounded bg-light shadow-sm",
          shiny::tags$summary(
            class = "fw-bold text-dark cursor-pointer",
            shiny::span("💡 Diagnostic Plots Guide & Interpretation", class = "fs-6")
          ),
          shiny::div(
            class = "mt-3 row g-3",
            shiny::div(
              class = "col-md-6",
              shiny::div(
                class = "p-3 border-start border-4 border-primary bg-white rounded shadow-sm h-100",
                shiny::div(
                  class = "d-flex align-items-center gap-2 mb-1",
                  shiny::span("📈", class = "badge bg-primary-subtle text-primary p-2 fs-6 rounded"),
                  shiny::tags$strong("Residuals vs Fitted", class = "text-dark")
                ),
                shiny::p(
                  "Checks linearity and homoscedasticity. Look for points randomly scattered around 0 with no funnel patterns or systematic curves.",
                  class = "small text-muted mb-0"
                )
              )
            ),
            shiny::div(
              class = "col-md-6",
              shiny::div(
                class = "p-3 border-start border-4 border-info bg-white rounded shadow-sm h-100",
                shiny::div(
                  class = "d-flex align-items-center gap-2 mb-1",
                  shiny::span("🎯", class = "badge bg-info-subtle text-info p-2 fs-6 rounded"),
                  shiny::tags$strong("Normal Q-Q", class = "text-dark")
                ),
                shiny::p(
                  "Checks residual normality. Points should fall closely along the 45° dashed diagonal line to satisfy regression assumptions.",
                  class = "small text-muted mb-0"
                )
              )
            ),
            shiny::div(
              class = "col-md-6",
              shiny::div(
                class = "p-3 border-start border-4 border-warning bg-white rounded shadow-sm h-100",
                shiny::div(
                  class = "d-flex align-items-center gap-2 mb-1",
                  shiny::span("📊", class = "badge bg-warning-subtle text-warning p-2 fs-6 rounded"),
                  shiny::tags$strong("Scale-Location", class = "text-dark")
                ),
                shiny::p(
                  "Checks homoscedasticity using root-standardized residuals. A flat horizontal trendline indicates equal error variance.",
                  class = "small text-muted mb-0"
                )
              )
            ),
            shiny::div(
              class = "col-md-6",
              shiny::div(
                class = "p-3 border-start border-4 border-danger bg-white rounded shadow-sm h-100",
                shiny::div(
                  class = "d-flex align-items-center gap-2 mb-1",
                  shiny::span("⚠️", class = "badge bg-danger-subtle text-danger p-2 fs-6 rounded"),
                  shiny::tags$strong("Residuals vs Leverage", class = "text-dark")
                ),
                shiny::p(
                  "Identifies influential outliers. Points outside Cook's distance contours exert disproportionate leverage on parameter estimates.",
                  class = "small text-muted mb-0"
                )
              )
            )
          )
        )
      )
    ),
    bslib::nav_panel(
      title = shiny::div("📑 Data & Audit Trail"),
      value = "Data",
      bslib::navset_card_tab(
        title = shiny::div(
          shiny::span("LEVEL 4", class = "level-badge"),
          "Raw Data & Audit Trail"
        ),
        bslib::nav_panel("Data Grid", DT::DTOutput("data_table")),
        bslib::nav_panel(
          "Simulation / Reproducible Code",
          shiny::div(
            class = "repro-code-card",
            shiny::div(
              class = "repro-code-header d-flex align-items-center justify-content-between",
              shiny::span("💻 Reproducible R Script & Audit Trail", class = "fw-bold fs-6")
            ),
            shiny::div(
              class = "repro-code-body",
              shiny::verbatimTextOutput("sim_code")
            )
          )
        )
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
        shiny::tags$dt("Response (Z)"),
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

  eli5_server("eli5_explainer", last_result)

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
  }, ignoreInit = FALSE)

  output$kpi_banner <- shiny::renderUI({
    result <- last_result()
    shiny::req(result)
    kpis <- extract_model_kpis(result$fit, result$model_type)

    shiny::div(
      class = "kpi-card-grid",
      shiny::div(
        class = "kpi-card",
        shiny::div(
          class = "kpi-card-header",
          shiny::span(class = "kpi-card-label", kpis$r2_label),
          shiny::span(class = paste("kpi-card-status", kpis$r2_badge_class), kpis$r2_status)
        ),
        shiny::div(class = "kpi-card-value", kpis$r2_value),
        shiny::div(class = "kpi-card-sub", kpis$r2_sub)
      ),
      shiny::div(
        class = "kpi-card",
        shiny::div(
          class = "kpi-card-header",
          shiny::span(class = "kpi-card-label", kpis$aic_label),
          shiny::span(class = paste("kpi-card-status", kpis$aic_badge_class), kpis$aic_status)
        ),
        shiny::div(class = "kpi-card-value", kpis$aic_value),
        shiny::div(class = "kpi-card-sub", kpis$aic_sub)
      ),
      shiny::div(
        class = "kpi-card",
        shiny::div(
          class = "kpi-card-header",
          shiny::span(class = "kpi-card-label", kpis$err_label),
          shiny::span(class = paste("kpi-card-status", kpis$err_badge_class), kpis$err_status)
        ),
        shiny::div(class = "kpi-card-value", kpis$err_value),
        shiny::div(class = "kpi-card-sub", kpis$err_sub)
      ),
      shiny::div(
        class = "kpi-card",
        shiny::div(
          class = "kpi-card-header",
          shiny::span(class = "kpi-card-label", kpis$health_label),
          shiny::span(class = paste("kpi-card-status", kpis$health_badge_class), kpis$health_status)
        ),
        shiny::div(class = "kpi-card-value", kpis$health_value),
        shiny::div(class = "kpi-card-sub", kpis$health_sub)
      )
    )
  })

  output$coef_table_ui <- shiny::renderUI({
    result <- last_result()
    shiny::req(result)
    df_coef <- extract_coefficient_table(result$fit)
    if (nrow(df_coef) == 0) return(NULL)

    formula_latex <- model_latex_formula(result$model_type, result$link)
    formula_box <- shiny::div(
      class = "model-formula-card mb-3 p-3 border rounded bg-light",
      shiny::div(
        class = "d-flex align-items-center justify-content-between mb-1",
        shiny::span(class = "fw-bold text-secondary small text-uppercase tracking-wide", "📐 Model Specification Formula"),
        shiny::span(class = "badge bg-secondary-subtle text-secondary font-mono small", sprintf("%s (%s link)", result$model_type, result$link))
      ),
      shiny::div(
        class = "formula-math-display text-center py-2 fs-5 font-mono",
        shiny::withMathJax(sprintf("$$\\displaystyle %s$$", formula_latex))
      )
    )

    rows <- lapply(seq_len(nrow(df_coef)), function(i) {
      sig_class <- if (!is.null(df_coef$PValueClass)) {
        df_coef$PValueClass[i]
      } else {
        p_str <- df_coef$PValue[i]
        if (grepl("***", p_str, fixed = TRUE)) "sig-high"
        else if (grepl("**", p_str, fixed = TRUE)) "sig-med"
        else if (grepl("*", p_str, fixed = TRUE)) "sig-low"
        else "sig-ns"
      }

      shiny::tags$tr(
        shiny::tags$td(shiny::tags$strong(df_coef$Term[i])),
        shiny::tags$td(df_coef$Estimate[i]),
        shiny::tags$td(df_coef$StdError[i]),
        shiny::tags$td(df_coef$Statistic[i]),
        shiny::tags$td(
          shiny::tags$span(class = paste("p-sig-badge", sig_class), df_coef$PValue[i])
        ),
        shiny::tags$td(
          shiny::tags$span(class = "coef-ci", df_coef$CI95[i])
        )
      )
    })

    shiny::tagList(
      formula_box,
      shiny::div(
        class = "coef-table-container",
        shiny::tags$table(
          class = "coef-table",
          shiny::tags$thead(
            shiny::tags$tr(
              shiny::tags$th("Parameter Term"),
              shiny::tags$th("Estimate (\u03b2)"),
              shiny::tags$th("Std Error"),
              shiny::tags$th("Statistic (t/z)"),
              shiny::tags$th("p-value"),
              shiny::tags$th("95% Conf. Interval")
            )
          ),
          shiny::tags$tbody(rows)
        )
      )
    )
  })

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
  output$var_mapping_legend <- shiny::renderUI({
    result <- last_result()
    shiny::req(result)
    if (!is.null(result$example)) {
      meta <- result$example$metadata
      config <- model_config(meta$model_type)
      items <- list(
        shiny::tags$span(shiny::tags$strong("Z (Response): "), meta$response_label),
        shiny::tags$span(shiny::tags$strong("X (Predictor): "), meta$predictor_x_label)
      )
      if (config$dimensions == 3L && nzchar(meta$predictor_y_label)) {
        items <- c(items, list(shiny::tags$span(shiny::tags$strong("Y (Predictor): "), meta$predictor_y_label)))
      }
      if (config$requires_group && nzchar(meta$group_source)) {
        items <- c(items, list(shiny::tags$span(shiny::tags$strong("Group: "), tools::toTitleCase(gsub("_", " ", meta$group_source, fixed = TRUE)))))
      }
      shiny::tags$div(
        class = "mb-2 p-2 border rounded bg-light small",
        shiny::tags$div(class = "fw-bold text-primary mb-1", "📌 Variable Mapping (Real Data)"),
        do.call(shiny::tags$div, c(class = "d-flex flex-wrap gap-3", items))
      )
    } else {
      config <- model_config(result$model_type)
      items <- list(
        shiny::tags$span(shiny::tags$strong("Z: "), "Response variable"),
        shiny::tags$span(shiny::tags$strong("X: "), "Primary predictor")
      )
      if (config$dimensions == 3L) {
        items <- c(items, list(shiny::tags$span(shiny::tags$strong("Y: "), "Secondary predictor")))
      }
      if (config$requires_group) {
        items <- c(items, list(shiny::tags$span(shiny::tags$strong("Group: "), "Random intercept factor")))
      }
      shiny::tags$div(
        class = "mb-2 p-2 border rounded bg-light small",
        shiny::tags$div(class = "fw-bold text-primary mb-1", "📌 Variable Mapping (Simulation)"),
        do.call(shiny::tags$div, c(class = "d-flex flex-wrap gap-3", items))
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
  output$diag_header_title <- shiny::renderUI({
    result <- last_result()
    is_glmm <- !is.null(result) && identical(result$model_type, "glmm")
    if (is_glmm) {
      "Diagnostics (2-Panel Suite for GLMM)"
    } else {
      "Diagnostics (4-Panel Suite)"
    }
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
    df <- display_result(result)
    num_cols <- names(df)[vapply(df, is.numeric, logical(1))]
    dt <- DT::datatable(
      df,
      class = "stripe hover compact cell-border",
      options = list(
        pageLength = 25,
        lengthMenu = c(10, 25, 50, 100),
        scrollX = TRUE,
        autoWidth = FALSE
      )
    )
    if (length(num_cols) > 0) {
      dt <- DT::formatRound(dt, columns = num_cols, digits = 4)
    }
    dt
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

  shiny::outputOptions(output, "main_plot", suspendWhenHidden = FALSE)
  shiny::outputOptions(output, "diag_plots", suspendWhenHidden = FALSE)
  shiny::outputOptions(output, "model_summary", suspendWhenHidden = FALSE)
  shiny::outputOptions(output, "data_table", suspendWhenHidden = FALSE)
}

shiny::shinyApp(ui, server)
