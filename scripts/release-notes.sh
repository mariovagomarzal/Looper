#!/usr/bin/env bash
# Prints the notes of the next release in Markdown, from the Conventional Commits since the latest tag.
set -euo pipefail
cd "$(dirname "$0")/.."

# Looper's history starts here: what comes before belongs to AeroSpace
first_looper_commit=251c272f

latest=$(git tag --list 'v[0-9]*' --sort=-version:refname | head -n 1)
range="${latest:-$first_looper_commit}..HEAD"

section() {
    local title=$1 pattern=$2 lines
    lines=$(git log --reverse --format='%h %s' "$range" |
        sed -nE "s/^([0-9a-f]+) $pattern: (.*)$/- \3 (\1)/p")
    if test -n "$lines"; then
        printf '## %s\n\n%s\n\n' "$title" "$lines"
    fi
}

section 'Breaking changes' '[a-z]+(\([^)]*\))?!'
section 'Features' 'feat(\([^)]*\))?'
section 'Fixes' 'fix(\([^)]*\))?'
echo "See the [docs](https://mariovagomarzal.github.io/Looper/docs/) to get started."
