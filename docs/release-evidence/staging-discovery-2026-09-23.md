# GitHub staging discovery — 2026-09-23

Read-only check at 18:32 UTC against `https://github.com/ktubi970/lmplot`, with local `master` still at `b5e9bdd99a6d313007d3d65e4133c13e497b4b8b`. No deployment was initiated and no secret was queried.

| GitHub API query | Exit | Result |
|---|---:|---|
| `gh api repos/ktubi970/lmplot/environments --jq '{total_count, environments: [.environments[] | {name,html_url,created_at,updated_at}]}'` | 0 | `{"environments":[],"total_count":0}` |
| `gh api 'repos/ktubi970/lmplot/deployments?per_page=100' --jq '[.[] | {id,environment,sha,ref,created_at,updated_at,original_environment}]'` | 0 | `[]` |

There is no GitHub environment or deployment record visible for this repository, so there is no deployment ID on which to query statuses, no GitHub-recorded staging URL, and no deployed commit to compare with the release candidate. This does not rule out infrastructure managed outside GitHub. The external ingress/WebSocket staging gate remains open until the deployment owner supplies the actual staging URL and configuration, deployed image digest/commit, and access for a smoke through that URL. A local Docker healthcheck cannot close this gate.

Resume only after a deployment record exists: `gh api 'repos/ktubi970/lmplot/deployments?per_page=100'`, then `gh api repos/ktubi970/lmplot/deployments/<id>/statuses` for a relevant ID. Inspect the latest status's `environment_url`, `state`, `created_at`, and the deployment `sha`; test the real URL separately. Do not infer staging from an old historical Render link.

## Recheck — 2026-10-01

Read-only queries repeated at 13:33:49–50 UTC, local HEAD `42e70f36788bfaeac880251a29195de2713ceb4c`. Both commands exited 0: environments `total_count=0`, deployments `[]`. Timestamped evidence: [environments](staging-environments-2026-10-01.json), [deployments](staging-deployments-2026-10-01.json). This still does not exclude an externally managed staging. No HTTPS URL, deployed digest, access method or human result has been supplied. Access/operator information and human science/screen-reader reviewers were requested again during CI verification. No deployment was made.
