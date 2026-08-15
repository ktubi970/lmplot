model_brain_tolerance <- function(expected) {
  pmax(1e-10, 1e-8 * abs(expected))
}

model_brain_observation_ids <- function(df) {
  stopifnot(is.data.frame(df))
  id_columns <- names(df)[grepl(
    "(^id$|(^|[._[:space:]])id$)",
    names(df),
    ignore.case = TRUE
  )]

  for (column in id_columns) {
    values <- as.character(df[[column]])
    if (!anyNA(values) && all(nzchar(trimws(values))) && !anyDuplicated(values)) {
      return(values)
    }
  }

  as.character(seq_len(nrow(df)))
}

.model_brain_labels <- function(labels) {
  resolved <- list(x = "X", y = "Y", z = "Z", group = "Group")
  if (is.null(labels)) return(resolved)
  if (!is.list(labels) || is.null(names(labels))) {
    stop("Model Brain labels must be supplied as a named list", call. = FALSE)
  }

  supplied <- intersect(names(labels), names(resolved))
  for (name in supplied) {
    value <- labels[[name]]
    if (!is.character(value) || length(value) != 1L ||
        is.na(value) || !nzchar(value)) {
      stop(
        "Model Brain label '", name, "' must be one non-empty string",
        call. = FALSE
      )
    }
    resolved[[name]] <- value
  }
  resolved
}

.model_brain_fixed_parts <- function(fit, df, model_type) {
  if (inherits(fit, "merMod")) {
    matrix <- stats::model.matrix(fit)
    coefficients <- lme4::fixef(fit)
  } else if (inherits(fit, "lme")) {
    fixed_terms <- stats::delete.response(stats::terms(stats::formula(fit)))
    matrix <- stats::model.matrix(fixed_terms, data = df)
    coefficients <- nlme::fixef(fit)
  } else {
    matrix <- stats::model.matrix(fit)
    coefficients <- stats::coef(fit)
  }

  fallback <- identical(model_type, "glmm") &&
    !inherits(fit, "merMod") && !inherits(fit, "lme")
  if (fallback) {
    assignment <- attr(matrix, "assign")
    term_labels <- attr(stats::terms(fit), "term.labels")
    assigned_terms <- rep("(Intercept)", length(assignment))
    non_intercept <- assignment > 0L
    assigned_terms[non_intercept] <- term_labels[assignment[non_intercept]]
    keep <- assigned_terms != "Group"
    matrix <- matrix[, keep, drop = FALSE]
  }

  common <- intersect(colnames(matrix), names(coefficients))
  matrix <- matrix[, common, drop = FALSE]
  coefficients <- coefficients[common]

  list(
    matrix = unclass(matrix),
    coefficients = coefficients,
    eta = as.numeric(matrix %*% coefficients),
    fallback = fallback
  )
}

.model_brain_group_values <- function(fit, df) {
  if (!"Group" %in% names(df)) return(rep(NA_character_, nrow(df)))
  as.character(df$Group)
}

.model_brain_random_intercepts <- function(fit, df) {
  groups <- .model_brain_group_values(fit, df)
  if (inherits(fit, "merMod")) {
    fitted_effects <- lme4::ranef(fit)[[1L]]
  } else if (inherits(fit, "lme")) {
    fitted_effects <- nlme::ranef(fit)
  } else {
    return(NULL)
  }

  if (!"(Intercept)" %in% colnames(fitted_effects)) return(NULL)
  intercepts <- fitted_effects[, "(Intercept)"]
  names(intercepts) <- rownames(fitted_effects)
  values <- unname(intercepts[groups])
  if (length(values) != nrow(df) || anyNA(values)) return(NULL)
  values
}

.model_brain_contributions <- function(input_matrix, coefficients, row) {
  lapply(seq_along(coefficients), function(column) {
    input <- unname(input_matrix[row, column])
    coefficient <- unname(coefficients[[column]])
    list(
      term = names(coefficients)[[column]],
      input = input,
      coefficient = coefficient,
      value = input * coefficient
    )
  })
}

