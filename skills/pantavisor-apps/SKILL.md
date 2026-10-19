---
name: pantavisor-apps
description: Build and ship apps for embedded Linux devices running Pantavisor, using Pantacor Hub's remote builds - from an empty repository to a container on a device, or a flashable device image. Use this whenever the user wants to create, package, build, sign or deploy an app or container for Pantavisor or Pantacor Hub, write a Dockerfile or pvpkg.json (Dockerfile, Yocto/kas or Buildroot) for a device, build a flashable image (image base, factory, policies, OEM configuration, join tokens), set up signing identities or build secrets, or put a build on a device - with the pvr CLI when a shell is available, or with the Pantahub MCP server otherwise (Claude Code, claude.ai, Codex, OpenCode, Antigravity). Also use it when a Pantahub build fails or a device refuses or rolls back a revision after an update.
---

# Pantavisor apps with Pantacor Hub

A Pantavisor device runs a **state**: a BSP plus containers ("apps"), each
signed. Pantacor Hub builds an app from a Git repository or a registry image
into a signed **pvr export** (`<app>.pvrexport.tgz`), and puts exports on
devices as new **revisions**. It can also build **flashable images** for new
devices. Your job is to take the user from an idea to that app running on
their device.

## Which Hub

| Hub | API (`<api>`) | Web (`<web>`) |
| --- | --- | --- |
| production | `https://api.pantahub.com` | `https://hub.pantahub.com` |
| stage | `https://api.stage.pantahub.com` | `https://hub.stage.pantahub.com` |

The references write `<api>` and `<web>`; fill in the Hub in use. Pick it,
in this order:
1. the one the user names;
2. the one the tools already point at: `$PVR_BASEURL` or the host pvr is
   logged into (`~/.pvr/auth.json`), or the API of the connected MCP server
   (a server named like `pantahub-stage` is stage);
3. otherwise ask.

Keep to one Hub per task: devices, secrets, signing identities and builds of
one Hub don't exist on the other. If a builds call answers 404 or "not
enabled" on a Hub, builds aren't available there yet: say so, and offer
stage, where builds run as a development preview.

The user guide is at `<web>/docs/guide/builds` (pages `builds-repository`,
`builds-pvr`, `builds-secrets`, `builds-signing`, `builds-images`,
`builds-deploy`, `mcp`).

## Pick the path by what you can do, not by which assistant you are

- **You can run shell commands and `pvr` is installed** (`pvr --help` lists
  `build`): use pvr. It works on the user's local checkout, is logged in as
  the user, and needs no extra permissions. Read `references/pvr.md`. This
  is the usual case in Claude Code, Codex, OpenCode and Antigravity.
- **No shell, or no pvr**: use the Pantahub MCP server. Read
  `references/mcp.md`; its first section says how to add the server in each
  client if its tools (`list_devices`, `start_build`, …) aren't available
  yet. This is the usual case in claude.ai.
- **Neither**: tell the user to install pvr or add the MCP server, and stop.

The MCP server grants access in steps. When a tool answers that "the access
granted to this connection does not cover builds" (or trails, devices…),
the user must approve that access in their client (the connector's page in
claude.ai, or signing in again through the client's MCP login), then
retry. Don't look for a way around it.

If both are available, prefer pvr for building and either for deploying.

## The workflow

1. **Understand the target.** Which device and architecture (`arm64` for
   Raspberry Pi 4/5 and CM4/CM5 on 64-bit, `amd64` for PCs and VMs,
   `arm32v6`/`arm32v7` for older boards)? Is it a running, claimed device
   (deploy an app) or a new one (flashable image)? Does it verify signatures
   (`strict` images do)?
2. **Prepare the repository** (`references/repository.md`): a Dockerfile, or
   `pvpkg.json` for a packaged app or a Yocto/Buildroot rootfs. Commit and
   push it: the builder only sees what is pushed, at one commit.
3. **Secrets and signing**, only when needed:
   - private repository: a **git** secret covering its host/path;
   - release signing: a **signing identity**; build with its `<identity>-oem`
     key. Without one, exports are signed with pvr's public developer key,
     fine for development devices only;
   - device join tokens or other OEM values: **config** secrets.
   The user creates secrets and pastes values themselves (web UI → Secrets,
   or `pvr secret add`, which reads the value from stdin). **Never ask for,
   echo, store or pass a secret value** (tokens, passwords, keys) through
   chat, commands you write, files you create or tool inputs; refer to
   secrets only by name.
4. **Start the build**, follow it to `succeeded`, read the log if it fails
   (table below).
5. **Deploy**: merge the export into the device's next revision and post it
   (`references/pvr.md` or `references/mcp.md`). Then watch the revision go
   to `DONE`, or read the device logs if it goes `WONTGO`/`ERROR`.
6. **New devices**: build images (`references/images.md`).

Before anything that changes a device or posts a revision, show the user
what will change and get a yes: a device the user can't reach physically is
easy to break.

## Things that bite

- **Limit seconds.** pvr's default `--limit-seconds 60` is only for
  simulations. Dockerfiles: 900–1800. Yocto: 3600–7200 (minutes from the
  shared sstate cache, hours cold). Max 14400 for git, 3600 for registry.
- **Branches resolve at admission**: a build always uses one commit. A retry
  of a tag is refused if the tag moved.
- **Architectures**: `pvpkg.json`'s `arch` must include every platform
  requested. Use `FROM --platform=$BUILDPLATFORM` + `TARGETARCH` for cross
  builds, or multi-arch base images.
- **Strict devices refuse unsigned parts.** An export may carry an unsigned
  `pv-oem-developer-001` part (from the repository's own pvpkg overlay):
  remove it when deploying to a `strict` device. Apps must be signed with the
  identity's OEM key; the BSP and the OEM configuration part with its
  platform key.
- **Refs on secrets**: `tags/v*` limits a key to tags; a bare `v*` also
  matches a branch named `v1-test`. Suggest `tags/v*` for release keys.
- **Quotas**: 8 active builds per account, and the plan's build minutes per
  calendar month. Over the minutes, new builds get 402: tell the user, don't
  retry.
- **Merging, not importing**: on a device checkout use `pvr merge` (adds the
  export's parts). `pvr import` would replace the whole state.

## When a build fails

| Log or status | Likely cause | Fix |
| --- | --- | --- |
| `timed_out` | limit too low | raise `limit_seconds` |
| `cannot resolve git source` | wrong URL/ref, or private repo without a git secret | check the ref exists; add a git secret for the host |
| `secret … may be used only for builds of …` | the secret's refs don't cover this ref | build an allowed ref, or the user edits the secret's refs |
| `architecture … not in pvpkg arch` | platform not listed | add it to `arch` or drop the platform |
| Yocto `Sstate summary` match low, hours long | kas config differs from meta-pantavisor CI | copy CI's kas config (machine, distro, layer commits, local.conf) and only add your layer |
| `402 build minutes quota reached` | month's minutes used | wait for the reset or a bigger plan |
| `429` | 8 active builds | wait or cancel some |
| `503 build quota unavailable` | Hub hiccup | retry shortly |

For a device that refuses or rolls back a revision, read its logs for that
revision: signature errors (unsigned or wrong key in `strict`), a container
that doesn't start, or a group timeout during boot.

## Ask the user, don't guess

The device nick or id, the target architecture, which signing identity (if
any), and anything that costs a device: committing a revision, flashing.
Use sensible defaults for the rest and say which you chose.
