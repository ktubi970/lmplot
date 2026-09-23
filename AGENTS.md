## Skill routing

For every user prompt:

1. Review the names and descriptions of all available skills.
2. Select every skill that genuinely matches the request, using the smallest sufficient set.
3. Read each selected `SKILL.md` completely before responding or taking action.
4. Follow the selected skills faithfully and in their required order.
5. Always use a skill explicitly named by the user.
6. Repeat this check for every new prompt; do not assume that a skill selected for a previous prompt still applies.
7. If no skill applies, continue normally.

<!-- PATTERN-DESIGN-START -->
## Architecture & Design Patterns

LM Plot Explorer is a modular Shiny monolith. Pure R services own scientific
calculation; Shiny modules own workflow presentation; `app.R` is only the
composition root. Keep changes KISS/YAGNI: introduce a pattern only where
the stated evidence requires it.

### Enforceable rules

1. **Strategy — only for fitted-model and diagnostics dispatch.**
   `FIT_STRATEGIES` in `R/model_registry.R` selects LM, GLM, and Gaussian-GLMM
   fitting; `DIAGNOSTIC_STRATEGIES` in `R/model_diagnostics.R` selects LM,
   binomial, count/Gamma, and GLMM checks. A new supported fit or diagnostic
   family must add a named registry entry and behavior tests proving it
   resolves, validates model/link compatibility, and does not silently fall
   back to another model family. Do not create a Strategy class/registry for
   ordinary branches, exports, UI choices, or a one-off calculation.

2. **Dependency injection — at the analysis boundary.**
   `create_analysis_services()` supplies the collaborators used by
   `run_analysis_usecase()` in `R/mod_pipeline.R`. Tests must be able to
   substitute calculation/service dependencies and prove request validation,
   trusted-local enforcement, error recovery, and no-refit Model Brain
   selection without Shiny globals. Do not introduce a general-purpose
   container or pass dependencies through unrelated views.

3. **Adapters — only at real external boundaries.**
   The JSON CLI contract (`R/json_contract.R`, `scripts/run_analysis.R`) and
   Plotly/Shiny rendering boundary may adapt external APIs. Core
   model/metric/diagnostic functions exchange R values and must not depend on
   CLI JSON or UI objects. New adapters require a contract test for stable
   schema/output or rendering data; do not wrap an R package merely because
   it is third-party.

4. **Shiny modules — one per user workflow.**
   Configuration, Overview, Diagnostics, Model Brain, and Data & provenance
   have namespaced UI/server modules. Modules receive validated reactives or
   result contracts, never another module's raw input IDs. Pure calculations
   remain outside `reactive()`/`observeEvent()` handlers. Tests must exercise
   module isolation and the user workflow, including keyboard/browser behavior
   where applicable.

5. **Evidence before architectural claims.**
   Add/adjust behavior-oriented tests alongside a changed contract: dispatcher
   and fallback tests for model strategies; family diagnostics tests; request
   and service-injection tests; CLI schema/exit/JSON-sanitization tests;
   Model Brain validation/no-refit tests; Shiny module/accessibility/browser
   tests; or Docker/Compose structural and health tests. File length, a
   library's name, and the mere presence of a third-party dependency are not
   evidence of a God object, coupling, or an Adapter requirement.
<!-- PATTERN-DESIGN-END -->
