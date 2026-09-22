# Canonical precomputed scientific contract: no rendering or reactive state.
model_brain_tolerance <- function(expected) pmax(1e-10, 1e-8 * abs(expected))
.brain_abort <- function(defect) stop(paste0('Model Brain: ', defect, '.'), call. = FALSE)
.brain_assert <- function(ok, defect) if (!isTRUE(ok)) .brain_abort(defect)
.brain_string <- function(x) is.character(x) && is.null(attributes(x)) &&
  length(x) == 1L && !is.na(x) && nzchar(trimws(x))
.brain_number <- function(x) is.numeric(x) && is.null(attributes(x)) && length(x) == 1L && is.finite(x)
.brain_array <- function(x) is.list(x) && is.null(attributes(x))
.brain_equal <- function(x, y) length(x) == length(y) && all(is.finite(x)) &&
  all(is.finite(y)) && all(abs(x-y) <= model_brain_tolerance(y))
.brain_object <- function(x, keys) {
  .brain_assert(is.list(x) && !is.data.frame(x) && !is.pairlist(x) &&
    identical(names(x), keys), 'invalid object fields or field order')
}

model_brain_observation_ids <- function(df) {
  stopifnot(is.data.frame(df))
  columns <- names(df)[grepl('(^id$|(^|[._[:space:]])id$)', names(df), ignore.case = TRUE)]
  for (column in columns) {
    values <- as.character(df[[column]])
    if (!anyNA(values) && all(nzchar(trimws(values))) && !anyDuplicated(values)) return(values)
  }
  as.character(seq_len(nrow(df)))
}

.brain_labels <- function(labels) {
  resolved <- list(x = 'X', y = 'Y', z = 'Z', group = 'Group')
  if (is.null(labels)) return(resolved)
  .brain_assert(is.list(labels) && !is.data.frame(labels) && !is.null(names(labels)) &&
    !anyDuplicated(names(labels)) && all(names(labels) %in% names(resolved)), 'invalid label fields')
  # The real-example manifest represents unused labels as empty strings.
  if (is.list(labels)) labels <- labels[!vapply(labels, function(x)
    is.null(x) || (is.character(x) && length(x) == 1L && (is.na(x) || !nzchar(trimws(x)))), logical(1))]
  .brain_assert(is.list(labels) && !is.data.frame(labels) && !is.null(names(labels)) &&
    !anyDuplicated(names(labels)) && all(names(labels) %in% names(resolved)) &&
    all(vapply(labels, .brain_string, logical(1))), 'invalid labels')
  resolved[names(labels)] <- labels
  resolved
}

.brain_interval <- function(available, lower = NULL, upper = NULL, reason = NULL,
                            method = NULL, level = .95) {
  list(available = available, level = level, lower = if (available) lower else NULL,
    upper = if (available) upper else NULL, reason = if (available) NULL else reason,
    method = method)
}

.brain_summary <- function(values) {
  .brain_assert(is.numeric(values) && length(values) > 0 && all(is.finite(values)), 'invalid summary values')
  q <- unname(stats::quantile(values, c(0, .25, .5, .75, 1)))
  sample <- unname(values[unique(round(seq(1, length(values), length.out = min(1000, length(values)))))])
  list(min = q[1], q1 = q[2], median = q[3], q3 = q[4], max = q[5], missing_n = 0L, sample = sample)
}

.brain_topology <- function(terms, estimates, mixed, labels) {
  ids <- c('bias', paste0('fixed_', seq_len(length(terms)-1)))
  roles <- c('bias', rep('fixed_term', length(terms)-1))
  text <- c('Intercept', labels$x, if (length(terms) == 3) labels$y)
  nodes <- lapply(seq_along(terms), function(i) list(id = ids[i], role = roles[i],
    label = text[i], column = 1L, row = as.integer(i)))
  edges <- lapply(seq_along(terms), function(i) list(source = ids[i], target = 'eta',
    term = terms[i], coefficient = unname(estimates[i]), order = as.integer(i)))
  if (mixed) {
    nodes <- c(nodes, list(list(id = 'random_intercept', role = 'random_intercept',
      label = labels$group, column = 1L, row = as.integer(length(terms)+1))))
    edges <- c(edges, list(list(source = 'random_intercept', target = 'eta',
      term = 'Group', coefficient = 1, order = as.integer(length(edges)+1))))
  }
  for (i in 1:3) {
    id <- c('eta','inverse_link','prediction')[i]
    nodes <- c(nodes, list(list(id = id, role = id,
      label = c('Linear predictor', 'Inverse link', 'Prediction')[i], column = as.integer(i+1), row = 1L)))
  }
  edges <- c(edges, list(list(source = 'eta', target = 'inverse_link', term = NULL,
    coefficient = NULL, order = as.integer(length(edges)+1)),
    list(source = 'inverse_link', target = 'prediction', term = NULL,
      coefficient = NULL, order = as.integer(length(edges)+2))))
  list(nodes = nodes, edges = edges)
}

