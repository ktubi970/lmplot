library(shiny)
library(shinyWidgets)
library(shinyAce)

simulate_data <- function(model_type, link = NULL, n = 200L, seed = 123L,
                          beta0 = 2, beta1 = 0.5, beta2 = -0.25,
                          sigma = 1, shape = 2, group_sd = 1, groups = 5L) {
  config <- model_config(model_type)
  link <- validate_model_link(model_type, link)
  stopifnot(n >= 10L, groups >= 2L, sigma > 0, shape > 0, group_sd >= 0)
  set.seed(as.integer(seed))
  X <- stats::runif(n, -1, 1)
  Y <- stats::runif(n, -1, 1)
  eta <- beta0 + beta1 * X + beta2 * Y

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
    result <- data.frame(X = X, Y = Y, Z = Z)
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
  ns <- NS(id)
  tagList(
    div(
      class = "d-flex justify-content-between align-items-center mb-3",
      span(class = "label", "Mode de simulation"),
      switchInput(
        ns("expert_mode"),
        value = FALSE,
        size = "small",
        onLabel = "Expert",
        offLabel = "Standard"
      )
    ),
    uiOutput(ns("controls_ui"))
  )
}

sim_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    output$controls_ui <- renderUI({
      if (!isTRUE(input$expert_mode)) {
        tagList(
          sliderInput(ns("beta1"), "Pente (beta1)", min = -2, max = 2, value = 0.5, step = 0.1),
          sliderInput(ns("sigma"), "Bruit (sigma)", min = 0.1, max = 5, value = 1, step = 0.1),
          numericInput(ns("n"), "Taille d'echantillon (n)", value = 100, min = 10, max = 1000),
          numericInput(ns("seed"), "Graine (Seed)", value = 123)
        )
      } else {
        aceEditor(
          ns("code"),
          value = "set.seed(input$seed)\nn <- input$n\nx <- rnorm(n)\ny <- 2 + 0.5*x + rnorm(n, 0, 1)\ndata.frame(x=x, y=y)",
          mode = "r",
          theme = "monokai",
          height = "200px"
        )
      }
    })

    reactive_data <- reactive({
      if (!isTRUE(input$expert_mode)) {
        req(input$beta1, input$sigma, input$n, input$seed)
        set.seed(input$seed)
        x <- rnorm(input$n)
        y <- 2 + input$beta1 * x + rnorm(input$n, 0, input$sigma)
        data.frame(x = x, y = y)
      } else {
        req(input$code)
        env <- new.env()
        env$input <- input
        tryCatch({
          eval(parse(text = input$code), envir = env)
        }, error = function(e) {
          showNotification(paste("Erreur dans le code expert:", e$message), type = "error")
          NULL
        })
      }
    })

    return(reactive_data)
  })
}
