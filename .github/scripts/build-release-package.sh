#!/usr/bin/env bash
# Builds Regrets.zip from the project committed at a git ref. The zip holds the whole
# Godot project in a Regrets folder, with its README, CHANGELOG and license.
#
# Usage: build-release-package.sh [ref] [output directory]
#
# The README links to this file name through
# https://github.com/arcweave/arcweave-godot-adventure-example/releases/latest/download/Regrets.zip,
# so renaming it breaks that link.
set -euo pipefail

ref="${1:-HEAD}"
mkdir -p "${2:-dist}"
out_dir=$(cd "${2:-dist}" && pwd)
zip="$out_dir/Regrets.zip"

# The CHANGELOG must have a section for the project's version, so every release
# ships with its changes listed.
version=$(git show "$ref:project.godot" | sed -n 's/^config\/version="\(.*\)"$/\1/p')
[ -n "$version" ] || { echo "project.godot has no config/version" >&2; exit 1; }
git show "$ref:CHANGELOG.md" | grep -qx "## $version" ||
  { echo "CHANGELOG.md has no \"## $version\" section" >&2; exit 1; }

# .gitattributes keeps the repo's CI files out of the archive, and only committed files
# are packaged, so local untracked files never end up in a release.
git archive --format=zip --prefix=Regrets/ -o "$zip" "$ref"

entries=$(git archive "$ref" | tar -t)
for required in project.godot README.md CHANGELOG.md LICENSE addons/arcweave/plugin.cfg; do
  grep -qx "$required" <<< "$entries" || { echo "The package has no $required" >&2; exit 1; }
done

# The Arcweave plugin can store an API key in these files or in an ArcweaveAsset resource.
leaks=$(grep -E '^addons/arcweave/(data\.save|data\.json|env\.json)$' <<< "$entries" || true)
[ -z "$leaks" ] || { printf 'The package contains plugin files that can hold an API key:\n%s\n' "$leaks" >&2; exit 1; }
if git grep -qE '^api_key = "[^"]+' "$ref" -- '*.tres'; then
  echo "A resource in the package has an Arcweave API key:" >&2
  git grep -lE '^api_key = "[^"]+' "$ref" -- '*.tres' >&2
  exit 1
fi

echo "Built $zip (version $version) from $ref"
