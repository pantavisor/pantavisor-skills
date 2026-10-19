#!/bin/sh
# Zip every skill into dist/<name>.skill (the skill folder at the root of the
# archive), the file claude.ai and the Claude apps take under
# Settings -> Capabilities -> Skills.
set -eu
cd "$(dirname "$0")/.."
sh scripts/validate.sh
rm -rf dist
mkdir -p dist
cd skills
for dir in */; do
	name=${dir%/}
	zip -qr -X "../dist/$name.skill" "$name" -x '*/.DS_Store'
	echo "dist/$name.skill"
done
