#!/bin/sh
# Check every skills/<name>/SKILL.md against the Agent Skills format:
# frontmatter with a name equal to the folder and a description of at most
# 1024 characters.
set -eu
cd "$(dirname "$0")/.."
status=0
for dir in skills/*/; do
	name=$(basename "$dir")
	file="$dir/SKILL.md"
	if [ ! -f "$file" ]; then echo "$name: no SKILL.md"; status=1; continue; fi
	if [ "$(head -1 "$file")" != "---" ]; then echo "$name: SKILL.md has no frontmatter"; status=1; continue; fi
	front=$(awk 'NR==1{next} /^---$/{exit} {print}' "$file")
	fm_name=$(printf '%s\n' "$front" | sed -n 's/^name: *//p')
	desc=$(printf '%s\n' "$front" | sed -n 's/^description: *//p')
	[ "$fm_name" = "$name" ] || { echo "$name: frontmatter name is '$fm_name'"; status=1; }
	[ -n "$desc" ] || { echo "$name: no description"; status=1; }
	[ ${#desc} -le 1024 ] || { echo "$name: description is ${#desc} characters (max 1024)"; status=1; }
	printf '%s\n' "$name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || { echo "$name: name must be lowercase words joined by '-'"; status=1; }
	[ $status -eq 0 ] && echo "$name: ok"
done
exit $status
