# Module ELI5 (Explain Like I'm 5) - Assistant d'Explication en Langage Naturel

generate_eli5_explanation <- function(fit, model_type, link = "identity",
                                      data_source = "simulation", example_metadata = NULL) {
  config <- model_config(model_type)
  kpis <- extract_model_kpis(fit, model_type)
  coef_df <- extract_coefficient_table(fit)
  
  resp_name <- if (!is.null(example_metadata)) example_metadata$response_label else "Z (Variable Réponse)"
  pred_x_name <- if (!is.null(example_metadata)) example_metadata$predictor_x_label else "X (Prédicteur Principal)"
  pred_y_name <- if (!is.null(example_metadata) && nzchar(example_metadata$predictor_y_label)) example_metadata$predictor_y_label else "Y (Second Prédicteur)"
  group_name <- if (!is.null(example_metadata) && nzchar(example_metadata$group_source)) example_metadata$group_source else "Group (Groupe)"

  # 1. Concept Simplifié (ELI5 Concept)
  concept <- switch(
    model_type,
    "lm_2d" = sprintf("Imaginez que vous voulez deviner **%s** en traçant une droite à partir de **%s**. C'est le modèle régression linéaire le plus simple !", resp_name, pred_x_name),
    "lm_3d" = sprintf("On essaie de prédire **%s** en combinant deux informations à la fois : **%s** et **%s**.", resp_name, pred_x_name, pred_y_name),
    "glm_binomial_2d" = sprintf("Ici, on cherche à prédire un événement (Oui/Non, 0 ou 1) pour **%s** en fonction de **%s** avec une courbe en 'S' (%s).", resp_name, pred_x_name, link),
    "glm_binomial" = sprintf("C'est une météo du risque : quelle est la probabilité que **%s** se produise (0 ou 1) selon **%s** et **%s** ?", resp_name, pred_x_name, pred_y_name),
    "glm_poisson" = sprintf("On compte des événements (ex. nombre de réussites, comptages) pour **%s** à l'aide de **%s** et **%s** (lien %s).", resp_name, pred_x_name, pred_y_name, link),
    "glm_gamma" = sprintf("On mesure des durées ou des montants toujours positifs pour **%s** en observant **%s** et **%s** (lien %s).", resp_name, pred_x_name, pred_y_name, link),
    "glmm" = sprintf("On tient compte des différences entre groupes (%s) tout en mesurant l'effet global de **%s** et **%s**.", group_name, pred_x_name, pred_y_name),
    sprintf("Modèle statistique ajusté pour prédire %s à partir de vos variables.", resp_name)
  )

  # 2. Explication des Coefficients (Effets observés)
  effect_bullets <- list()
  if (nrow(coef_df) > 0) {
    for (i in seq_len(nrow(coef_df))) {
      term <- coef_df$Term[i]
      est_val <- suppressWarnings(as.numeric(coef_df$Estimate[i]))
      p_str <- coef_df$PValue[i]
      
      if (term == "(Intercept)") {
        msg <- sprintf("📍 **Point de départ (Ordonnée à l'origine) :** Quand toutes les variables valent zéro, la valeur de départ estimée est de **%s**.", coef_df$Estimate[i])
      } else {
        direction <- if (!is.na(est_val) && est_val > 0) "augmente" else "diminue"
        change_amount <- if (!is.na(est_val)) sprintf("%.4f", abs(est_val)) else coef_df$Estimate[i]
        
        var_label <- if (term == "X") pred_x_name else if (term == "Y") pred_y_name else term
        
        sig_explanation <- if (grepl("***", p_str, fixed = TRUE)) {
          "très solide (presque 0% de chance d'être du hasard)"
        } else if (grepl("**", p_str, fixed = TRUE)) {
          "solide (moins de 1% de chance de hasard)"
        } else if (grepl("*", p_str, fixed = TRUE)) {
          "significatif (moins de 5% de hasard)"
        } else {
          "non incertaine ou potentiellement due au hasard"
        }
        
        msg <- sprintf("📈 **Effet de %s :** Chaque fois que **%s** augmente de 1 unité, **%s** %s en moyenne de **%s** unités. Cette relation est %s (p = %s).", var_label, var_label, resp_name, direction, change_amount, sig_explanation, p_str)
      }
      effect_bullets[[length(effect_bullets) + 1L]] <- msg
    }
  }

  # 3. Qualité Globale (R² et Erreur)
  r2_val <- kpis$r2_value
  r2_eval <- switch(
    kpis$r2_status,
    "EXCELLENT FIT" = "⭐ **Excellente précision !** Le modèle explique une très grande partie de la réalité.",
    "GOOD FIT" = "✅ **Bonne précision.** Le modèle capture bien la tendance principale.",
    "MODERATE FIT" = "🟡 **Précision modérée.** La tendance existe, mais d'autres facteurs non mesurés jouent un rôle.",
    "LOW FIT" = "ℹ️ **Faible pouvoir explicatif.** Le modèle voit une tendance, mais 80%+ de la variation reste inexpliquée par ces variables seules.",
    "Le modèle est ajusté."
  )

  # 4. Bilan / Conclusion Pratique (ELI5 Synthesis)
  conclusion <- sprintf(
    "En résumé : votre modèle a réussi à calculer l'effet de vos variables avec un échantillon de %s observations. %s",
    kpis$health_value,
    r2_eval
  )

  list(
    concept = concept,
    effects = effect_bullets,
    r2_eval = r2_eval,
    r2_val = r2_val,
    conclusion = conclusion
  )
}

