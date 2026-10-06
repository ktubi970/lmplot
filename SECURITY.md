# Security Policy

## Supported Versions

Security updates are provided for the following versions:

| Version | Supported | Notes |
|---|---|---|
| `0.10.0-beta.1` | :white_check_mark: | Current active release candidate |
| `< 0.10.0` | :x: | Older releases are retired |

---

## Security Architecture & Threat Model

LM Plot Explorer is designed for anonymous public exploration of statistical models with strict security boundaries:

1. **Untrusted / Public Deployments**:
   - The public UI and API accept only bounded, validated requests:
     - Pre-bundled, curated scientific datasets.
     - Deterministic simulations with strictly bounded parameter ranges ($N \in [10, 2000]$, grid points $\le 200$).
   - Uploading arbitrary datasets or executing custom R formulas is intentionally disabled.
   - User-facing error messages are sanitized (`options(shiny.sanitize.errors = TRUE)`); technical stack traces and internal file paths are kept private to stderr.

2. **Expert Mode & `LMPLOT_TRUSTED_LOCAL`**:
   - The application contains an optional "Expert" evaluation mode that evaluates R expressions.
   - This mode is **disabled by default** and activates **only** when `LMPLOT_TRUSTED_LOCAL=1` is explicitly set in the server environment.
   - **WARNING:** Expert mode is **NOT a sandbox**. It executes code with the privileges of the running process. It must **never** be enabled on publicly accessible servers or untrusted multi-user environments.
   - Docker Compose and CI configurations enforce that `LMPLOT_TRUSTED_LOCAL` is omitted.

3. **Container Isolation**:
   - Docker images run as the unprivileged `shiny` user (UID 997).
   - The root filesystem is mounted read-only (`read_only: true`).
   - All Linux capabilities are dropped (`cap_drop: ALL`).
   - Privilege escalation is forbidden (`no-new-privileges: true`).
   - Network egress is blocked or restricted to internal Docker bridge networks.

---

## Reporting a Vulnerability

If you discover a security vulnerability in LM Plot Explorer, please report it privately. **Do not open a public GitHub issue.**

### Reporting Process
1. Send an email to the maintainer at [krikor.tchepidjian@gmail.com](mailto:krikor.tchepidjian@gmail.com) with the subject line `[SECURITY] LM Plot Explorer Vulnerability`.
2. Please include:
   - A description of the vulnerability and its potential impact.
   - Step-by-step instructions or proof-of-concept code to reproduce the issue.
   - The affected version(s) and environment (OS, R version, browser).
   - Any suggested mitigations or fixes.

### Response Timelines
- **Initial acknowledgment:** Within 48 hours.
- **Triage and assessment:** Within 5 business days.
- **Patch and coordinated disclosure:** As quickly as practical, typically within 30 days.

We ask you to observe responsible disclosure guidelines and keep the issue confidential until an official patch has been published.
