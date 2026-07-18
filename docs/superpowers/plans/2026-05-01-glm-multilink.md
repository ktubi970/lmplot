# LM Plot Explorer — GLM Multi-Link Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add GLM support with multiple families (Binomial, Poisson, Gamma) and their link functions to LM Plot Explorer.

**Architecture:** Extract model logic into a new `R/mod_model.R` module. The sidebar drives model selection (family + link). The simulation module generates data appropriate to the chosen family. The server becomes a thin orchestrator calling `fit_model()` from mod_model.R.

**Tech Stack:** R, Shiny, bslib, plotly, ggfortify, stats (base glm).

---

## File Structure

| File | Role |
|------|------|
| `R/mod_model.R` | **[NEW]** GLM/LM fitting logic + family/link registry |
| `R/mod_simulation.R` | **[MODIFY]** Generate data appropriate to the family selected |
| `app.R` | **[MODIFY]** Wire new sidebar controls and model module |

---

## GLM Family / Link Registry

| Family | Valid Links | Response type | Default sim |
|--------|-------------|---------------|-------------|
| `gaussian` | `identity`, `log`, `inverse` | Continuous ℝ | `lm` equivalent |
| `binomial` | `logit`, `probit`, `cloglog` | 0/1 binary | `rbinom(n, 1, p)` |
| `poisson` | `log`, `identity`, `sqrt` | Count ≥ 0 | `rpois(n, lambda)` |
| `Gamma` | `inverse`, `log`, `identity` | Positive real | `rgamma(n, shape)` |

---

### Task 1: Model Module (`R/mod_model.R`)

**Files:**
- Create: `R/mod_model.R`

- [ ] **Step 1: Define the family/link registry**

```r
# R/mod_model.R

#' Registry of all supported GLM families and their valid link functions
FAMILY_REGISTRY <- list(
  "Gaussien (lm)" = list(
    family = "gaussian",
    links = c("identity", "log", "inverse"),
    default_link = "identity"
  ),
  "Binomial (logistique)" = list(
    family = "binomial",
    links = c("logit", "probit", "cloglog"),
    default_link = "logit"
  ),
  "Poisson (comptage)" = list(
    family = "poisson",
    links = c("log", "identity", "sqrt"),
    default_link = "log"
  ),
  "Gamma" = list(
    family = "Gamma",
    links = c("inverse", "log", "identity"),
    default_link = "inverse"
  )
)

#' Fit a GLM (or LM if gaussian/identity) given data, family and link.
#'
#' @param df    data.frame with columns x and y
#' @param fam   Character: family name (e.g. "gaussian")
#' @param lnk   Character: link function name (e.g. "log")
#' @return      A fitted model object (glm or lm)
fit_model <- function(df, fam, lnk) {
  tryCatch({
    if (fam == "gaussian" && lnk == "identity") {
      lm(y ~ x, data = df)
    } else {
      glm(y ~ x, data = df, family = do.call(fam, list(link = lnk)))
    }
  }, error = function(e) {
    stop(paste("Echec de l'ajustement du modele:", e$message))
  })
}

#' Return fitted values on the RESPONSE scale (inverse-link applied)
#' @param fit  Fitted model from fit_model()
#' @return     Numeric vector of fitted values on response scale
fitted_response <- function(fit) {
  if (inherits(fit, "lm")) {
    fitted(fit)
  } else {
    predict(fit, type = "response")
  }
}
```

- [ ] **Step 2: Verify the module loads and fits correctly**

Run: `& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "source('R/mod_model.R'); set.seed(1); df <- data.frame(x=rnorm(100),y=rnorm(100)); fit <- fit_model(df,'gaussian','identity'); stopifnot(inherits(fit,'lm')); cat('OK\n')"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add R/mod_model.R
git commit -m "feat: add model registry and fit_model helper (mod_model.R)"
```

---

### Task 2: Sidebar — Family & Link Selectors

**Files:**
- Modify: `app.R` (sidebar section, lines 20–33)

- [ ] **Step 1: Source mod_model.R at top of app.R (after existing sources)**

```r
source("R/mod_model.R")
```

- [ ] **Step 2: Replace the static accordion in the sidebar**

