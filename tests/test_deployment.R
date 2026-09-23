deployment_root <- normalizePath("..", winslash = "/", mustWork = TRUE)

deployment_lines <- function(path) {
  lines <- readLines(file.path(deployment_root, path), warn = FALSE)
  trimws(lines[!grepl("^\\s*(#|$)", lines)])
}

test_that("the shipped runtime contains only the maintained Shiny application", {
  retired <- c("streamlit_app.py", ".streamlit/config.toml", "requirements.txt", "packages.txt")
  expect_false(any(file.exists(file.path(deployment_root, retired))))
  runtime <- c("app.R", "scripts/run_analysis.R", list.files(
    file.path(deployment_root, "R"), pattern = "\\.R$", recursive = TRUE, full.names = TRUE))
  for (path in runtime) {
    if (!grepl("^([A-Za-z]:|/)", path)) path <- file.path(deployment_root, path)
    code <- paste(readLines(path, warn = FALSE), collapse = "\n")
    expect_no_match(code, "install\\.packages\\s*\\(", info = path)
    expect_no_match(code, "streamlit|8501|_stcore", ignore.case = TRUE, info = path)
  }
})

test_that("ignore configuration retires Python deployment exclusions", {
  obsolete <- c("__pycache__/", "*.pyc", "*.pyo", "*.py", ".streamlit/",
                "streamlit_app.py", "requirements.txt", "packages.txt")
  for (path in c(".dockerignore", ".renvignore")) {
    expect_identical(intersect(deployment_lines(path), obsolete), character(), info = path)
  }
})

test_that("the image builds locked dependencies and starts Shiny without privileged init", {
  lines <- deployment_lines("Dockerfile")
  expect_identical(lines[[1]], paste0("FROM rocker/shiny:4.6.0@sha256:",
    "95a0d826be0bfc9bd41300385b35cf0ec074fc6b82cfaa92fddd7c6f6f2fd0dd"))
  text <- paste(lines, collapse = "\n")
  expect_true("USER shiny" %in% lines)
  expect_true("EXPOSE 3838" %in% lines)
  expect_match(text, "renv::restore(prompt = FALSE", fixed = TRUE)
  expect_match(text, "WORKDIR /srv/shiny-server/lmplot", fixed = TRUE)
  expect_match(text, "app_dir /srv/shiny-server/lmplot;", fixed = TRUE)
  expect_match(text, "http://127.0.0.1:3838/", fixed = TRUE)
  expect_match(text, "HEALTHCHECK --interval=10s --timeout=65s --start-period=90s --retries=3", fixed = TRUE)
  expect_match(text, "wget --quiet --tries=1 --timeout=60", fixed = TRUE)
  expect_match(text, "CMD [\"/usr/bin/shiny-server\"]", fixed = TRUE)
  expect_no_match(text, "LMPLOT_TRUSTED_LOCAL|8501|streamlit|\\bpip\\b|/init")
  copies <- grep("^COPY ", lines, value = TRUE)
  expect_setequal(copies, c("COPY renv.lock .Rprofile ./", "COPY renv/activate.R ./renv/activate.R",
    "COPY app.R ./", "COPY R/ ./R/", "COPY data/real/ ./data/real/",
    "COPY www/style.css ./www/style.css"))
  ignored <- deployment_lines(".dockerignore")
  expect_false(any(c("renv", "renv/", "renv/activate.R") %in% ignored))
  expect_true(all(c("renv/library/", "renv/staging/", ".env", "www/.env") %in% ignored))
})

test_that("Compose bounds an immutable non-root service on an internal network", {
  config <- yaml::read_yaml(file.path(deployment_root, "docker-compose.yml"))
  expect_null(config$version)
  expect_identical(names(config$services), "lmplot")
  service <- config$services[[1]]
  expect_identical(service$platform, "linux/amd64")
  expect_null(service$ports)
  expect_true("3838" %in% service$expose)
  expect_true(service$read_only)
  expect_null(service$container_name)
  expect_null(service$healthcheck)
  expect_false("LMPLOT_TRUSTED_LOCAL" %in% names(service$environment))
  expect_true("no-new-privileges:true" %in% service$security_opt)
  expect_true("ALL" %in% service$cap_drop)
  expect_true(is.numeric(service$pids_limit) && service$pids_limit > 0)
  expect_true(all(c("cpus", "memory") %in% names(service$deploy$resources$limits)))
  expect_true("/tmp:mode=1777" %in% service$tmpfs)
  for (path in c("/var/log/shiny-server", "/var/lib/shiny-server", "/var/run/shiny-server",
                 "/var/shiny-server/sockets")) {
    expect_true(paste0(path, ":uid=997,gid=997,mode=0770") %in% service$tmpfs, info = path)
  }
  expect_true(length(service$networks) > 0)
  for (network in service$networks) expect_true(config$networks[[network]]$internal)
})