.brain_warnings <- function(warnings) {
  .brain_assert(is.character(warnings) && !anyNA(warnings) && all(nzchar(trimws(warnings))), 'invalid warnings')
  lapply(unique(warnings), function(message) list(code = 'analysis_warning', scope = 'analysis', message = message))
}

.brain_link_grid <- function(eta, link) {
  limits <- range(eta)
  padding <- max(diff(limits)*.05, max(abs(limits))*.01, 1e-6)
  limits <- limits + c(-padding, padding)
  if (link %in% c('inverse', 'sqrt')) limits[1] <- max(limits[1], min(eta)/2, .Machine$double.eps)
  seq(limits[1], limits[2], length.out = 201L)
}

build_model_brain <- function(fit, data, model_type, link, labels = NULL,
                              warnings = character(), prediction_mode = NULL) {
  config <- model_config(model_type)
  link <- validate_model_link(model_type, link)
  mixed <- identical(model_type, 'glmm')
  .brain_assert(if (mixed) inherits(fit, 'merMod') else
    if (config$fit_strategy == 'glm') inherits(fit, 'glm') else
      inherits(fit, 'lm') && !inherits(fit, 'glm'), 'fitted class mismatch; GLMM requires merMod')
  validate_model_data(data, model_type)
  .brain_assert(nrow(data) > 0 && nrow(data) == stats::nobs(fit), 'data must match fitted observation count')
  .brain_assert(.brain_equal(data$Z, as.numeric(stats::model.response(stats::model.frame(fit)))),
    'source responses do not match fitted rows')
  if (mixed) .brain_assert(identical(as.character(data$Group),
    as.character(stats::model.frame(fit)$Group)), 'source groups do not match fitted rows')
  modes <- if (mixed) c('conditional', 'population') else 'conditional'
  .brain_assert(is.null(prediction_mode) || (.brain_string(prediction_mode) && prediction_mode %in% modes), 'unsupported prediction mode')
  labels <- .brain_labels(labels)
  matrix <- stats::model.matrix(fit)
  table <- extract_coefficient_table(fit, model_type, link)
  terms <- table$term
  .brain_assert(identical(colnames(matrix), terms) && all(is.finite(matrix)) &&
    all(is.finite(table$estimate)) && all(is.finite(table$standard_error)), 'invalid fixed coefficients or inputs')
  .brain_assert(.brain_equal(unname(matrix[, -1, drop = FALSE]),
    unname(as.matrix(data[, terms[-1], drop = FALSE]))), 'source rows do not match fitted inputs')
  inverse <- if (inherits(fit, 'glm')) stats::family(fit)$linkinv else identity
  if (inherits(fit, 'glm')) .brain_assert(identical(stats::family(fit)$family, config$family) &&
    identical(stats::family(fit)$link, link), 'fitted family or link mismatch')
  coefficients <- lapply(seq_len(nrow(table)), function(i) list(term = terms[i],
    estimate = table$estimate[i], standard_error = table$standard_error[i],
    interval = .brain_interval(table$interval_available[i], table$conf_low[i], table$conf_high[i],
      reason = 'Coefficient interval is unavailable for this model.',
      method = if (table$interval_available[i]) table$interval_method[i] else NULL)))
  response <- predict_response_interval(fit, data, model_type, level = .95)
  intervals <- lapply(seq_len(nrow(data)), function(i) {
    available <- isTRUE(response$available) && isTRUE(response$interval_available[i])
    .brain_interval(available, response$lower[i], response$upper[i],
      reason = response$reason %||% 'Response interval is unavailable for this observation.',
      method = if (available) response$method else NULL, level = response$level)
  })
  groups <- if (mixed) as.character(data$Group) else rep(NA_character_, nrow(data))
  random <- rep(0, nrow(data))
  if (mixed) {
    effects <- lme4::ranef(fit)[[1L]]
    random <- unname(effects[groups, '(Intercept)'])
    .brain_assert(length(random) == nrow(data) && all(is.finite(random)), 'missing group intercept')
  }
  ids <- model_brain_observation_ids(data)
  fixed_eta <- as.numeric(matrix %*% table$estimate)
  values <- sweep(matrix, 2, table$estimate, '*')
  contributions <- lapply(seq_len(nrow(data)), function(i) lapply(seq_along(terms), function(j) {
    list(term = terms[j], input = unname(matrix[i,j]), coefficient = table$estimate[j],
      value = unname(values[i,j]), order = as.integer(j))
  }))
  observations <- unlist(lapply(modes, function(mode) {
    active <- mixed && mode == 'conditional'
    u <- if (active) random else rep(0, nrow(data))
    eta <- fixed_eta + u
    prediction <- as.numeric(predict_response(fit, data, population = mode == 'population'))
    .brain_assert(.brain_equal(prediction, as.numeric(inverse(eta))), 'prediction disagrees with decomposition')
    lapply(seq_len(nrow(data)), function(i) list(observation_id = ids[i], index = as.integer(i),
      prediction_mode = mode, inputs = as.list(setNames(unname(matrix[i,-1]), terms[-1])),
      contributions = contributions[[i]], random_effect = list(group = if (mixed) groups[i] else NULL,
        value = u[i], available = mixed, active = active), eta = eta[i], prediction = prediction[i],
      observed = data$Z[i], residual = data$Z[i]-prediction[i], response_interval = intervals[[i]]))
  }), recursive = FALSE)
  conditional <- observations[seq_len(nrow(data))]
  prediction <- vapply(conditional, `[[`, numeric(1), 'prediction')
  eta <- vapply(observations, `[[`, numeric(1), 'eta')
  grid <- .brain_link_grid(eta, link)
  curve <- as.numeric(inverse(grid))
  .brain_assert(all(is.finite(curve)), 'non-finite link curve')
  list(schema_version = 'model-brain/1.0', model_type = model_type, family = config$family,
    link = link, formula = paste(deparse(stats::formula(fit)), collapse = ' '), labels = labels,
    units = list(x = NULL, y = NULL, z = NULL, eta = if (link == 'identity') 'response units' else 'link scale'),
    n = nrow(data), prediction_modes = modes,
    default_observation_id = ids[order(prediction, ids, method = 'radix')[ceiling(length(ids)/2)]],
    topology = .brain_topology(terms, table$estimate, mixed, labels), coefficients = coefficients,
    observations = observations, link_curve = list(eta = grid, prediction = curve, valid = rep(TRUE, length(grid))),
    global_summaries = list(coefficients = .brain_summary(table$estimate),
      contributions = .brain_summary(as.numeric(t(values))),
      random_effects = if (mixed) .brain_summary(unname(effects[
        order(rownames(effects), method = 'radix'), '(Intercept)'])) else NULL),
    warnings = .brain_warnings(warnings))
}

