source("R/model_registry.R")
source("R/mod_model.R")
source("R/mod_simulation.R")
source("R/mod_visualization.R")
source("R/mod_examples.R")

for (id in example_ids()) {
  example <- load_real_example(id)
  fit <- fit_model(example$analysis, example$metadata$model_type,
                   example$metadata$default_link)
  export_real_example_png(
    example, fit,
    file.path("artifacts", "real-examples", paste0(id, ".png"))
  )
}