```r
accordion(
  open = "MODÈLES",
  accordion_panel(
    "MODÈLES",
    selectInput("family_sel", "Famille",
                choices = names(FAMILY_REGISTRY),
                selected = "Gaussien (lm)"),
    uiOutput("link_ui"),
    tags$small(class = "text-muted", "Formule : y ~ x")
  )
),
actionButton("refresh", "Générer & Ajuster", class = "btn-success w-100 mt-3")
```

- [ ] **Step 3: Add server logic to render dynamic link selector**

```r
# In server():
output$link_ui <- renderUI({
  fam_cfg <- FAMILY_REGISTRY[[input$family_sel]]
  req(fam_cfg)
  selectInput("link_sel", "Fonction de lien",
              choices = fam_cfg$links,
              selected = fam_cfg$default_link)
})
```

- [ ] **Step 4: Commit**

```bash
git add app.R
git commit -m "feat: dynamic family/link selectors in sidebar"
```

---

### Task 3: Adaptive Simulation by Family

**Files:**
- Modify: `R/mod_simulation.R`

- [ ] **Step 1: Add null-coalescing operator and update `sim_server()` signature**

Add at top of `R/mod_simulation.R`:
```r
`%||%` <- function(a, b) if (!is.null(a)) a else b
```

Change `sim_server` to accept a `family` reactive:
```r
sim_server <- function(id, family) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    output$controls_ui <- renderUI({
      fam <- family()
      if (!isTRUE(input$expert_mode)) {
        base_inputs <- list(
          sliderInput(ns("beta1"), "Pente (β1)", -2, 2, 0.5, step = 0.1),
          numericInput(ns("n"), "Taille (n)", 100, min = 10, max = 2000),
          numericInput(ns("seed"), "Graine (Seed)", 123)
        )
        extra <- switch(fam,
          "gaussian" = list(sliderInput(ns("sigma"), "Bruit (σ)", 0.1, 5, 1, step = 0.1)),
          "Gamma"    = list(sliderInput(ns("shape"), "Forme (shape)", 0.5, 10, 2, step = 0.5)),
          list()
        )
        do.call(tagList, c(base_inputs, extra))
      } else {
        default_code <- switch(fam,
          "gaussian"  = "set.seed(seed)\nx <- rnorm(n)\ny <- 2 + beta1*x + rnorm(n, 0, sigma)\ndata.frame(x=x, y=y)",
          "binomial"  = "set.seed(seed)\nx <- rnorm(n)\np <- plogis(-1 + beta1*x)\ny <- rbinom(n, 1, p)\ndata.frame(x=x, y=y)",
          "poisson"   = "set.seed(seed)\nx <- rnorm(n)\nlambda <- exp(0.5 + beta1*x)\ny <- rpois(n, lambda)\ndata.frame(x=x, y=y)",
          "Gamma"     = "set.seed(seed)\nx <- rnorm(n)\nmu <- exp(1 + beta1*x)\nshape <- 2\ny <- rgamma(n, shape=shape, rate=shape/mu)\ndata.frame(x=x, y=y)"
        )
        aceEditor(ns("code"), value = default_code,
                  mode = "r", theme = "monokai", height = "200px")
      }
    })
    
    reactive_data <- reactive({
      fam <- family()
      if (!isTRUE(input$expert_mode)) {
        req(input$beta1, input$n, input$seed)
        n <- input$n; seed <- input$seed; beta1 <- input$beta1
        set.seed(seed)
        x <- rnorm(n)
        y <- switch(fam,
          "gaussian" = { req(input$sigma); 2 + beta1*x + rnorm(n, 0, input$sigma) },
          "binomial" = { p <- plogis(-1 + beta1*x); rbinom(n, 1, p) },
          "poisson"  = { lambda <- exp(0.5 + beta1*x); rpois(n, lambda) },
          "Gamma"    = { req(input$shape); mu <- exp(1 + beta1*x); rgamma(n, shape=input$shape, rate=input$shape/mu) }
        )
        data.frame(x = x, y = y)
      } else {
        req(input$code)
        env <- new.env()
        env$n <- input$n %||% 100; env$seed <- input$seed %||% 123
        env$beta1 <- input$beta1 %||% 0.5; env$sigma <- input$sigma %||% 1
        env$shape <- input$shape %||% 2
        tryCatch(
          eval(parse(text = input$code), envir = env),
          error = function(e) {
            showNotification(paste("Erreur code expert:", e$message), type = "error")
            NULL
          }
        )
      }
    })
    return(reactive_data)
  })
}
```

