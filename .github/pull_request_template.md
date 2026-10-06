## Description

Please provide a concise summary of the changes introduced in this pull request and the rationale behind them.

Fixes #(issue)

## Type of Change

- [ ] Bug fix (non-breaking change fixing unexpected behavior or calculation defect)
- [ ] New feature (non-breaking change adding supported models, datasets, or UI capabilities)
- [ ] Documentation update (improving guides, README, or scientific context)
- [ ] Refactoring (internal code quality or performance improvement without functional changes)
- [ ] CI / Build / Infrastructure update

## Architectural Conformance (`AGENTS.md`)

- [ ] Strategy pattern: Fits and diagnostics dispatch through registered strategies (`R/model_registry.R`, `R/model_diagnostics.R`).
- [ ] Pure R calculations remain outside reactive handlers and do not depend on Shiny UI state or JSON contracts.
- [ ] Error messages are sanitized and do not expose internal paths or stack traces.
- [ ] `LMPLOT_TRUSTED_LOCAL` security boundary is respected.

## Verification Evidence

- [ ] Run full test suite: `Rscript -e "testthat::test_dir('tests', reporter='summary')"`
  - Result: 0 failures, 0 errors, 0 skipped.
- [ ] Browser tests executed with real Chrome (`chromote` / `shinytest2`).
- [ ] Docker configuration verified: `docker compose config --quiet`
- [ ] Git diff clean of whitespace / line-ending issues: `git diff --check`
- [ ] Added or updated unit/integration tests for any changed contracts.

## Accessibility Review

- [ ] Keyboard navigation: All new interactive elements are reachable and operable via keyboard.
- [ ] Visible focus indicators preserved.
- [ ] Semantic structure (landmarks, headings, labels, ARIA attributes) maintained.
- [ ] Text summaries and table alternatives provided for new data visualizations.
