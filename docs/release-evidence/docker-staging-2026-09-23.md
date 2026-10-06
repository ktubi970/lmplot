# Docker and staging ingress evidence — 2026-09-23

Commit inspected: `b5e9bdd99a6d313007d3d65e4133c13e497b4b8b` on `master`.
Scope: Docker/Compose configuration, local image health, and the external staging gate for `0.10.0-beta.1`. This note is evidence, not a deployment approval.

## Local configuration and tests

- Docker Desktop Linux engine `29.6.2`; Compose `v5.3.1`; Rscript `4.6.0` found at their installed absolute paths. They were not on the shell `PATH`.
- `docker compose config --quiet`: exit 0. Resolved config has one `lmplot` service, `linux/amd64`, internal `lmplot_lmplot_internal` network, exposed container port `3838`, no published `ports`, `read_only: true`, five writable tmpfs mounts, dropped capabilities, no-new-privileges, and CPU/memory/PID limits. The image tag is `lmplot:0.10.0-beta.1`.
- `tests/test_deployment.R` and `tests/test_release.R`: exit 0 with R 4.6.0, `--vanilla`, and the explicit project library path `renv/library/windows/R-4.6/x86_64-w64-mingw32`. The runner warned that the installed `testthat` package was built under R 4.6.1. These are contract/source tests, not a substitute for the hosted full suite.
- `git diff --check`: exit 0 before this evidence file was added.
- The default sandboxed R startup could not create its AppData `renv` cache and reported missing packages. A privileged run of the standard `renv` check by the release owner found the project synchronized. The initial sandbox result is not evidence of lockfile drift.

## Local image and health

