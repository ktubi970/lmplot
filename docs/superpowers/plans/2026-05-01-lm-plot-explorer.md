# LM Plot Explorer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a professional standalone Shiny app for interactive regression modeling and simulation.

**Architecture:** Modular Shiny app using `{bslib}` for layout, `{plotly}` for interactivity, and a hybrid simulation engine (sliders + Ace editor).

**Tech Stack:** R, Shiny, bslib, plotly, ggfortify, DT, shinyAce.

---

### Task 1: Project Skeleton & UI Shell

**Files:**
- Create: `app.R`
- Create: `www/style.css`

- [ ] **Step 1: Create the main app.R with bslib layout**

```r
library(shiny)
library(bslib)
library(plotly)
library(DT)
library(ggfortify)
library(shinyAce)

ui <- page_sidebar(
  title = "LM Plot Explorer",
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  sidebar = sidebar(
    title = "Configuration",
    accordion(
      accordion_panel(
        "RÉGRESSION LINÉAIRE",
        radioButtons("model_type", "Type:", choices = c("lm" = "lm"), selected = "lm")
      ),
      accordion_panel(
        "MODÈLES GÉNÉRALISÉS",
        "Bientôt disponible..."
      ),
      accordion_panel(
        "EFFETS MIXTES",
        "Bientôt disponible..."
      )
    ),
    actionButton("refresh", "Générer & Ajuster", class = "btn-success w-100 mt-3")
  ),
  layout_column_wrap(
    width = 1,
    card(
      card_header("Régression Interactive"),
      plotlyOutput("main_plot", height = "350px")
    ),
    layout_column_wrap(
      width = 1/2,
      card(
        card_header("Simulation & Code"),
        # Simulation UI placeholders
        uiOutput("sim_controls")
      ),
      navset_card_tab(
        title = "Diagnostics & Résultats",
        nav_panel("Diagnostics", plotOutput("diag_plot")),
        nav_panel("Données", DTOutput("data_table")),
        nav_panel("Summary", verbatimTextOutput("model_summary"))
      )
    )
  )
)

server <- function(input, output, session) {
  # Server logic to be implemented
}

shinyApp(ui, server)
```

- [ ] **Step 2: Verify app starts**

Run: `Rscript -e "shiny::runApp('app.R', port=3000, launch.browser=FALSE)"`
Expected: Server starts without errors.

- [ ] **Step 3: Commit**

```bash
git add app.R
git commit -m "feat: initial app skeleton with bslib layout"
```

---

### Task 2: Hybrid Simulation Module

**Files:**
- Create: `R/mod_simulation.R`
- Modify: `app.R`

- [ ] **Step 1: Implement simulation logic in R/mod_simulation.R**

```r
sim_ui <- function(id) {
  ns <- NS(id)
  tagList(
    switchInput(ns("expert_mode"), "Mode Expert", value = FALSE, size = "small"),
    uiOutput(ns("controls_ui"))
  )
}

sim_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    output$controls_ui <- renderUI({
      if (!input$expert_mode) {
        tagList(
          sliderInput(ns("beta1"), "Pente (β1)", -2, 2, 0.5, step = 0.1),
          sliderInput(ns("sigma"), "Bruit (σ)", 0, 5, 1, step = 0.1),
          numericInput(ns("n"), "Taille (n)", 100, min = 10),
          numericInput(ns("seed"), "Seed", 123)
        )
      } else {
        aceEditor(ns("code"), 
                  value = "set.seed(input$seed)\nx <- rnorm(input$n)\ny <- 2 + 0.5*x + rnorm(input$n, 0, 1)\ndata.frame(x=x, y=y)",
                  mode = "r", theme = "monokai", height = "150px")
      }
    })
    
    reactive_data <- reactive({
      if (!input$expert_mode) {
        set.seed(input$seed)
        x <- rnorm(input$n)
        y <- 2 + input$beta1 * x + rnorm(input$n, 0, input$sigma)
        data.frame(x = x, y = y)
      } else {
        # Simple eval for expert mode (demo purpose)
        eval(parse(text = input$code))
      }
    })
    
    return(reactive_data)
  })
}
```

- [ ] **Step 2: Integrate module in app.R**

- [ ] **Step 3: Commit**

---

### Task 3: Interactive Plotting with Plotly

**Files:**
- Modify: `app.R`

- [ ] **Step 1: Add plotly logic to server**

```r
output$main_plot <- renderPlotly({
  df <- data()
  fit <- lm(y ~ x, data = df)
  
  p <- ggplot(df, aes(x = x, y = y)) +
    geom_point(aes(text = paste("Residual:", round(resid(fit), 2))), color = "#3498db", alpha = 0.6) +
    geom_smooth(method = "lm", color = "#e74c3c") +
    theme_minimal()
    
  ggplotly(p, tooltip = "text")
})
```

- [ ] **Step 2: Verify interactivity**

- [ ] **Step 3: Commit**

---

### Task 4: Diagnostics with ggfortify

**Files:**
- Modify: `app.R`

- [ ] **Step 1: Implement diagnostic plots**

```r
output$diag_plot <- renderPlot({
  df <- data()
  fit <- lm(y ~ x, data = df)
  autoplot(fit, which = 1:4, ncol = 2) + theme_minimal()
})
```

- [ ] **Step 2: Add DT and Summary**

```r
output$data_table <- renderDT({
  datatable(data(), options = list(pageLength = 5))
})

output$model_summary <- renderPrint({
  summary(lm(y ~ x, data = data()))
})
```

- [ ] **Step 3: Commit**

---

### Task 5: Final Styling & Sidebar Polish

**Files:**
- Modify: `www/style.css`
- Modify: `app.R`

- [ ] **Step 1: Add custom CSS for premium look**

```css
.card {
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
  border-radius: 8px;
}
.sidebar {
  background-color: #f8f9fa;
}
```

- [ ] **Step 2: Final verification of all features**

- [ ] **Step 3: Final Commit**