select_model_brain_observation <- function(brain, index, mode = 'conditional') {
  .brain_assert(.brain_number(index) && index == floor(index) && index >= 1 && index <= brain$n,
    'observation index is invalid')
  .brain_assert(.brain_string(mode) && mode %in% brain$prediction_modes, 'unsupported prediction mode')
  brain$observations[[(match(mode, brain$prediction_modes)-1L)*brain$n + as.integer(index)]]
}

.brain_validate_interval <- function(interval) {
  .brain_object(interval, c('available','level','lower','upper','reason','method'))
  .brain_assert(is.logical(interval$available) && is.null(attributes(interval$available)) && length(interval$available) == 1 &&
    !is.na(interval$available) && .brain_number(interval$level) && interval$level > 0 && interval$level < 1,
    'invalid interval status or level')
  if (interval$available) {
    .brain_assert(.brain_number(interval$lower) && .brain_number(interval$upper) &&
      interval$lower <= interval$upper && is.null(interval$reason) && .brain_string(interval$method), 'invalid interval bounds or method')
  } else .brain_assert(is.null(interval$lower) && is.null(interval$upper) &&
    .brain_string(interval$reason) && (is.null(interval$method) || .brain_string(interval$method)), 'invalid unavailable interval')
}

.brain_validate_summary <- function(summary, expected) {
  .brain_object(summary, c('min','q1','median','q3','max','missing_n','sample'))
  .brain_assert(all(vapply(summary[1:6], .brain_number, logical(1))) &&
    is.numeric(summary$sample) && length(summary$sample) <= 1000 && all(is.finite(summary$sample)), 'invalid summary numbers')
  .brain_assert(isTRUE(all.equal(summary, .brain_summary(expected), tolerance = 1e-10)), 'inconsistent global summary')
}

