if (requireNamespace("shiny", quietly = TRUE)) {
  suppressPackageStartupMessages({
    library(shiny)
    library(shinyWidgets)
    library(shinyAce)
  })
}

simulate_data <- function(model_type, link = NULL, n = 200L, seed = 123L,
                          beta0 = 2, beta1 = 0.5, beta2 = -0.25,
                          sigma = 1, shape = 2, group_sd = 1, groups = 5L,
                          pattern = "linear") {
  config <- model_config(model_type)
  link <- validate_model_link(model_type, link)
  valid_patterns <- c("linear", "quadratic", "cosine", "heteroscedastic")
  if (!pattern %in% valid_patterns) {
    stop("Invalid simulation pattern: ", pattern, call. = FALSE)
  }
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

  nonlin_effect <- switch(pattern,
    "linear" = 0,
    "quadratic" = if (config$dimensions == 2L) 1.5 * X^2 else 1.5 * Y^2,
    "cosine" = if (config$dimensions == 2L) 2.5 * cos(3 * X) else 2.5 * cos(3 * Y),
    "heteroscedastic" = 0
  )

  noise_scale <- if (pattern == "heteroscedastic") {
    if (config$dimensions == 2L) sigma * (1 + 3 * abs(X)) else sigma * (1 + 3 * abs(Y))
  } else {
    sigma
  }

  eta <- if (config$dimensions == 2L) beta0 + beta1 * X else beta0 + beta1 * X + beta2 * Y

  if (model_type == "lm_2d") {
    result <- data.frame(X = X, Z = beta0 + beta1 * X + nonlin_effect + stats::rnorm(n, 0, noise_scale))
  } else if (model_type == "lm_3d") {
    result <- data.frame(X = X, Y = Y, Z = eta + nonlin_effect + stats::rnorm(n, 0, noise_scale))
  } else if (model_type == "glmm") {
    Group <- factor(rep(seq_len(groups), length.out = n))
    offsets <- stats::rnorm(groups, 0, group_sd)
    Z <- eta + nonlin_effect + offsets[as.integer(Group)] + stats::rnorm(n, 0, noise_scale)
    result <- data.frame(X = X, Y = Y, Z = Z, Group = Group)
  } else {
    family_object <- do.call(config$family, list(link = link))
    mu <- family_object$linkinv(eta + nonlin_effect)
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
  config <- model_config(model_type)
  link <- validate_model_link(model_type, link)

  n <- parameters$n %||% 200L
  seed <- parameters$seed %||% 123L
  beta0 <- parameters$beta0 %||% 2
  beta1 <- parameters$beta1 %||% 0.5
  beta2 <- parameters$beta2 %||% -0.25
  sigma <- parameters$sigma %||% 1
  shape <- parameters$shape %||% 2
  group_sd <- parameters$group_sd %||% 1
  groups <- parameters$groups %||% 5L

  lines <- c(
    paste0("set.seed(", seed, "L)"),
    paste0("n <- ", n, "L"),
    "X <- runif(n, -1, 1)"
  )

  if (config$dimensions == 3L) {
    lines <- c(lines, "Y <- runif(n, -1, 1)")
  }

  if (model_type == "lm_2d") {
    lines <- c(
      lines,
      paste0("Z <- ", beta0, " + ", beta1, " * X + rnorm(n, 0, ", sigma, ")"),
      "data.frame(X = X, Z = Z)"
    )
  } else if (model_type == "lm_3d") {
    lines <- c(
      lines,
      paste0("Z <- ", beta0, " + ", beta1, " * X + ", beta2, " * Y + rnorm(n, 0, ", sigma, ")"),
      "data.frame(X = X, Y = Y, Z = Z)"
    )
  } else if (model_type == "glmm") {
    lines <- c(
      lines,
      paste0("groups <- ", groups, "L"),
      "Group <- factor(rep(seq_len(groups), length.out = n))",
      paste0("offsets <- rnorm(groups, 0, ", group_sd, ")"),
      paste0("eta <- ", beta0, " + ", beta1, " * X + ", beta2, " * Y + offsets[as.integer(Group)]"),
      paste0("Z <- eta + rnorm(n, 0, ", sigma, ")"),
      "data.frame(X = X, Y = Y, Z = Z, Group = Group)"
    )
  } else {
    linear_pred <- if (config$dimensions == 2L) {
      paste0(beta0, " + ", beta1, " * X")
    } else {
      paste0(beta0, " + ", beta1, " * X + ", beta2, " * Y")
    }
    lines <- c(lines, paste0("eta <- ", linear_pred))

    if (config$family == "binomial") {
      if (link == "logit") {
        lines <- c(lines, "mu <- 1 / (1 + exp(-eta))")
      } else if (link == "probit") {
        lines <- c(lines, "mu <- pnorm(eta)")
      } else if (link == "cloglog") {
        lines <- c(lines, "mu <- 1 - exp(-exp(eta))")
      }
      lines <- c(lines, "Z <- rbinom(n, 1, mu)")
    } else if (config$family == "poisson") {
      if (link == "log") {
        lines <- c(lines, "mu <- exp(eta)")
      } else if (link == "identity") {
        lines <- c(lines, "mu <- eta")
      } else if (link == "sqrt") {
        lines <- c(lines, "mu <- eta^2")
      }
      lines <- c(lines, "Z <- rpois(n, mu)")
    } else if (config$family == "Gamma") {
      if (link == "inverse") {
        lines <- c(lines, "mu <- 1 / eta")
      } else if (link == "log") {
        lines <- c(lines, "mu <- exp(eta)")
      } else if (link == "identity") {
        lines <- c(lines, "mu <- eta")
      }
      lines <- c(
        lines,
        paste0("shape <- ", shape),
        "Z <- rgamma(n, shape = shape, rate = shape / mu)"
      )
    }

    if (config$dimensions == 2L) {
      lines <- c(lines, "data.frame(X = X, Z = Z)")
    } else {
      lines <- c(lines, "data.frame(X = X, Y = Y, Z = Z)")
    }
  }

  paste(lines, collapse = "\n")
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
        shiny::selectInput(
          session$ns("pattern"), "Modèle Générateur / Relation",
          choices = c(
            "📏 Vrai modèle linéaire" = "linear",
            "🔄 Non-linéaire : Quadratique (Y² / X²)" = "quadratic",
            "🌊 Non-linéaire : Périodique (cos(Y) / cos(X))" = "cosine",
            "💥 Non-linéaire : Variance importante (Hétéroscédasticité)" = "heteroscedastic"
          ),
          selected = "linear"
        ),
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
        pattern = input$pattern %||% "linear",
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
