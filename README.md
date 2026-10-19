# Pantavisor skills

[Agent Skills](https://agentskills.io) that teach AI assistants to build and
ship apps for embedded Linux devices running [Pantavisor](https://pantavisor.io),
with [Pantacor Hub](https://hub.pantacor.com)'s remote builds.

| Skill | What it does |
| --- | --- |
| [`pantavisor-apps`](skills/pantavisor-apps/SKILL.md) | From an empty repository to a signed container on a device, or a flashable device image: Dockerfile / `pvpkg.json` (Yocto, Buildroot), secrets and signing identities, builds, deploys, OEM configuration and join tokens. Uses the `pvr` CLI when it has a shell, the Pantahub MCP server otherwise. |

## Install

A skill is a folder with a `SKILL.md`; every agent below reads the same
folder, only the place differs.

**Claude Code, Codex, OpenCode, Antigravity (Gemini):**

```sh
curl -fsSL https://raw.githubusercontent.com/pantavisor/pantavisor-skills/main/install.sh | sh
```

or `npx skills add pantavisor/pantavisor-skills`, or from a checkout
`sh install.sh` (`--link` to symlink, `--project` for the current project,
`--uninstall` to remove). It installs into:

| Agent | User-wide | Per project |
| --- | --- | --- |
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| Codex, OpenCode | `~/.agents/skills/` | `.agents/skills/` |
| Antigravity | `~/.gemini/antigravity/skills/` | `.agent/skills/` |

**claude.ai and the Claude apps:** download `pantavisor-apps.skill` from the
[latest release](https://github.com/pantavisor/pantavisor-skills/releases/latest)
and upload it in Settings → Capabilities → Skills.

**Other chats:** clients without skills but with MCP get the same guidance
from the Pantahub MCP server itself (`get_build_guide`, and its prompts).

## Connect the Pantahub MCP server

The skill uses `pvr` when it can run commands, else the MCP server:

| Client | Add | Sign in |
| --- | --- | --- |
| claude.ai | Settings → Connectors → custom connector, `https://api.pantahub.com/mcp` | Connect |
| Claude Code | `claude mcp add --transport http pantahub https://api.pantahub.com/mcp` | `/mcp` |
| Codex | `codex mcp add pantahub --url https://api.pantahub.com/mcp` | `codex mcp login pantahub` |
| OpenCode | `opencode mcp add --global --url https://api.pantahub.com/mcp pantahub` | `opencode mcp auth pantahub` |
| Antigravity | `agy mcp add pantahub https://api.pantahub.com/mcp` | in the app, on first use |

Builds currently run on stage: use `https://api.stage.pantahub.com/mcp`
(named `pantahub-stage`) for them.

## Develop

```sh
sh install.sh --link      # agents read the skills straight from this checkout
sh scripts/validate.sh    # SKILL.md frontmatter checks
sh scripts/package.sh     # dist/<skill>.skill zips
```

Commits follow [Conventional Commits](https://www.conventionalcommits.org);
`CHANGELOG.md` is generated with
[git-chglog](https://github.com/git-chglog/git-chglog). A release is a tag
`vX.Y.Z`: CI validates the skills, builds the `.skill` files and attaches
them to the GitHub release, with that version's changelog as notes.

## License

Apache 2.0
