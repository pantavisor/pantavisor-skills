# The Pantahub MCP server

Endpoint: `<api>/mcp`, one server per Hub: `https://api.pantahub.com/mcp`
(production) and `https://api.stage.pantahub.com/mcp` (stage). A user with
both adds both, under different names (`pantahub`, `pantahub-stage`), and
you use the one for the Hub of the task. Clients sign in with OAuth: the
user approves access in the browser, no token is ever copied by hand.

## Adding it to a client

Give the user the line for their client; adding a server and signing in
are theirs to do.

For stage, name it `pantahub-stage` instead of `pantahub`.

| Client | Add | Sign in |
| --- | --- | --- |
| claude.ai | Settings → Connectors → Add custom connector, `<api>/mcp` | the connector's Connect button |
| Claude Code | `claude mcp add --transport http pantahub <api>/mcp` | `/mcp`, then pick pantahub |
| Codex | `codex mcp add pantahub --url <api>/mcp` | `codex mcp login pantahub` |
| OpenCode | `opencode mcp add --global --url <api>/mcp pantahub` | `opencode mcp auth pantahub` |
| Antigravity | `agy mcp add pantahub <api>/mcp` (flags go before the name) | when agy first uses it |

Restart the client's session if the tools don't show up after adding it.
Never set an `Authorization` header with a personal token instead of
signing in: that writes a credential into the client's config.

## Access

All calls act on the account that approved the connection. Tools that
change something ask the user before each call. A first connection is
read-only; builds need the **builds** grant and deploys **trails.write**.
If a tool refuses with "access … does not cover …", ask the user to approve
that access in their client (claude.ai: the connector's page; CLI clients:
sign in again), then retry.

## Read first

`get_build_guide` (topics: overview, repository, pvpkg, yocto, buildroot,
secrets, oem, image, deploy, troubleshooting) answers how-to questions from
the Hub itself; read the relevant topic before advising on a repository or a
failure. `list_secrets` and `list_signing_identities` show names only.

## Build

1. `start_build` with `project`, `mode` (`git` or `docker`, `image` for
   images), `git_url` + `git_ref` (or `image` pinned by digest), `platform`
   (`linux/arm64`, or comma-separated for a pipeline), `limit_seconds`
   (raise it: 900-1800 for a Dockerfile, 3600-7200 for Yocto), optional
   `app`, `secret`, `signing_secret` (`<identity>-oem`), `oem`. Keep the
   returned build id.
2. `get_build` until `succeeded`, `failed`, `cancelled` or `timed_out`
   (check every minute or so, not in a tight loop); `get_build_logs` for the
   log, with `after_sequence` to read only new lines.
3. `cancel_build`, `retry_build` (same commit; a moved tag is refused),
   `list_builds`, `get_build_usage`.

## Deploy to a device

1. `list_devices` / `get_device_status` to find the device and confirm it
   is up to date and online.
2. `import_build_artifact` with the build id (and `platform` for one
   architecture of a pipeline) → an `upload_id`.
3. `get_revision_parts` to see what the device runs now.
4. `plan_revision` on the device with operations, in order:
   `{"op":"import_export","upload_id":…}` and, for a strict device, also
   `{"op":"remove_parts","parts":["pv-oem-developer-001"]}` when the export
   carries it. To replace an OEM part cleanly, remove it first
   (`remove_parts: ["<identity>"]`) then import. Show the user the plan's
   changes and warnings.
5. `commit_revision` with the `plan_id` and a message, once the user agrees.
6. `get_device_status` until the revision is `DONE`; on `WONTGO`/`ERROR`,
   `get_device_logs` filtered by that revision and level `ERROR`.

An export built elsewhere (CI artifact) comes in with
`import_export_from_url`, or `get_export_upload_link` for the user to upload
a file; then `get_export_upload` until it is received, and plan as above.

## Images

`start_build` with `mode: "image"` and `device_image` (`base` or `factory`,
`make_factory`, `identity`, `apps` = app build ids, `policies`,
`secureboot`, `pantahub_host`) plus `oem`; `get_build_artifact_link` gives a
download link for an `.img.xz` (share it only with whoever flashes). See
images.md.

## Not available here

Creating or changing secret values, rotating/revoking/retiring signing keys
(they need the user's password) and deleting things: send the user to the
web app (`<web>/settings/secrets`,
`/settings/signing`) or pvr.
