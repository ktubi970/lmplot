read_example_manifest <- function(root = ".") {
  manifest <- utils::read.csv(file.path(root, "data", "real", "manifest.csv"),
                              stringsAsFactors = FALSE, check.names = FALSE)
  manifest$expected_rows <- as.integer(manifest$expected_rows)
  manifest
}

example_ids <- function(root = ".") read_example_manifest(root)$example_id

example_config <- function(example_id, root = ".") {
  manifest <- read_example_manifest(root)
  match <- manifest[manifest$example_id == example_id, , drop = FALSE]
  if (nrow(match) != 1L) stop("Unknown real-data example: ", example_id,
                              call. = FALSE)
  as.list(match[1L, , drop = FALSE])
}

example_for_model <- function(model_type, root = ".") {
  manifest <- read_example_manifest(root)
  match <- manifest$example_id[manifest$model_type == model_type]
  if (length(match) != 1L) stop("No unique real-data example for model: ",
                                model_type, call. = FALSE)
  match[[1L]]
}

assert_source <- function(data, rows, columns, name) {
  if (!is.data.frame(data) || nrow(data) != rows ||
      !all(columns %in% names(data))) {
    stop("Unexpected ", name, " source schema", call. = FALSE)
  }
  invisible(data)
}

example_sha256_file <- function(path) {
  paste(as.character(digest::digest(path, algo = "sha256", file = TRUE)),
        collapse = "")
}

verify_real_example_sources <- function(root = ".") {
  manifest <- read_example_manifest(root)
  specs <- unique(manifest[c("source_file", "source_sha256")])
  paths <- file.path(root, "data", "real", "sources", specs$source_file)
  actual <- vapply(paths, function(path) {
    if (!file.exists(path)) return("<missing>")
    example_sha256_file(path)
  }, character(1))
  matches <- actual != "<missing>" &
    tolower(actual) == tolower(specs$source_sha256)
  if (!all(matches)) {
    row <- which(!matches)[[1L]]
    stop(
      "SHA-256 mismatch for ", specs$source_file[[row]], ": expected ",
      specs$source_sha256[[row]], ", actual ", actual[[row]],
      call. = FALSE
    )
  }
  invisible(specs$source_file)
}

canonical_columns <- function(model_type) {
  config <- model_config(model_type)
  c("X", if (config$dimensions == 3L) "Y", "Z",
    if (config$requires_group) "Group")
}

prepare_adelie_lm_2d <- function(path) {
  source <- utils::read.csv(path, check.names = FALSE, na.strings = "",
                            stringsAsFactors = FALSE)
  assert_source(source, 152L, c("Sample Number", "Flipper Length (mm)",
                                "Body Mass (g)"), "Adélie")
  keep <- is.finite(source[["Flipper Length (mm)"]]) &
    is.finite(source[["Body Mass (g)"]])
  out <- source[keep, c("Sample Number", "Flipper Length (mm)",
                        "Body Mass (g)"), drop = FALSE]
  out$X <- out[["Flipper Length (mm)"]]
  out$Z <- out[["Body Mass (g)"]]
  stopifnot(nrow(out) == 151L)
  out
}

prepare_adelie_binomial <- function(path) {
  source <- utils::read.csv(path, check.names = FALSE, na.strings = "",
                            stringsAsFactors = FALSE)
  assert_source(source, 152L, c("Sample Number", "Culmen Length (mm)",
                                "Body Mass (g)", "Sex"), "Adélie")
  keep <- is.finite(source[["Culmen Length (mm)"]]) &
    is.finite(source[["Body Mass (g)"]]) & source$Sex %in% c("FEMALE", "MALE")
  out <- source[keep, c("Sample Number", "Culmen Length (mm)",
                        "Body Mass (g)", "Sex"), drop = FALSE]
  out <- out[order(as.numeric(out[["Sample Number"]])), , drop = FALSE]
  out$X <- out[["Culmen Length (mm)"]]
  out$Y <- out[["Body Mass (g)"]]
  out$Z <- as.integer(out$Sex == "FEMALE")
  counts <- table(out$Z)
  stopifnot(
    nrow(out) == 146L,
    identical(as.integer(counts), c(73L, 73L)),
    identical(names(counts), c("0", "1"))
  )
  out
}