- [ ] **Step 2: Update the `sim_server()` call in `app.R`**

```r
# In server():
family_reactive <- reactive({
  req(input$family_sel)
  FAMILY_REGISTRY[[input$family_sel]]$family
})

sim_data <- sim_server("sim_mod", family = family_reactive)
```

- [ ] **Step 3: Commit**

```bash
git add R/mod_simulation.R app.R
git commit -m "feat: adaptive simulation by GLM family"
```

---

### Task 4: Unified Plotting (lm & glm)

**Files:**
- Modify: `app.R` (server section — all output renders)

- [ ] **Step 1: Add a `fitted_model` reactive (before output renders)**

```r
# In server(), BEFORE any output$... blocks:
fitted_model <- reactive({
  df  <- sim_data()
  req(df, input$link_sel, input$family_sel)
  fam <- FAMILY_REGISTRY[[input$family_sel]]$family
  lnk <- input$link_sel
  tryCatch(
    fit_model(df, fam, lnk),
    error = function(e) {
      showNotification(paste("Echec ajustement:", e$message), type = "error")
      NULL
    }
  )
})
```

- [ ] **Step 2: Replace `output$main_plot`**

```r
output$main_plot <- renderPlotly({
  df  <- sim_data()
  fit <- fitted_model()
  req(df, fit)
  df$fitted   <- fitted_response(fit)
  df$residual <- residuals(fit, type = "response")
  p <- ggplot(df, aes(x = x)) +
    geom_point(aes(y = y,
                   text = paste0("X: ", round(x, 2),
                                 "<br>Y: ", round(y, 3),
                                 "<br>Résidu: ", round(residual, 3))),
               color = "#3498db", alpha = 0.5) +
    geom_line(aes(y = fitted), color = "#e74c3c", linewidth = 1.2) +
    labs(title = input$family_sel,
         subtitle = paste("Link:", input$link_sel),
         x = "x", y = "y") +
    theme_minimal()
  ggplotly(p, tooltip = "text") |>
    layout(margin = list(l = 50, r = 50, b = 50, t = 60))
})
```

- [ ] **Step 3: Replace `output$diag_plot`**

```r
output$diag_plot <- renderPlot({
  fit <- fitted_model()
  req(fit)
  autoplot(fit, which = 1:4, ncol = 2, colour = "#2c3e50") +
    theme_bw() +
    theme(panel.grid.minor = element_blank())
})
```

- [ ] **Step 4: Replace `output$model_summary`**

```r
output$model_summary <- renderPrint({
  fit <- fitted_model()
  req(fit)
  summary(fit)
})
```

- [ ] **Step 5: Replace `output$download_data` to include fitted values**

```r
output$download_data <- downloadHandler(
  filename = function() paste0("data-", Sys.Date(), ".csv"),
  content = function(file) {
    df <- sim_data(); fit <- fitted_model(); req(df, fit)
    df$fitted   <- fitted_response(fit)
    df$residual <- residuals(fit, type = "response")
    write.csv(df, file, row.names = FALSE)
  }
)
```

- [ ] **Step 6: Commit**

```bash
git add app.R
git commit -m "feat: unified GLM/LM plotting with response-scale fitted values"
```

---

### Task 5: Final Verification

- [ ] **Step 1: Run app**

```
& "C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe" -e "shiny::runApp('.', port=3500, launch.browser=FALSE)"
```

- [ ] **Step 2: Checklist of all combinations to test**

| Family | Link | Expected behavior |
|--------|------|-------------------|
| Gaussien | identity | lm-style linear fit |
| Gaussien | log | curved fit (exp-like) |
| Binomial | logit | 0/1 data, sigmoid curve |
| Binomial | probit | 0/1 data, slightly diff curve |
| Binomial | cloglog | 0/1 data, asymmetric curve |
| Poisson | log | count data, exponential fit |
| Poisson | identity | count data, linear fit |
| Gamma | inverse | pos-real data |
| Gamma | log | pos-real data, exp fit |

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "feat: GLM multi-link complete — all families verified"
```