validate_model_brain <- function(brain) {
  .brain_object(brain, c('schema_version','model_type','family','link','formula','labels','units','n',
    'prediction_modes','default_observation_id','topology','coefficients','observations','link_curve','global_summaries','warnings'))
  for (key in c('schema_version','model_type','family','link','formula','default_observation_id')) {
    .brain_assert(.brain_string(brain[[key]]), paste('invalid', key))
  }
  .brain_assert(brain$schema_version == 'model-brain/1.0' && brain$model_type %in% model_ids(), 'schema or model mismatch')
  config <- model_config(brain$model_type)
  mixed <- brain$model_type == 'glmm'
  .brain_assert(brain$family == config$family && brain$link %in% config$links, 'family or link mismatch')
  n <- brain$n
  .brain_assert(.brain_number(n) && n >= 1 && n == floor(n), 'invalid observation count')
  modes <- if (mixed) c('conditional','population') else 'conditional'
  .brain_assert(identical(brain$prediction_modes, modes), 'incomplete prediction modes')
  .brain_object(brain$labels, c('x','y','z','group'))
  .brain_assert(all(vapply(brain$labels, .brain_string, logical(1))), 'invalid labels')
  .brain_object(brain$units, c('x','y','z','eta'))
  .brain_assert(all(vapply(brain$units, function(x) is.null(x) || .brain_string(x), logical(1))) &&
    .brain_string(brain$units$eta), 'invalid units')
  terms <- c('(Intercept)','X', if (config$dimensions == 3) 'Y')
  expected_formula <- if (mixed) 'Z ~ X + Y + (1 | Group)' else
    if (config$dimensions == 3) 'Z ~ X + Y' else 'Z ~ X'
  .brain_assert(identical(brain$formula, expected_formula), 'formula does not match fixed terms')
  .brain_assert(.brain_array(brain$coefficients) && length(brain$coefficients) == length(terms), 'invalid coefficient collection')
  for (j in seq_along(terms)) {
    c <- brain$coefficients[[j]]
    .brain_object(c, c('term','estimate','standard_error','interval'))
    .brain_assert(identical(c$term, terms[j]) && .brain_number(c$estimate) &&
      .brain_number(c$standard_error) && c$standard_error >= 0, 'invalid coefficient')
    .brain_validate_interval(c$interval)
  }
  estimates <- vapply(brain$coefficients, `[[`, numeric(1), 'estimate')
  .brain_object(brain$topology, c('nodes','edges'))
  # Canonical topology rejects cycles, orphan edges, duplicate IDs and role/order mutations.
  .brain_assert(identical(brain$topology, .brain_topology(terms, estimates, mixed, brain$labels)), 'invalid contribution topology')
  .brain_assert(.brain_array(brain$observations) && length(brain$observations) == n*length(modes), 'incomplete observations')
  inverse <- stats::make.link(brain$link)$linkinv
  ids <- character(n); predictions <- numeric(n)
  contribution_values <- numeric(n*length(terms)); random <- numeric(n); groups <- character(n)
  for (k in seq_along(brain$observations)) {
    o <- brain$observations[[k]]
    i <- (k-1L) %% n + 1L; mode <- modes[(k-1L) %/% n + 1L]
    .brain_object(o, c('observation_id','index','prediction_mode','inputs','contributions','random_effect',
      'eta','prediction','observed','residual','response_interval'))
    .brain_assert(.brain_string(o$observation_id) && .brain_number(o$index) && o$index == i &&
      identical(o$prediction_mode, mode), 'invalid observation identity, index or mode order')
    .brain_object(o$inputs, terms[-1])
    .brain_assert(all(vapply(o$inputs, .brain_number, logical(1))), 'invalid input numbers')
    .brain_assert(.brain_array(o$contributions) && length(o$contributions) == length(terms), 'invalid contributions')
    values <- numeric(length(terms))
    for (j in seq_along(terms)) {
      c <- o$contributions[[j]]
      .brain_object(c, c('term','input','coefficient','value','order'))
      .brain_assert(identical(c$term, terms[j]) && .brain_number(c$order) && c$order == j &&
        all(vapply(c[c('input','coefficient','value')], .brain_number, logical(1))), 'invalid contribution order or numbers')
      .brain_assert(.brain_equal(c$coefficient, estimates[j]) &&
        .brain_equal(c$input, if (j == 1L) 1 else o$inputs[[j-1L]]) &&
        .brain_equal(c$value, c$input*c$coefficient), 'inconsistent contribution')
      values[j] <- c$value
    }
    r <- o$random_effect
    .brain_object(r, c('group','value','available','active'))
    .brain_assert(identical(r$available, mixed) && identical(r$active, mixed && mode == 'conditional') &&
      .brain_number(r$value) && (if (mixed) .brain_string(r$group) else is.null(r$group)) &&
      (r$active || r$value == 0), 'invalid random effect')
    .brain_assert(all(vapply(o[c('eta','prediction','observed','residual')], .brain_number, logical(1))), 'non-finite observation')
    .brain_assert(.brain_equal(o$eta, sum(values)+r$value) && .brain_equal(o$prediction, as.numeric(inverse(o$eta))) &&
      .brain_equal(o$residual, o$observed-o$prediction), 'inconsistent eta, prediction or residual')
    .brain_validate_interval(o$response_interval)
    if (mixed) .brain_assert(identical(o$response_interval,
      .brain_interval(FALSE, reason = 'Response-scale intervals are unavailable for this GLMM.')), 'invalid GLMM interval')
    if (mode == 'conditional') {
      ids[i] <- o$observation_id; predictions[i] <- o$prediction
      contribution_values[(i-1)*length(terms)+seq_along(terms)] <- values
      random[i] <- r$value
      if (mixed) groups[i] <- r$group
    } else {
      first <- brain$observations[[i]]
      .brain_assert(identical(o$observation_id, first$observation_id) && identical(o$inputs, first$inputs) &&
        identical(o$contributions, first$contributions) && identical(o$observed, first$observed) &&
        identical(r$group, first$random_effect$group), 'inconsistent population observation')
    }
  }
  .brain_assert(!anyDuplicated(ids) && identical(brain$default_observation_id,
    ids[order(predictions, ids, method = 'radix')[ceiling(n/2)]]), 'invalid default or duplicate observation ID')
  .brain_object(brain$link_curve, c('eta','prediction','valid'))
  curve <- brain$link_curve
  .brain_assert(is.numeric(curve$eta) && is.null(attributes(curve$eta)) &&
    length(curve$eta) == 201 && all(is.finite(curve$eta)) &&
    is.numeric(curve$prediction) && is.null(attributes(curve$prediction)) &&
    length(curve$prediction) == 201 && all(is.finite(curve$prediction)) &&
    identical(curve$valid, rep(TRUE, 201L)), 'invalid link samples')
  .brain_assert(.brain_equal(curve$eta, .brain_link_grid(vapply(brain$observations, `[[`, numeric(1), 'eta'), brain$link)) &&
    .brain_equal(curve$prediction, as.numeric(inverse(curve$eta))), 'inconsistent link curve')
  .brain_object(brain$global_summaries, c('coefficients','contributions','random_effects'))
  .brain_validate_summary(brain$global_summaries$coefficients, estimates)
  .brain_validate_summary(brain$global_summaries$contributions, contribution_values)
  if (mixed) {
    .brain_assert(all(vapply(split(random, groups), function(x) length(unique(x)) == 1L, logical(1))), 'inconsistent group intercepts')
    .brain_validate_summary(brain$global_summaries$random_effects,
      random[match(sort(unique(groups), method = 'radix'), groups)])
  } else .brain_assert(is.null(brain$global_summaries$random_effects), 'unexpected random summary')
  .brain_assert(.brain_array(brain$warnings), 'invalid warning collection')
  for (warning in brain$warnings) {
    .brain_object(warning, c('code','scope','message'))
    .brain_assert(all(vapply(warning, .brain_string, logical(1))), 'invalid warning record')
  }
  .brain_assert(!anyDuplicated(brain$warnings), 'duplicate warning records')
  invisible(brain)
}