prepare_concrete_28d <- function(path) {
  extract <- tempfile("concrete-")
  dir.create(extract)
  on.exit(unlink(extract, recursive = TRUE), add = TRUE)
  utils::unzip(path, files = "Concrete_Data.xls", exdir = extract)
  workbook <- file.path(extract, "Concrete_Data.xls")
  if (!identical(example_sha256_file(workbook),
                 "710076c66b9ca3f8050e7942f3dcbdbe04013534daeb0077ffd3079a52d8e0c4")) {
    stop("Unexpected Concrete_Data.xls checksum", call. = FALSE)
  }
  source <- as.data.frame(readxl::read_excel(
    workbook, .name_repair = "minimal"
  ), check.names = FALSE)
  if (nrow(source) != 1030L || ncol(source) != 9L) {
    stop("Unexpected concrete source schema", call. = FALSE)
  }
  source <- source[source[[8L]] == 28, , drop = FALSE]
  out <- data.frame(
    source_row = as.integer(rownames(source)), cement_kg_m3 = source[[1L]],
    water_kg_m3 = source[[4L]], strength_mpa = source[[9L]],
    X = source[[1L]], Y = source[[4L]], Z = source[[9L]],
    check.names = FALSE
  )
  stopifnot(nrow(out) == 425L, all(is.finite(as.matrix(out[c("X", "Y", "Z")]))))
  out
}

prepare_abalone_poisson <- function(path) {
  names <- c("Sex", "Length", "Diameter", "Height", "Whole_weight",
             "Shucked_weight", "Viscera_weight", "Shell_weight", "Rings")
  source <- utils::read.csv(path, header = FALSE, col.names = names,
                            stringsAsFactors = FALSE)
  assert_source(source, 4177L, names, "abalone")
  out <- data.frame(
    source_row = seq_len(nrow(source)), length_mm = 200 * source$Length,
    shell_weight_g = 200 * source$Shell_weight, rings = source$Rings,
    X = 200 * source$Length, Y = 200 * source$Shell_weight, Z = source$Rings
  )
  stopifnot(all(out$Z == floor(out$Z)), all(out$Z >= 0))
  out
}

prepare_forest_fire_gamma <- function(path) {
  source <- utils::read.csv(path, stringsAsFactors = FALSE)
  assert_source(source, 517L, c("temp", "RH", "area"), "forest fire")
  source <- source[source$area > 0, , drop = FALSE]
  out <- data.frame(
    source_row = as.integer(rownames(source)), temp_c = source$temp,
    rh_pct = source$RH, area_ha = source$area,
    X = source$temp, Y = source$RH, Z = source$area
  )
  stopifnot(nrow(out) == 270L, all(out$Z > 0))
  out
}

prepare_inner_london_glmm <- function(path) {
  extract <- tempfile("mlmRev-")
  dir.create(extract)
  on.exit(unlink(extract, recursive = TRUE), add = TRUE)
  utils::untar(path, files = "mlmRev/data/Exam.rda", exdir = extract)
  exam_path <- file.path(extract, "mlmRev", "data", "Exam.rda")
  if (!identical(example_sha256_file(exam_path),
                 "2b373e72be15b68bafd7ba8515e408b75404a61db44a5d5b4b3474b3b11e01e9")) {
    stop("Unexpected Exam.rda checksum", call. = FALSE)
  }
  environment <- new.env(parent = emptyenv())
  load(exam_path, envir = environment)
  source <- get("Exam", envir = environment)
  expected <- c("school", "normexam", "schgend", "schavg", "vr", "intake",
                "standLRT", "sex", "type", "student")
  assert_source(source, 4059L, expected, "mlmRev Exam")
  group <- factor(as.character(source$school),
                  levels = as.character(sort(as.numeric(levels(source$school)))))
  out <- data.frame(
    source_row = seq_len(nrow(source)), standLRT = source$standLRT,
    schavg = source$schavg, normexam = source$normexam,
    school = as.character(source$school), X = source$standLRT,
    Y = source$schavg, Z = source$normexam, Group = group
  )
  stopifnot(nrow(out) == 4059L, nlevels(out$Group) == 65L)
  out
}

