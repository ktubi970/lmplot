MODEL_REGISTRY <- list(
  lm_2d = list(label = "Simple LM (2D)", family = "gaussian", links = "identity", default_link = "identity", dimensions = 2L, requires_group = FALSE),
  lm_3d = list(label = "Multiple LM (3D)", family = "gaussian", links = "identity", default_link = "identity", dimensions = 3L, requires_group = FALSE),
  glm_binomial_2d = list(label = "Simple Binomial GLM (2D)", family = "binomial", links = c("logit", "probit", "cloglog"), default_link = "logit", dimensions = 2L, requires_group = FALSE),
  glm_binomial = list(label = "Binomial GLM", family = "binomial", links = c("logit", "probit", "cloglog"), default_link = "logit", dimensions = 3L, requires_group = FALSE),
  glm_poisson = list(label = "Poisson GLM", family = "poisson", links = c("log", "identity", "sqrt"), default_link = "log", dimensions = 3L, requires_group = FALSE),
  glm_gamma = list(label = "Gamma GLM", family = "Gamma", links = c("inverse", "log", "identity"), default_link = "inverse", dimensions = 3L, requires_group = FALSE),
  glmm = list(label = "Gaussian GLMM", family = "gaussian", links = "identity", default_link = "identity", dimensions = 3L, requires_group = TRUE)
)

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

`%||%` <- function(left, right) if (is.null(left) || length(left) == 0L) right else left

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

fit_model <- function(df, model_type, link = NULL) {
  config <- model_config(model_type)
  link <- validate_model_link(model_type, link)
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
  if (model_type == "lm_2d") return(stats::lm(Z ~ X, data = df))
  if (model_type == "lm_3d") return(stats::lm(Z ~ X + Y, data = df))
  if (model_type == "glmm") {
    model_data <- df
    model_data$Group <- factor(model_data$Group)
    if (requireNamespace("lme4", quietly = TRUE)) {
      lmer_fn <- getExportedValue("lme4", "lmer")
      return(lmer_fn(Z ~ X + Y + (1 | Group), data = model_data))
    } else if (requireNamespace("nlme", quietly = TRUE)) {
      lme_fn <- getExportedValue("nlme", "lme")
      return(lme_fn(Z ~ X + Y, random = ~ 1 | Group, data = model_data))
    } else {
      return(stats::lm(Z ~ X + Y + Group, data = model_data))
    }
  }
  family_object <- do.call(config$family, list(link = link))
  if (config$dimensions == 2L) {
    return(stats::glm(Z ~ X, data = df, family = family_object))
  }
  if (model_type == "glm_poisson" && link == "identity") {
    design <- stats::model.matrix(Z ~ X + Y, data = df)
    start <- numeric(ncol(design))
    names(start) <- colnames(design)
    start[["(Intercept)"]] <- mean(df$Z) + 0.1
    return(stats::glm(
      Z ~ X + Y,
      data = df,
      family = family_object,
      start = start
    ))
  }
  stats::glm(Z ~ X + Y, data = df, family = family_object)
}

predict_response <- function(fit, newdata = NULL, population = FALSE) {
  if (inherits(fit, "glm")) return(stats::predict(fit, newdata = newdata, type = "response"))
  if (inherits(fit, "merMod")) return(stats::predict(fit, newdata = newdata, re.form = if (population) NA else NULL, allow.new.levels = TRUE))
  if (inherits(fit, "lme")) return(as.numeric(stats::predict(fit, newdata = newdata, level = if (population) 0 else 1)))
  stats::predict(fit, newdata = newdata)
}

fitted_response <- function(fit) as.numeric(predict_response(fit))

response_residuals <- function(fit) {
  observed <- stats::model.response(stats::model.frame(fit))
  as.numeric(observed - fitted_response(fit))
}
