library(shiny)
library(plotly)
library(shinythemes)
library(bslib)
library(DT)
library(ggplot2)
library(lme4)

# Helper: generate random data ------------------------------------------------
generate_data <- function(n = 200, type = "lm_3d") {
  set.seed(as.numeric(Sys.time()))
  x <- runif(n, 0, 10)
  y <- runif(n, 0, 10)
  
  if (type == "glmm") {
    # GLMM: Random intercept for 5 groups
    groups <- factor(rep(seq_len(5), length.out = n))
    group_effects <- rnorm(5, 0, 3) # Random intercepts
    eps <- rnorm(n, 0, 1)
    z <- 2 + 1.5 * x - 0.8 * y + group_effects[as.numeric(groups)] + eps
    return(data.frame(X = x, Y = y, Z = z, Group = groups))
  } else if (type == "glm_logistic") {
    lp <- -5 + 0.8 * x + 0.4 * y
    z <- rbinom(n, 1, 1 / (1 + exp(-lp)))
  } else if (type == "glm_poisson") {
    z <- rpois(n, exp(0.5 + 0.2 * x + 0.1 * y))
  } else if (type == "lm_2d") {
    z <- 2 + 1.5 * x + rnorm(n, 0, 1)
  } else {
    z <- 2 + 1.5 * x - 0.8 * y + rnorm(n, 0, 2)
  }
  
  data.frame(X = x, Y = y, Z = z, Group = factor(1))
}

# Helper: fit model -----------------------------------------------------------
fit_model <- function(df, type = "lm_3d") {
  if (type == "lm_2d") {
    lm(Z ~ X, data = df)
  } else if (type == "glm_logistic") {
    glm(Z ~ X + Y, data = df, family = binomial)
  } else if (type == "glm_poisson") {
    glm(Z ~ X + Y, data = df, family = poisson)
  } else if (type == "glmm") {
    lmer(Z ~ X + Y + (1 | Group), data = df)
  } else {
    lm(Z ~ X + Y, data = df)
  }
}

# UI Definition ---------------------------------------------------------------
ui <- page_sidebar(
  title = "LM Plot Explorer",
  theme = bs_theme(version = 5, bootswatch = "flatly", primary = "#2563eb"),
  sidebar = sidebar(
    title = "Selection:",
    radioButtons("model_type", NULL, 
                 choices = c("Simple LM (2D)" = "lm_2d", 
                             "Multiple LM (3D)" = "lm_3d", 
                             "Logistic GLM (Binomial)" = "glm_logistic", 
                             "Poisson GLM (Count)" = "glm_poisson", 
                             "GLMM (Mixed Effects)" = "glmm"), 
                 selected = "lm_3d"),
    hr(),
    actionButton("regen", "Regenerate Data", class = "btn-primary w-100"),
    checkboxInput("show_plane", "Show Regression Surface", TRUE)
  ),
  tags$head(tags$link(rel = "stylesheet", type = "text/css", href = "style.css")),
  
  # Main Layout
  layout_column_wrap(
    width = 1,
    heights_equal = "all",
    
    # Top Panel: Visualization
    card(
      full_screen = TRUE,
      card_header("Visualization"),
      plotlyOutput("main_plot", height = "450px")
    ),
    
    # Bottom Panel: Two Columns
    layout_column_wrap(
      width = 1/2,
      
      # Bottom Left: Summary & Code
      layout_column_wrap(
        width = 1,
        card(
          card_header("Statistical Summary"),
          verbatimTextOutput("model_summary")
        ),
        card(
          card_header("Simulation Code"),
          verbatimTextOutput("sim_code")
        )
      ),
      
      # Bottom Right: Diagnostics & Data
      navset_card_tab(
        title = "Diagnostics & Data",
        nav_panel("Diagnostics", plotOutput("diag_plots", height = "350px")),
        nav_panel("Data Table", DTOutput("data_table"))
      )
    )
  )
)