build_real_examples <- function(root = ".") {
  verify_real_example_sources(root)
  sources <- file.path(root, "data", "real", "sources")
  builders <- list(
    adelie_flipper_mass = function() prepare_adelie_lm_2d(file.path(sources, "adelie.csv")),
    concrete_28d = function() prepare_concrete_28d(file.path(sources, "concrete-compressive-strength.zip")),
    adelie_sex = function() prepare_adelie_binomial(file.path(sources, "adelie.csv")),
    abalone_rings = function() prepare_abalone_poisson(file.path(sources, "abalone.data")),
    forest_fire_positive_area = function() prepare_forest_fire_gamma(file.path(sources, "forestfires.csv")),
    inner_london_exam = function() prepare_inner_london_glmm(file.path(sources, "mlmRev_1.0-8.tar.gz"))
  )
  for (id in names(builders)) {
    data <- builders[[id]]()
    config <- example_config(id, root)
    analysis <- data[canonical_columns(config$model_type)]
    if ("Group" %in% names(analysis)) analysis$Group <- factor(analysis$Group)
    validate_simulation_data(analysis, config$model_type)
    stopifnot(nrow(data) == config$expected_rows)
    output <- file.path(root, "data", "real", id)
    dir.create(output, recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(data, file.path(output, "model-data.csv"), row.names = FALSE)
  }
  invisible(names(builders))
}

load_real_example <- function(example_id, root = ".") {
  config <- example_config(example_id, root)
  path <- file.path(root, "data", "real", example_id, "model-data.csv")
  data <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  analysis <- data[canonical_columns(config$model_type)]
  if ("Group" %in% names(analysis)) analysis$Group <- factor(analysis$Group)
  validate_simulation_data(analysis, config$model_type)
  if (nrow(data) != config$expected_rows) stop("Unexpected prepared row count", call. = FALSE)
  list(
    id = example_id,
    analysis = analysis,
    display = data[, setdiff(names(data), c("X", "Y", "Z", "Group")), drop = FALSE],
    metadata = config
  )
}

enrich_real_example <- function(example, fit) {
  enriched <- example$display
  enriched$.fitted <- fitted_response(fit)
  enriched$.residual <- response_residuals(fit)
  enriched
}

example_plot <- function(example, fit, show_surface = TRUE) {
  metadata <- example$metadata
  config <- model_config(metadata$model_type)
  labels <- list(
    x = metadata$predictor_x_label,
    z = metadata$response_label
  )
  if (config$dimensions == 3L) {
    labels$y <- metadata$predictor_y_label
  }
  if (config$requires_group) {
    labels$group <- tools::toTitleCase(
      gsub("_", " ", metadata$group_source, fixed = TRUE)
    )
  }
  plot <- build_main_plot(
    example$analysis,
    fit,
    metadata$model_type,
    show_surface = show_surface,
    labels = labels
  )
  citation <- if (nzchar(metadata$publication_doi)) {
    paste0("Publication DOI: ", metadata$publication_doi)
  } else {
    paste0("Publication: ", metadata$publication_url)
  }
  title <- paste0(
    metadata$title,
    "<br><sup>",
    config$label,
    " | ",
    citation,
    "</sup>"
  )
  if (config$dimensions == 2L) {
    plotly::layout(
      plot,
      title = list(text = title),
      xaxis = list(title = metadata$predictor_x_label),
      yaxis = list(title = metadata$response_label)
    )
  } else {
    plotly::layout(
      plot,
      title = list(text = title),
      showlegend = metadata$model_type != "glmm",
      scene = list(
        xaxis = list(title = metadata$predictor_x_label),
        yaxis = list(title = metadata$predictor_y_label),
        zaxis = list(title = metadata$response_label)
      )
    )
  }
}

export_real_example_png <- function(example, fit, file, width = 1200L,
                                    height = 800L) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  html <- tempfile(fileext = ".html")
  on.exit(unlink(html), add = TRUE)
  htmlwidgets::saveWidget(example_plot(example, fit), html,
                          selfcontained = TRUE)
  webshot2::webshot(html, file = file, vwidth = width, vheight = height,
                    delay = 0.5)
  if (!file.exists(file) || file.info(file)$size == 0) {
    stop("Static plot export failed: ", file, call. = FALSE)
  }
  invisible(file)
}