eli5_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::div(
    class = "eli5-card-container mb-3",
    shiny::div(
      class = "card border-0 shadow-sm rounded-3 overflow-hidden",
      shiny::div(
        class = "card-header bg-gradient-slate text-white d-flex align-items-center justify-content-between p-3",
        shiny::div(
          class = "d-flex align-items-center gap-2",
          shiny::span("🤖", class = "fs-4"),
          shiny::div(
            shiny::div("Assistant IA ELI5 (Explain Like I'm 5)", class = "fw-bold fs-6"),
            shiny::div("Explications statistiques en langage naturel simple", class = "small opacity-75")
          )
        ),
        shiny::actionButton(
          ns("explain_btn"),
          "🤖 Expliquer en français simple",
          class = "btn btn-sm btn-light text-primary fw-bold shadow-sm"
        )
      ),
      shiny::uiOutput(ns("eli5_content"))
    )
  )
}

eli5_server <- function(id, last_result) {
  shiny::moduleServer(id, function(input, output, session) {
    show_explanation <- shiny::reactiveVal(FALSE)

    shiny::observeEvent(input$explain_btn, {
      show_explanation(TRUE)
    })

    # Réinitialise la vue automatique si le modèle change
    shiny::observeEvent(last_result(), {
      show_explanation(FALSE)
    })

    output$eli5_content <- shiny::renderUI({
      result <- last_result()
      shiny::req(result)

      if (!show_explanation()) {
        return(shiny::div(
          class = "p-3 text-center bg-light text-muted small",
          "Cliquez sur le bouton ci-dessus pour générer une explication pédagogique en français simple du modèle sélectionné."
        ))
      }

      meta <- if (!is.null(result$example)) result$example$metadata else NULL
      eli5 <- generate_eli5_explanation(
        result$fit,
        result$model_type,
        result$link,
        data_source = if (!is.null(result$example)) "real" else "simulation",
        example_metadata = meta
      )

      effect_items <- lapply(eli5$effects, function(eff) {
        shiny::tags$li(class = "mb-2", shiny::HTML(eff))
      })

      shiny::div(
        class = "card-body bg-white p-4",
        shiny::div(
          class = "alert alert-primary border-0 bg-primary-subtle text-primary-emphasis rounded-3 mb-3 p-3",
          shiny::div(class = "fw-bold mb-1", "💡 Concept Clé (ELI5) :"),
          shiny::div(shiny::HTML(eli5$concept))
        ),
        shiny::div(
          class = "mb-3",
          shiny::div(class = "fw-bold text-dark mb-2", "🔍 Que signifient vos chiffres en pratique ?"),
          shiny::tags$ul(class = "ps-3 mb-0 text-secondary small", effect_items)
        ),
        shiny::div(
          class = "p-3 border rounded bg-light mb-3",
          shiny::div(class = "fw-bold text-dark mb-1", "📊 Évaluation de la Précision :"),
          shiny::div(class = "small text-secondary", shiny::HTML(eli5$r2_eval))
        ),
        shiny::div(
          class = "d-flex align-items-center justify-content-between p-2 bg-success-subtle text-success-emphasis rounded border border-success-subtle small",
          shiny::span(class = "fw-bold", "📌 Conclusion :"),
          shiny::span(eli5$conclusion)
        )
      )
    })
  })
}
