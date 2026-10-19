#!/bin/sh
# Install the Pantavisor skills for every agent found on this machine:
# Claude Code, Codex, OpenCode and Antigravity (Gemini) all read the Agent
# Skills format (a folder with a SKILL.md); only the folder differs.
#
#   sh install.sh             copy into the user-wide folders
#   sh install.sh --link      symlink instead (to develop the skills)
#   sh install.sh --project   install into the current project instead
#   sh install.sh --uninstall remove what this script installed
#
# Run from a checkout, or with curl:
#   curl -fsSL https://raw.githubusercontent.com/pantavisor/pantavisor-skills/main/install.sh | sh
set -eu

REPO=https://github.com/pantavisor/pantavisor-skills
mode=copy
scope=user
for arg in "$@"; do
	case $arg in
	--link) mode=link ;;
	--project) scope=project ;;
	--uninstall) mode=uninstall ;;
	-h | --help) sed -n '2,13p' "$0"; exit 0 ;;
	*) echo "unknown option: $arg" >&2; exit 2 ;;
	esac
done

# Find the skills: this checkout, or a fresh shallow clone when piped.
src=""
if [ -d "$(dirname "$0")/skills" ]; then
	src=$(cd "$(dirname "$0")" && pwd)/skills
elif [ "$mode" != uninstall ]; then
	command -v git >/dev/null || { echo "git is needed to fetch $REPO" >&2; exit 1; }
	[ "$mode" = link ] && { echo "--link needs a checkout of $REPO" >&2; exit 1; }
	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' EXIT
	git clone -q --depth 1 "$REPO" "$tmp/repo"
	src=$tmp/repo/skills
fi

# Folders per agent: present when the agent is installed (its config folder
# exists), or always for --project.
targets=""
add() { targets="$targets $1"; }
if [ "$scope" = project ]; then
	add .claude/skills    # Claude Code
	add .agents/skills    # Codex, OpenCode
	add .agent/skills     # Antigravity
else
	[ -d "$HOME/.claude" ] && add "$HOME/.claude/skills"                          # Claude Code
	{ [ -d "$HOME/.codex" ] || [ -d "$HOME/.config/opencode" ] || [ -d "$HOME/.agents" ]; } &&
		add "$HOME/.agents/skills"                                                # Codex, OpenCode
	[ -d "$HOME/.gemini/antigravity" ] && add "$HOME/.gemini/antigravity/skills" # Antigravity
fi
[ -n "$targets" ] || { echo "no supported agent found (Claude Code, Codex, OpenCode, Antigravity)" >&2; exit 1; }

names=$(if [ -n "$src" ]; then ls "$src"; else echo pantavisor-apps; fi)
for target in $targets; do
	for name in $names; do
		dest=$target/$name
		case $mode in
		uninstall)
			[ -e "$dest" ] || [ -L "$dest" ] || continue
			rm -rf "$dest"; echo "removed $dest" ;;
		link)
			mkdir -p "$target"; rm -rf "$dest"; ln -s "$src/$name" "$dest"; echo "linked  $dest" ;;
		copy)
			mkdir -p "$target"; rm -rf "$dest"; cp -R "$src/$name" "$dest"; echo "copied  $dest" ;;
		esac
	done
done
[ "$mode" = uninstall ] || echo "Restart the agent (or start a new session) to load the skills."
