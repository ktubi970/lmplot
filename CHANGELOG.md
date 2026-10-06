# Changelog

All notable changes to LM Plot Explorer are recorded here.
Release versions follow semantic versioning; beta interfaces may still change.

## [0.10.0-beta.1] — Unreleased release candidate

This entry records the prepared beta. It is not a publication announcement.
Complete the release gates below before tagging or deploying publicly.

### Added

- Versioned `lmplot-analysis-request/1.0`, `lmplot-analysis-result/1.0`, and
  `lmplot-error/1.0` CLI contracts with stable exit codes 0/2/3/4, sanitized
  error JSON, explicit unavailable numeric values, and atomic output replacement.
- Validated `model-brain/1.0` decomposition, observation navigation without
  refitting, inverse-link views, coefficient views, and Gaussian random-effect
  conditional/population views.
- Deterministic Guided interpretation, family-specific metrics/diagnostics,
  and bundled-data provenance with checksums, source links, units, exclusions,
  and separate dataset licenses.
- Chart summaries, table/CSV alternatives, keyboard controls, semantic
  landmarks, labeled inputs, visible focus, non-colour status text, and local
  system fonts.
- Scientific, CLI, module, failure-recovery, accessibility, real-browser, and
  deployment contract tests. GitHub Actions checks Windows and Ubuntu with
  R 4.6.0, locked renv restoration, and real Chrome, then tests Docker health.
- MIT application license, copyright 2026 lmplot contributors. Bundled datasets
  keep their original licenses; see [data/real/NOTICE.md](data/real/NOTICE.md).

### Changed / breaking

- Model, source, link and simulation settings now trigger analysis automatically
  instead of requiring a Generate & fit button. Equivalent numeric input
  acknowledgements do not repeat a fit; failed updates retain the last result.
- Views put charts or data first, use compact metrics and consistent chart
  sections, and collapse supporting explanations. Model Brain aligns related
  plots and supports keyboard conditional/population selection with a native
  control.

- Shiny is the only supported application runtime, using port 3838. The former
  Streamlit/Python runtime and port 8501 entrypoints are removed.
- Public inputs are limited to bundled teaching examples and deterministic
  simulation. Uploads, arbitrary formulas, hosted code execution, random slopes,
  generalized mixed families, authentication, and multi-tenancy are not supplied.
- Model fitting uses named strategies for the 15 supported model/link pairs.
  Gaussian GLMM uses `lme4::lmer` with a random intercept; unsupported behavior
  has no silent fallback to LM or another mixed-model engine.
- Shared validated analysis services power both Shiny modules and the CLI.
  The last successful result survives analysis errors and can be replaced by
  a later successful request.

### Scientific notes

- AIC/BIC are relative comparison values for compatible fits on the same
  response and observations, not stand-alone model-quality judgments.
- P-values describe evidence conditional on model assumptions; diagnostic
  checks remain exploratory and family-specific. Algorithm convergence and
  absence of warnings do not establish scientific validity.
- Unsupported Gaussian GLMM coefficient confidence intervals and p-values,
  and unavailable GLMM response intervals, are explicitly marked unavailable.
- Observed outcomes are distinguished from predicted means/probabilities in
  chart and Model Brain copy. Known example units propagate through the
  analysis boundary; unknown units remain unspecified.
- Documented scientific copy review by a human or an explicitly identified
  agent remains a release gate.

### Security and deployment

- `LMPLOT_TRUSTED_LOCAL=1` enables local R-code evaluation only for trusted
  operators. UI and request/use-case validation both enforce the boundary.
  Never enable it on a public service; public Compose and Docker CI omit it.
- Runtime code never installs packages. Dependency restoration occurs during
  explicit bootstrap/build. Direct local Shiny and CLI startup fail closed
  when the project renv library is absent; the CLI keeps its exit-3 error JSON.
  User-facing errors are sanitized; technical server/CLI logs require
  operator-controlled access.
