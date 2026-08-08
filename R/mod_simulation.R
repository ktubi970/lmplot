library(shiny)
library(shinyWidgets)
library(shinyAce)

simulate_data <- function(model_type, link = NULL, n = 200L, seed = 123L,
                          beta0 = 2, beta1 = 0.5, beta2 = -0.25,
                          sigma = 1, shape = 2, group_sd = 1, groups = 5L) {
  config <- model_config(model_type)
  link <- validate_model_link(model_type, link)
  if (model_type == "glmm") {
    valid_groups <- length(groups) == 1L && is.numeric(groups) &&
      !is.na(groups) && is.finite(groups) && groups == floor(groups) &&
      groups >= 5L
    if (!valid_groups) {
      stop(
        "GLMM groups must be a single integer of at least 5",
        call. = FALSE
      )
    }
    if (groups > n) {
      stop("GLMM groups must not exceed sample size n", call. = FALSE)
    }
  }
  stopifnot(n >= 10L, sigma > 0, shape > 0, group_sd >= 0)
  set.seed(as.integer(seed))
  X <- stats::runif(n, -1, 1)
  Y <- stats::runif(n, -1, 1)
  eta <- if (config$dimensions == 2L) beta0 + beta1 * X else beta0 + beta1 * X + beta2 * Y

  if (model_type == "lm_2d") {
    result <- data.frame(X = X, Z = beta0 + beta1 * X + stats::rnorm(n, 0, sigma))
  } else if (model_type == "lm_3d") {
    result <- data.frame(X = X, Y = Y, Z = eta + stats::rnorm(n, 0, sigma))
  } else if (model_type == "glmm") {
    Group <- factor(rep(seq_len(groups), length.out = n))
    offsets <- stats::rnorm(groups, 0, group_sd)
    Z <- eta + offsets[as.integer(Group)] + stats::rnorm(n, 0, sigma)
    result <- data.frame(X = X, Y = Y, Z = Z, Group = Group)
  } else {
    family_object <- do.call(config$family, list(link = link))
    mu <- family_object$linkinv(eta)
    if (any(!is.finite(mu))) stop("Selected coefficients produce non-finite means", call. = FALSE)
    if (config$family == "binomial") {
      mu <- pmin(pmax(mu, .Machine$double.eps), 1 - .Machine$double.eps)
      Z <- stats::rbinom(n, 1, mu)
    } else if (config$family == "poisson") {
      if (any(mu <= 0)) stop("Selected coefficients produce non-positive Poisson means", call. = FALSE)
      Z <- stats::rpois(n, mu)
    } else {
      if (any(mu <= 0)) stop("Selected coefficients produce non-positive Gamma means", call. = FALSE)
      Z <- stats::rgamma(n, shape = shape, rate = shape / mu)
    }
    result <- if (config$dimensions == 2L) data.frame(X = X, Z = Z) else data.frame(X = X, Y = Y, Z = Z)
  }
  validate_simulation_data(result, model_type)
  result
}

validate_simulation_data <- function(df, model_type) {
  config <- model_config(model_type)
  required <- c("X", "Z", if (config$dimensions == 3L) "Y", if (config$requires_group) "Group")
  missing <- setdiff(required, names(df))
  if (!is.data.frame(df) || length(missing)) stop("Simulation must return a data frame with required columns: ", paste(required, collapse = ", "), call. = FALSE)
  numeric_columns <- intersect(c("X", "Y", "Z"), required)
  if (any(!vapply(df[numeric_columns], is.numeric, logical(1)))) stop("Simulation columns X, Y, and Z must be numeric", call. = FALSE)
  if (any(!is.finite(as.matrix(df[numeric_columns])))) stop("Simulation contains non-finite values", call. = FALSE)
  if (model_type == "glm_binomial" && any(!df$Z %in% c(0, 1))) stop("Binomial response must contain only 0 and 1", call. = FALSE)
  if (model_type == "glm_poisson" && any(df$Z < 0 | df$Z != floor(df$Z))) stop("Poisson response must contain non-negative integers", call. = FALSE)
  if (model_type == "glm_gamma" && any(df$Z <= 0)) stop("Gamma response must be strictly positive", call. = FALSE)
  if (model_type == "glmm") validate_glmm_groups(df$Group)
  invisible(df)
}