.model_brain_observations <- function(
    ids, df, fixed, mode, prediction, eta, random_values,
    random_available, decomposition_complete, residual) {
  groups <- .model_brain_group_values(NULL, df)
  lapply(seq_len(nrow(df)), function(row) {
    contributions <- .model_brain_contributions(
      fixed$matrix, fixed$coefficients, row
    )
    input_records <- contributions[vapply(
      contributions,
      function(contribution) contribution$term != "(Intercept)",
      logical(1)
    )]
    inputs <- setNames(
      lapply(input_records, `[[`, "input"),
      vapply(input_records, `[[`, character(1), "term")
    )
    random_active <- identical(mode, "conditional") && random_available
    random_value <- if (random_available) {
      if (random_active) random_values[[row]] else 0
    } else if (identical(mode, "population")) {
      0
    } else {
      NA_real_
    }

    list(
      observation_id = ids[[row]],
      prediction_mode = mode,
      inputs = inputs,
      contributions = contributions,
      random_effect = list(
        group = groups[[row]],
        value = unname(random_value),
        available = random_available,
        active = random_active
      ),
      eta = unname(eta[[row]]),
      prediction = unname(prediction[[row]]),
      observed = unname(df$Z[[row]]),
      residual = unname(residual[[row]]),
      eta_valid = is.finite(eta[[row]]),
      prediction_valid = is.finite(prediction[[row]]),
      residual_valid = is.finite(residual[[row]]),
      decomposition_complete = decomposition_complete
    )
  })
}

build_model_brain <- function(fit, df, model_type, link, labels = NULL) {
  stopifnot(is.data.frame(df))
  config <- model_config(model_type)
  link <- validate_model_link(model_type, link)
  if (nrow(df) != stats::nobs(fit)) {
    stop("Model Brain data must match the fitted observation count", call. = FALSE)
  }

  fixed <- .model_brain_fixed_parts(fit, df, model_type)
  ids <- model_brain_observation_ids(df)
  is_glmm <- identical(model_type, "glmm")
  random_values <- if (is_glmm && !fixed$fallback) {
    .model_brain_random_intercepts(fit, df)
  } else {
    NULL
  }
  random_available <- is_glmm && !is.null(random_values)
  decomposition_complete <- !fixed$fallback && (!is_glmm || random_available)
  modes <- if (is_glmm && random_available) {
    c("conditional", "population")
  } else {
    "conditional"
  }

  warnings <- list()
  if (fixed$fallback) {
    warnings <- list(list(
      code = "glmm_random_effect_unavailable",
      scope = "model",
      message = paste(
        "The stats::lm GLMM fallback has no exact random-intercept branch;",
        "only conditional predictions are available and the decomposition is incomplete."
      )
    ))
  }

  observations <- unlist(lapply(modes, function(mode) {
    population <- identical(mode, "population")
    prediction <- as.numeric(predict_response(
      fit, newdata = df, population = population
    ))
    eta <- if (fixed$fallback) {
      prediction
    } else {
      fixed$eta + if (population || !random_available) 0 else random_values
    }
    residual <- as.numeric(df$Z - prediction)

    .model_brain_observations(
      ids = ids,
      df = df,
      fixed = fixed,
      mode = mode,
      prediction = prediction,
      eta = eta,
      random_values = random_values,
      random_available = random_available,
      decomposition_complete = decomposition_complete,
      residual = residual
    )
  }), recursive = FALSE)

  list(
    schema_version = "model-brain/1.0",
    model_type = model_type,
    family = config$family,
    link = link,
    formula = paste(deparse(stats::formula(fit)), collapse = " "),
    prediction_modes = modes,
    labels = .model_brain_labels(labels),
    random_effect_available = random_available,
    decomposition_complete = decomposition_complete,
    observations = observations,
    warnings = warnings
  )
}