- The Windows launcher no longer installs renv or restores packages on each
  launch. It bypasses startup profiles, validates the explicitly restored
  standard Windows project library, and fails with bootstrap instructions when
  dependencies are missing or inconsistent.
- Linux/AMD64 image pins
  `rocker/shiny:4.6.0@sha256:95a0d826be0bfc9bd41300385b35cf0ec074fc6b82cfaa92fddd7c6f6f2fd0dd`,
  restores `renv.lock`, runs as non-root `shiny`, and checks the actual app
  root on port 3838.
- Compose uses a read-only root, five tmpfs paths, dropped capabilities,
  no-new-privileges, CPU/memory/process limits, and an internal-only network.
  It exposes 3838 internally and publishes no host port. `docker compose up`
  alone does not provide localhost:3838.
- A deployment-owned external ingress/reverse proxy outside this repository
  must join the app network and publish its listener. TLS, WebSocket proxying,
  rate limits, monitoring, and operational access controls belong to that
  deployment. Do not grant the application a normal outbound network merely
  to publish a host port.
- Docker CI checks startup under `--network none` with the same read-only,
  tmpfs, capability, and resource constraints and verifies LM Plot Explorer
  content. It does not certify the external ingress or WebSocket path.
- Rollback requires the previous reviewed image digest and matching deployment
  configuration, service recreation, and a repeated ingress/WebSocket smoke.

### Accessibility review checklist

Checked items describe automated/source evidence, not complete WCAG 2.2 AA
conformance. Manual assistive-technology and visual reviews remain open.

- [x] Automated semantic checks: landmarks, main content, English document
  language, skip link and target; browser skip-link keyboard activation.
- [x] Automated label/error/status checks, with polite observation announcements
  and alert markup for invalid inputs.
- [x] Real-browser keyboard path: configuration, analysis, tab navigation, and
  previous/next observation controls; selected control focus is retained.
- [x] Real-browser selected-control focus checks: solid outline at least 2px,
  visible in viewport, and target at least 24px high.
- [x] Automated contrast checks for declared text/status colours against white
  (4.5:1) and selected focus colour (3:1); statuses also have text.
- [x] Chart summaries with table/CSV alternatives; large-table preview wording
  and full CSV data; browser download checked against selected observation.
- [x] Source/browser checks for local fonts and assets with no remote font load.
- [ ] Manual screen-reader review of all workflows, names, status/error
  announcements, tables, chart alternatives, and reading order.
- [ ] Manual keyboard review of every interactive control and popup, focus
  visibility/occlusion, and error recovery.
- [ ] Manual visual review at zoom and narrow viewports, all contrast states,
  non-colour meaning, and chart/table readability.

### Release gates and evidence

- [ ] Hosted GitHub Actions matrix passes on Windows and Ubuntu with exact
  R 4.6.0, synchronized lockfile, required packages, real Chrome, and no skipped
  tests. Package build versions and warnings must be retained in the evidence.
- [ ] Hosted Docker build and constrained no-egress health job passes after both
  R matrix legs.
- [ ] Documented scientific copy review approves the public UI and
  documentation; the reviewer may be a human or an explicitly identified agent.
- [ ] Manual accessibility checklist above is completed with assistive-technology
  evidence; no conformance claim is made solely from automated checks.
- [ ] Deployment-owned staging proves ingress and WebSocket operation, public
  Expert absence, example/simulation analysis, chart alternatives, download,
  error recovery, and no runtime egress requirement.
- [ ] Release owner records tested commit/image digest, approval evidence, and
  rollback target before publication.

Scientific approval evidence records the reviewer's identity and type (human
or agent), review date, reviewed commit and scope, sources and checks, findings
and their severity, limitations, and an explicit approve/block decision.
Blocking findings must be resolved and verified before approval; non-blocking
findings require a recorded disposition. A separate human scientific sign-off
is not required. Passing automated tests alone does not constitute scientific
copy review. This policy does not waive actual manual accessibility checks or
external ingress/WebSocket staging evidence.
