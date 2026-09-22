# Deterministic, model-aware interpretation; all text is rendered as escaped content.
COEFFICIENT_EXPLANATIONS <- list(
  identity = function(beta) sprintf("an additive change of %.4g response units in the conditional mean", beta),
  log = function(beta) sprintf("a multiplicative factor exp(beta) = %.4g for the conditional mean (%.4g%% change)", exp(beta), 100 * expm1(beta)),
  logit = function(beta) sprintf("a conditional odds ratio exp(beta) = %.4g; the probability change depends on baseline probability", exp(beta)),
  probit = function(beta) sprintf("a change of %.4g on the probit link scale; response probability changes depend on the starting covariates", beta),
  cloglog = function(beta) sprintf("a change of %.4g on the cloglog link scale; response probability changes depend on the starting covariates", beta),
  inverse = function(beta) sprintf("a change of %.4g on the inverse link scale (1 / conditional mean); response changes depend on the starting covariates", beta),
  sqrt = function(beta) sprintf("a change of %.4g on the sqrt link scale (square root of the conditional mean); response changes depend on the starting covariates", beta)
)

explain_coefficient <- function(estimate, p_value = NA_real_, link = "identity", term = "X", mixed = FALSE) {
  explain <- COEFFICIENT_EXPLANATIONS[[link]]
  if (is.null(explain)) stop("Unsupported interpretation link: ", link, call. = FALSE)
  if (!is.finite(estimate)) return(paste(term, "is not estimable from this fitted design."))
  effect <- if (term == "(Intercept)") {
    sprintf("Intercept: %.4g on the %s link scale when included predictors are zero and factors are at their reference levels; this baseline may be outside the observed data.", estimate, link)
  } else {
    sprintf("%s: a one-unit increase is associated with %s, holding other included covariates fixed.", term, explain(estimate))
  }
  if (mixed) effect <- paste(effect, "This fixed-effect comparison is at a common random-effect value.")
  inference <- if (is.finite(p_value)) {
    sprintf("Under the fitted model and its assumptions, p = %.4g summarizes compatibility of the observed statistic with a zero coefficient.", p_value)
  } else "A p-value is unavailable for this coefficient."
  paste(effect, inference)
}

guided_interpretation <- function(result) {
  coefficients <- result$coefficients %||% extract_coefficient_table(result$fit, result$model_type, result$link)
  diagnostics <- result$diagnostics %||% result$linearity_diag %||% diagnose_model(result$fit, result$data, result$model_type)
  metrics <- result$metrics %||% extract_model_metrics(result$fit, result$model_type, result$data)
  effects <- lapply(seq_len(nrow(coefficients)), function(i) {
    explain_coefficient(coefficients$estimate[i], coefficients$p_value[i], result$link,
      coefficients$term[i], mixed = result$model_type == "glmm")
  })
  list(concept = sprintf("%s uses a %s link to relate included predictors to the conditional mean response.",
      model_config(result$model_type)$label, result$link),
    effects = effects, diagnostics = diagnostics, metrics = metrics,
    comparison = COMPARISON_CRITERIA_DESCRIPTION,
    caution = paste("These estimates describe association under the model, not causation.",
      "In-sample metrics do not establish performance for future observations or new groups.",
      "Confidence intervals for mean responses do not describe the spread of future observations."))
}

guided_interpretation_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::div(class = "card mb-3",
    shiny::div(class = "card-header", shiny::h3("Guided interpretation", class = "h6"),
      shiny::p("Deterministic explanations of estimates, uncertainty and diagnostic limitations."),
      shiny::actionButton(ns("explain_btn"), "Show interpretation", class = "btn btn-sm btn-secondary")),
    shiny::uiOutput(ns("content")))
}

guided_interpretation_server <- function(id, last_result) {
  shiny::moduleServer(id, function(input, output, session) {
    show <- shiny::reactiveVal(FALSE)
    shiny::observeEvent(last_result(), show(FALSE))
    shiny::observeEvent(input$explain_btn, show(TRUE))
    output$content <- shiny::renderUI({
      result <- last_result()
      shiny::req(result)
      if (!show()) return(shiny::p(class = "p-3", "Select Show interpretation to inspect this model."))
      explanation <- guided_interpretation(result)
      shiny::div(class = "card-body",
        shiny::p(explanation$concept),
        shiny::tags$ul(lapply(explanation$effects, shiny::tags$li)),
        shiny::p(explanation$diagnostics$summary),
        shiny::tags$ul(lapply(explanation$diagnostics$warnings, shiny::tags$li)),
        shiny::p(explanation$comparison), shiny::p(explanation$caution))
    })
  })
}
