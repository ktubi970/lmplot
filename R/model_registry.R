MODEL_REGISTRY <- list(
  lm_2d = list(label = "Simple LM (2D)", family = "gaussian", links = "identity", default_link = "identity", dimensions = 2L, requires_group = FALSE, fit_strategy = "lm"),
  lm_3d = list(label = "Multiple LM (3D)", family = "gaussian", links = "identity", default_link = "identity", dimensions = 3L, requires_group = FALSE, fit_strategy = "lm"),
  glm_binomial_2d = list(label = "Simple Binomial GLM (2D)", family = "binomial", links = c("logit", "probit", "cloglog"), default_link = "logit", dimensions = 2L, requires_group = FALSE, fit_strategy = "glm"),
  glm_binomial = list(label = "Binomial GLM", family = "binomial", links = c("logit", "probit", "cloglog"), default_link = "logit", dimensions = 3L, requires_group = FALSE, fit_strategy = "glm"),
  glm_poisson = list(label = "Poisson GLM", family = "poisson", links = c("log", "identity", "sqrt"), default_link = "log", dimensions = 3L, requires_group = FALSE, fit_strategy = "glm"),
  glm_gamma = list(label = "Gamma GLM", family = "Gamma", links = c("inverse", "log", "identity"), default_link = "inverse", dimensions = 3L, requires_group = FALSE, fit_strategy = "glm"),
  glmm = list(label = "Gaussian GLMM", family = "gaussian", links = "identity", default_link = "identity", dimensions = 3L, requires_group = TRUE, fit_strategy = "glmm")
)

`%||%` <- function(left, right) if (is.null(left) || length(left) == 0L) right else left

model_ids <- function() names(MODEL_REGISTRY)

model_config <- function(model_type) {
  config <- MODEL_REGISTRY[[model_type]]
  if (is.null(config)) stop("Unknown model type: ", model_type, call. = FALSE)
  c(list(id = model_type), config)
}

valid_links <- function(model_type) model_config(model_type)$links

validate_model_link <- function(model_type, link = NULL) {
  config <- model_config(model_type)
  selected <- link %||% config$default_link
  if (!selected %in% config$links) {
    stop("Invalid link '", selected, "' for model '", model_type, "'", call. = FALSE)
  }
  selected
}

required_model_columns <- function(model_type) {
  config <- model_config(model_type)
  c("X", "Z", if (config$dimensions == 3L) "Y", if (config$requires_group) "Group")
}

validate_glmm_groups <- function(group) {
  if (anyNA(group)) {
    stop("GLMM Group must not contain missing values", call. = FALSE)
  }
  if (length(unique(group)) < 5L) {
    stop("GLMM data must contain at least 5 observed groups", call. = FALSE)
  }
  invisible(group)
}

validate_model_data <- function(df, model_type) {
  missing <- setdiff(required_model_columns(model_type), names(df))
  if (length(missing)) stop("Missing model columns: ", paste(missing, collapse = ", "), call. = FALSE)

  numeric <- intersect(c("X", "Y", "Z"), required_model_columns(model_type))
  if (any(!vapply(df[numeric], is.numeric, logical(1))) || any(!is.finite(as.matrix(df[numeric])))) {
    stop("Model data must contain finite numeric predictors and response", call. = FALSE)
  }
  if (startsWith(model_type, "glm_binomial") && any(!df$Z %in% c(0, 1))) stop("Binomial response must contain only 0 and 1", call. = FALSE)
  if (model_type == "glm_poisson" && any(df$Z < 0 | df$Z != floor(df$Z))) stop("Poisson response must contain non-negative integers", call. = FALSE)
  if (model_type == "glm_gamma" && any(df$Z <= 0)) stop("Gamma response must be strictly positive", call. = FALSE)
  if (model_type == "glmm") validate_glmm_groups(df$Group)
  invisible(df)
}

fit_lm_strategy <- function(df, link) {
  config <- attr(df, "model_config")
  if (is.null(config)) stop("LM fitting requires model configuration", call. = FALSE)
  formula <- if (config$dimensions == 2L) Z ~ X else Z ~ X + Y
  stats::lm(formula, data = df)
}

fit_glm_strategy <- function(df, link) {
  config <- attr(df, "model_config")
  if (is.null(config)) stop("GLM fitting requires model configuration", call. = FALSE)

  family_object <- do.call(config$family, list(link = link))
  formula <- if (config$dimensions == 2L) Z ~ X else Z ~ X + Y
  if (identical(config$id, "glm_poisson") && identical(link, "identity")) {
    design <- stats::model.matrix(formula, data = df)
    start <- numeric(ncol(design))
    names(start) <- colnames(design)
    start[["(Intercept)"]] <- mean(df$Z) + 0.1
    return(stats::glm(formula, data = df, family = family_object, start = start))
  }
  stats::glm(formula, data = df, family = family_object)
}

abort_analysis_dependency <- function(message) {
  stop(structure(list(message = message, call = NULL),
    class = c("analysis_dependency_error", "error", "condition")))
}

fit_glmm_strategy <- function(df, link, namespace_available = function(pkg) requireNamespace(pkg, quietly = TRUE)) {
  if (!namespace_available("lme4")) {
    abort_analysis_dependency("Gaussian GLMM requires the lme4 package")
  }

  model_data <- df
  model_data$Group <- factor(model_data$Group)
  lme4::lmer(Z ~ X + Y + (1 | Group), data = model_data)
}

FIT_STRATEGIES <- list(
  lm = fit_lm_strategy,
  glm = fit_glm_strategy,
  glmm = fit_glmm_strategy
)

model_fit_warnings <- function(fit) attr(fit, "model_fit_warnings") %||% character()

fit_model <- function(df, model_type, link = NULL) {
  config <- model_config(model_type)
  resolved_link <- validate_model_link(model_type, link)
  validate_model_data(df, model_type)
  attr(df, "model_config") <- config

  warnings <- character()
  fit <- withCallingHandlers(
    FIT_STRATEGIES[[config$fit_strategy]](df, resolved_link),
    warning = function(warning) warnings <<- c(warnings, conditionMessage(warning))
  )
  attr(fit, "model_fit_warnings") <- warnings
  fit
}
