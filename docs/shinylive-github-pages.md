# Shinylive demo on GitHub Pages

LM Plot Explorer can run in the visitor's browser using WebAssembly R. GitHub Pages serves the exported files; there is no hosted Shiny R process or server account for each visitor.

The static demo contains the public application source, stylesheet, prepared scientific examples and their attribution. Anyone with access to the site can download those sources. The original repository history, raw source archives, local configuration and developer documents are excluded. Keep `LMPLOT_TRUSTED_LOCAL` unset for public use.

## Build

The native project must already have its locked dependencies restored with `Rscript --vanilla scripts/bootstrap.R`. The export tool is separate from `renv.lock`: use Shinylive **0.5.0** and assets **0.10.12**. WASM package versions can differ from native versions; browser validation is required for each rebuild.

From an R session in the project:

```r
dir.create(".superpowers/shinylive-tools", recursive = TRUE, showWarnings = FALSE)
build_lib <- normalizePath(".superpowers/shinylive-tools")
install.packages("remotes", lib = build_lib, repos = "https://cloud.r-project.org")
.libPaths(c(build_lib, .libPaths()))
remotes::install_version("shinylive", version = "0.5.0", lib = build_lib,
                         repos = "https://cloud.r-project.org", upgrade = "never")
callr::rscript("scripts/export_shinylive.R", cmdargs = "--vanilla",
               args = ".superpowers/shinylive-site", libpath = .libPaths(), show = TRUE)
```

The destination must be empty or absent. The exporter refuses to overwrite an existing site. It stages only the reviewed runtime file list from `scripts/shinylive_bundle.R`, so a new application module or asset needs an explicit update there.

The manual **Build Shinylive demo** workflow builds a downloadable artifact from the private repository. It does not publish or change repository visibility. Restore the native runtime only in the build job; no native `.Rprofile` or `renv` library enters the browser bundle.

## Preview and acceptance

Serve the directory using `httpuv::runStaticServer(".superpowers/shinylive-site")`. Opening `index.html` as a local file is insufficient: WebAssembly and service workers require HTTP on localhost or HTTPS.

Check the actual exported application in Chromium, including a repository-style URL subpath:

1. Generate a simulated LM and inspect metrics and the main Plotly chart.
2. Inspect Diagnostics and Model Brain; change the selected observation.
3. Generate each GLM family and a Gaussian GLMM; verify fit status and model labels.
4. Load the prepared real examples, especially the 65-school mixed model.
5. Download the enriched CSV from Data & provenance and verify its rows and fitted/residual columns.
6. Reload the site and check that runtime files and packages load successfully.

The site bundles WASM dependencies. The first visit downloads R and application packages and can take tens of seconds or longer on a slow connection. The complete artifact is around 133 MB in the initial build; not all of it is required for every page. A browser with JavaScript, WebAssembly and service-worker support is needed. The offline helper that creates static PNGs through Chrome remains a native build tool, not a browser feature.

Shinylive downloads use Shiny's normal response headers for the filename. In WASM only, `R/browser_compatibility.R` removes the HTML `download` attribute from Shiny links, following the [official Chromium service-worker workaround](https://shiny.posit.co/r/components/inputs/download-button/). It also keeps downloads in the application frame rather than opening a new tab. Native Shiny links are unchanged.

## Publish only the export

For free GitHub Pages hosting, use a separate **public** repository such as `lmplot-demo`, keeping the original source repository private. Public hosting exposes the application source included in `app.json`; obtain an explicit decision before creating that public copy when the source project is private.

Place the generated site at the root of the deployment repository with `.nojekyll`. Configure **Settings → Pages → Deploy from a branch → main / root**. The `.nojekyll` file prevents Jekyll from altering static package paths. The expected URL is `https://<owner>.github.io/lmplot-demo/`.

For subsequent deployments, rebuild, validate, and replace only this repository's generated site. Do not copy the entire private source checkout or push its history into the demo repository. GitHub's published-site limits apply; the initial artifact is below the 1 GB site limit and each file is below GitHub's 100 MiB Git file limit.

References: [Shinylive for R](https://posit-dev.github.io/r-shinylive/), [export arguments](https://posit-dev.github.io/r-shinylive/reference/export.html), [GitHub Pages availability](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages), [GitHub Pages limits](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits).