- A fresh `docker build --tag lmplot:0.10.0-beta.1-local-20260923 .` exited 0. Buildx history identifies VCS revision `b5e9bdd99a6d313007d3d65e4133c13e497b4b8b`, pinned base digest `sha256:95a0d826be0bfc9bd41300385b35cf0ec074fc6b82cfaa92fddd7c6f6f2fd0dd`, duration 20m39s, and 18/18 completed steps. System dependency layers (#6/#7) and WORKDIR (#8) were cached; the renv restoration was re-executed. Its [raw initial build log](docker-build-fresh-2026-09-23.log) shows `renv::restore` downloading 113 locked packages, installing all 113 in 1100 seconds, and final image export. `renv` warned that `chromium` and `cmake` system packages were absent, but did not fail the restore. A second build with the same tag, `--progress=plain`, exited 0 using cache and produced a separate [cached replay log](docker-build-2026-09-23.log). The first build's image ID was `sha256:83a65ae2dba0739328f47ac0022f88116e06d51d7541e7331c2a54c5cc7c919c`; the cached replay changed only the exported manifest/attestation identity, and the tag now resolves to `sha256:f26f975b23284a84d1647f645a45acab6c5151ee6ef6564bc670419590db8378`. Both exports report the same image config digest `sha256:cb5aa645b78e3b0b491836984e74cd346405aa15eebe73d2a1fba7b9f06aaef7`.
- `docker image inspect` on the first image: `linux/amd64`, configured user `shiny`, healthcheck `wget ... http://127.0.0.1:3838/`, interval 10s, timeout 65s, start period 90s, three retries.
- Started dedicated container `lmplot-release-health-20260923` (container ID `9a09dc491ee0a487bf179c431815d086df566e1b18413ee1bec846d441c674be`) from the first build's image index `sha256:83a65ae2dba0739328f47ac0022f88116e06d51d7541e7331c2a54c5cc7c919c` (image config `sha256:cb5aa645b78e3b0b491836984e74cd346405aa15eebe73d2a1fba7b9f06aaef7`) with `--network none`, read-only root, five specified tmpfs mounts, dropped capabilities, no-new-privileges, 2 CPUs, 1 GiB memory, 512 MiB reservation, and 256 PID limit. `docker inspect .Image` on that container returned the same first image index. The health poll reached `running=true|healthy` on attempt 3. Captured [raw health state](docker-health-2026-09-23.json): five recorded checks exited 0, failing streak 0.
- `docker exec ... wget --output-document=- http://127.0.0.1:3838/`: exit 0; 23,836 UTF-8 bytes; contains `LM Plot Explorer` and `0.10.0-beta.1`. Effective UID was 997. Container inspection returned `network=none`, `read_only=true`, `user=shiny`; its environment did not contain `LMPLOT_TRUSTED_LOCAL`. The [container log](docker-health-2026-09-23.log) showed Shiny Server listening on 3838 with no worker error during the probe.
- Resources created: two local image exports/build cache and the named health container. The named container was removed with `docker rm -f lmplot-release-health-20260923` after evidence capture (exit 0); `docker ps -a --filter 'name=^/lmplot-release-health-20260923$'` then returned no rows. The image tag/cache remain for local review. No new Docker network was created. Existing stopped `lmplot-task8-*` containers and its internal network predated this check and were left untouched.

The image healthcheck probes `http://127.0.0.1:3838/` **inside the container**. Even a passing result proves only offline application startup and root content; it cannot prove public ingress, TLS, or a Shiny WebSocket session.

## External staging gate

The delivery files contain no current staging URL, ingress/reverse-proxy configuration, published host port, deployment manifest, or deployed image digest. `README.md` and `CHANGELOG.md` explicitly assign the ingress and staging smoke to the deployment owner outside this repository. The old Render URL in a historical Streamlit plan uses the retired `/_stcore/health` endpoint and is not a valid Shiny staging target. Local Docker inventory lists only stopped prior test containers and no identified ingress service. Environment variable **names** contain no staging/ingress locator.

The release gate therefore remains open. The deployment owner must supply access to the real HTTPS staging URL and its proxy/deployment configuration, the image digest built from the tested commit, and the prior reviewed image/configuration for rollback. Through that ingress, record TLS and root response, a successful Shiny WebSocket session, absence of public Expert mode, bundled-example and simulation analyses, chart text/table alternatives and download, error recovery, and operation without application egress. An HTTP 200 from localhost or the container healthcheck is insufficient.

## Reprise commands

From the repository root on a Docker host, use the full path to `docker.exe` here or `docker` if it is in `PATH`:

```powershell
$docker = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
& $docker compose config --quiet
& $docker build --tag lmplot:0.10.0-beta.1-local-20260923 .
& $docker image inspect lmplot:0.10.0-beta.1-local-20260923 --format '{{.Id}}'
```

The isolated local health smoke was run with these commands (the health poll, root fetch, UID and log reads followed the `run`):

```powershell
& $docker run -d --name lmplot-release-health-20260923 --network none --read-only `
  --tmpfs /tmp:mode=1777 `
  --tmpfs /var/log/shiny-server:uid=997,gid=997,mode=0770 `
  --tmpfs /var/lib/shiny-server:uid=997,gid=997,mode=0770 `
  --tmpfs /var/run/shiny-server:uid=997,gid=997,mode=0770 `
  --tmpfs /var/shiny-server/sockets:uid=997,gid=997,mode=0770 `
  --security-opt no-new-privileges:true --cap-drop ALL `
  --cpus 2 --memory 1g --memory-reservation 512m --pids-limit 256 `
  lmplot:0.10.0-beta.1-local-20260923
& $docker inspect lmplot-release-health-20260923 --format '{{.State.Running}}|{{.State.Health.Status}}'
& $docker exec lmplot-release-health-20260923 wget --quiet --tries=1 --timeout=60 --output-document=- http://127.0.0.1:3838/
& $docker exec lmplot-release-health-20260923 id -u
& $docker logs lmplot-release-health-20260923
```

That container was started **before** the cached replay changed the tag's manifest ID, and its inspected image reference above identifies exactly what was smoke-tested. Use a new name for any repeat. Remove only the dedicated test container after collecting evidence. Do not treat this as the ingress check.

For staging, obtain the actual deployment-owned URL and config, then fetch its HTTPS root and test the interactive workflow in a browser **through that URL**. Record the tested commit, image digest, ingress URL, screenshots/network evidence of WebSocket operation and the application checks above, and the rollback digest/configuration. No staging deployment or public request was performed in this check.

