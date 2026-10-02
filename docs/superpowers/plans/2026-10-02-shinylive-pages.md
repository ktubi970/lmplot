# Shinylive and GitHub Pages deployment

> For implementer: use `superpowers:executing-plans` to execute this plan inline.

**Goal:** Export the public LM Plot Explorer application to a tested static site, then publish it on GitHub Pages within the user's authorized scope.

**Spec:** The user selected Shinylive + GitHub Pages and said "ok go". Preserve all seven model families, real examples, diagnostics, Model Brain and CSV downloads. Do not expose private project history or uncommitted changes.

**Architecture:** Stage an allowlisted public application, export it with the R Shinylive tool, and publish only generated static files. Keep native R services and the existing server deployment unchanged.

**Global constraints:** Original GitHub repository is private. Publication needs a concrete decision about a separate public export repository; never change original repository visibility. Work in the managed isolated checkout. Keep native dependencies separate from the export tool library. Never silently substitute a model when a WASM dependency is unavailable.

## Task 1: Safe, repeatable export

- [ ] Write behavior tests for the staging allowlist, complete runtime assets, rejected manifest traversal, and nonempty output protection; run them red.
- [ ] Implement staging and export entry points; run tests green.
- [ ] Install the export tool in a separate local library; inspect WASM package support and produce the static output.

**Interfaces:** `stage_shinylive_app(root, stage)` returns an app directory containing only runtime sources, stylesheet, prepared examples and their attribution. The exporter consumes that directory and writes a new destination directory.

**Verification:** `testthat::test_file("tests/test_shinylive.R")`; expected all tests pass. Actual `shinylive::export` must finish and include self-hosted WASM dependencies.

## Task 2: Browser compatibility and deployment recipe

- [ ] Serve the output locally and exercise startup, LM, GLM, GLMM, real examples, tabs and CSV download in Chromium.
- [ ] Fix observed compatibility defects with focused regression tests.
- [ ] Add reproducible build and GitHub Pages publication instructions, including the private repository constraint.
- [ ] Run the native R suite and export checks, preserve evidence.

**Verification:** Fresh native test suite and observed browser results. Document any unsupported behavior and stop publication if core models fail.

## Task 3: Review and publication

- [ ] Request one fresh review of the complete change; address important findings.
- [ ] Prepare a concrete separate export repository and request approval only if exposing new public content requires a user decision.
- [ ] Publish when authorized, verify the live URL, and report exact status and evidence.

**Review focus:** Unintended files or credentials in the static bundle; symlink/path traversal in staging; accidental native renv activation in WASM; offline-only dependencies; relative URL behavior under a GitHub Pages repository subpath; no silent fallback for GLMM; private source history; existing local changes preserved.