# Server Logic ----------------------------------------------------------------
server <- function(input, output, session) {
  data <- reactiveVal(generate_data())
  
  model <- reactive({ 
    fit_model(data(), input$model_type)
  })

  observeEvent(input$regen, {
    data(generate_data(type = input$model_type))
  })
  
  observeEvent(input$model_type, {
    data(generate_data(type = input$model_type))
  })

  output$main_plot <- renderPlotly({
    df <- data()
    fit <- model()
    
    if (input$model_type == "lm_2d") {
      p <- ggplot(df, aes(x = X, y = Z)) +
        geom_point(color = "#ff6f91", alpha = 0.6) +
        theme_minimal() +
        labs(title = "Simple Linear Regression: Z ~ X")
      if (input$show_plane) p <- p + geom_smooth(method = "lm", color = "#2563eb", fill = "#2563eb", alpha = 0.2)
      ggplotly(p) %>% layout(paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)")
    } else {
      # 3D Plot for LM, GLM, and GLMM
      # Use fixed effects for the surface
      coeffs <- if(input$model_type == "glmm") fixef(fit) else coef(fit)
      
      p <- plot_ly() %>%
        add_markers(data = df, x = ~X, y = ~Y, z = ~Z, color = ~Group,
                    marker = list(size = 4),
                    name = ~paste("Group", Group))
      
      if (input$show_plane) {
        grid <- seq(0, 10, length.out = 30)
        grid_df <- expand.grid(X = grid, Y = grid)
        
        if (input$model_type == "glm_logistic") {
          lp <- coeffs[1] + coeffs[2] * grid_df$X + coeffs[3] * grid_df$Y
          grid_df$Z <- 1 / (1 + exp(-lp))
        } else if (input$model_type == "glm_poisson") {
          lp <- coeffs[1] + coeffs[2] * grid_df$X + coeffs[3] * grid_df$Y
          grid_df$Z <- exp(lp)
        } else {
          grid_df$Z <- coeffs[1] + coeffs[2] * grid_df$X + coeffs[3] * grid_df$Y
        }
        
        surface_mat <- matrix(grid_df$Z, nrow = length(grid), ncol = length(grid)) %>% t()
        p <- p %>% add_surface(x = grid, y = grid, z = surface_mat,
                               opacity = 0.4, showscale = FALSE,
                               colorscale = list(c(0, "#4e79a7"), c(1, "#a0cbe8")),
                               name = "Population Trend")
      }
      p %>% layout(
        scene = list(xaxis = list(title = "X"), yaxis = list(title = "Y"), zaxis = list(title = "Z")),
        paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
        margin = list(l=0, r=0, b=0, t=0)
      )
    }
  })

  output$model_summary <- renderPrint({
    summary(model())
  })

  output$sim_code <- renderText({
    if (input$model_type == "glmm") {
      "n <- 200\ngroups <- factor(rep(seq_len(5), length.out = n))\ng_eff <- rnorm(5, 0, 3)\nx <- runif(n, 0, 10)\ny <- runif(n, 0, 10)\nz <- 2 + 1.5*x - 0.8*y + g_eff[as.numeric(groups)] + rnorm(n)\ndf <- data.frame(X=x, Y=y, Z=z, Group=groups)\nfit <- lmer(Z ~ X + Y + (1 | Group), data = df)"
    } else if (input$model_type == "glm_logistic") {
      "n <- 200\nx <- runif(n, 0, 10)\ny <- runif(n, 0, 10)\nlp <- -5 + 0.8 * x + 0.4 * y\np <- 1 / (1 + exp(-lp))\nz <- rbinom(n, 1, p)\ndf <- data.frame(X = x, Y = y, Z = z)\nfit <- glm(Z ~ X + Y, data = df, family = binomial)"
    } else if (input$model_type == "glm_poisson") {
      "n <- 200\nx <- runif(n, 0, 10)\ny <- runif(n, 0, 10)\nlp <- 0.5 + 0.2 * x + 0.1 * y\nz <- rpois(n, exp(lp))\ndf <- data.frame(X = x, Y = y, Z = z)\nfit <- glm(Z ~ X + Y, data = df, family = poisson)"
    } else if (input$model_type == "lm_2d") {
      "n <- 200\nx <- runif(n, 0, 10)\nz <- 2 + 1.5 * x + rnorm(n)\ndf <- data.frame(X = x, Z = z)\nfit <- lm(Z ~ X, data = df)"
    } else {
      "n <- 200\nx <- runif(n, 0, 10)\ny <- runif(n, 0, 10)\nz <- 2 + 1.5 * x - 0.8 * y + rnorm(n, 0, 2)\ndf <- data.frame(X = x, Y = y, Z = z)\nfit <- lm(Z ~ X + Y, data = df)"
    }
  })

  output$diag_plots <- renderPlot({
    if (input$model_type == "glmm") {
      # Custom plots for mixed models as plot.lmer is different
      par(mfrow = c(1, 2))
      plot(fitted(model()), resid(model()), main = "Resid vs Fitted", xlab = "Fitted", ylab = "Resid")
      qqnorm(resid(model())); qqline(resid(model()))
    } else {
      par(mfrow = c(2, 2), mar = c(4, 4, 2, 1))
      plot(model())
    }
  })

  output$data_table <- renderDT({
    datatable(data(), options = list(pageLength = 5, dom = 'tp'))
  })
}

shinyApp(ui, server)