evaluate_expert_simulation <- function(code, parameters, model_type, link = NULL) {
  environment <- list2env(c(parameters, list(simulate_data = simulate_data)), parent = baseenv())
  result <- eval(parse(text = code), envir = environment)
  validate_simulation_data(result, model_type)
  result
}

simulation_code <- function(model_type, link, parameters) {
  call <- as.call(c(quote(simulate_data), list(model_type = model_type, link = link), parameters))
  paste(deparse(call, width.cutoff = 100L), collapse = "\n")
}

sim_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shinyWidgets::switchInput(
      ns("expert_mode"),
      "Simulation mode",
      onLabel = "Expert",
      offLabel = "Standard",
      value = FALSE
    ),
    shiny::uiOutput(ns("controls_ui"))
  )
}

sim_server <- function(id, model_type, link, trigger) {
  shiny::moduleServer(id, function(input, output, session) {
    output$controls_ui <- shiny::renderUI({
      config <- model_config(model_type())

      if (isTRUE(input$expert_mode)) {
        default_code <- simulation_code(
          model_type(),
          link(),
          list(n = 200L, seed = 123L)
        )
        return(shinyAce::aceEditor(
          session$ns("code"),
          value = default_code,
          mode = "r",
          theme = "monokai",
          height = "220px"
        ))
      }

      controls <- list(
        shiny::numericInput(
          session$ns("n"), "Sample size", 200L,
          min = 10L, max = 2000L
        ),
        shiny::numericInput(session$ns("seed"), "Seed", 123L),
        shiny::sliderInput(
          session$ns("beta0"), "Intercept", -3, 5, 2,
          step = 0.1
        ),
        shiny::sliderInput(
          session$ns("beta1"), "X coefficient", -2, 2, 0.5,
          step = 0.1
        )
      )
      if (config$dimensions == 3L) {
        controls <- c(controls, list(shiny::sliderInput(
          session$ns("beta2"), "Y coefficient", -2, 2, -0.25,
          step = 0.1
        )))
      }
      if (model_type() %in% c("lm_2d", "lm_3d", "glmm")) {
        controls <- c(controls, list(shiny::sliderInput(
          session$ns("sigma"), "Noise sigma", 0.1, 5, 1,
          step = 0.1
        )))
      }
      if (model_type() == "glm_gamma") {
        controls <- c(controls, list(shiny::sliderInput(
          session$ns("shape"), "Gamma shape", 0.5, 10, 2,
          step = 0.5
        )))
      }
      if (model_type() == "glmm") {
        controls <- c(controls, list(
          shiny::sliderInput(
            session$ns("group_sd"), "Group SD", 0, 4, 1,
            step = 0.1
          ),
          shiny::numericInput(
            session$ns("groups"), "Groups", 5L,
            min = 5L, max = 20L
          )
        ))
      }
      do.call(shiny::tagList, controls)
    })

    shiny::eventReactive(trigger(), {
      model_snapshot <- model_type()
      link_snapshot <- link()
      parameters <- list(
        n = input$n %||% 200L,
        seed = input$seed %||% 123L,
        beta0 = input$beta0 %||% 2,
        beta1 = input$beta1 %||% 0.5,
        beta2 = input$beta2 %||% -0.25,
        sigma = input$sigma %||% 1,
        shape = input$shape %||% 2,
        group_sd = input$group_sd %||% 1,
        groups = input$groups %||% 5L
      )
      expert_mode <- isTRUE(input$expert_mode)
      code <- if (expert_mode) {
        input$code
      } else {
        simulation_code(model_snapshot, link_snapshot, parameters)
      }
      if (expert_mode && (is.null(code) || !nzchar(code))) {
        stop("Expert simulation code is required", call. = FALSE)
      }
      data <- if (expert_mode) {
        evaluate_expert_simulation(
          code,
          parameters,
          model_snapshot,
          link_snapshot
        )
      } else {
        do.call(
          simulate_data,
          c(
            list(model_type = model_snapshot, link = link_snapshot),
            parameters
          )
        )
      }
      list(
        data = data,
        code = code,
        parameters = parameters,
        model_type = model_snapshot,
        link = link_snapshot
      )
    }, ignoreInit = FALSE)
  })
}
