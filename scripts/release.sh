#!/usr/bin/env bash
# Builds a signed release of Looper.app and the CLI and packs them into .build/dist/Looper-v<version>.zip. The version
# is the one in the VERSION file.
#
# Usage: scripts/release.sh [--identity <codesign identity>]
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(cat VERSION)
identity="${LOOPER_CODESIGN_IDENTITY:-Looper Development}"
while test $# -gt 0; do
    case $1 in
        --identity) identity="$2"; shift 2 ;;
        *) echo "Unknown option $1" > /dev/stderr; exit 1 ;;
    esac
done
if ! test -z "$(git status --porcelain)"; then
    echo "The working tree must be clean: the release embeds the current commit hash" > /dev/stderr
    exit 1
fi

generated=(Sources/Common/versionGenerated.swift Sources/Common/gitHashGenerated.swift)
restore-generated() { git checkout -- "${generated[@]}"; }
trap restore-generated EXIT

scripts/generate.sh --build-version "$version" --git-hash

out=.build/dist
pack="$out/Looper-v$version"
rm -rf "$out"
scripts/bundle.sh --release --version "$version" --identity "$identity" --output "$out"

hash=$(git rev-parse HEAD)
for binary in "$out/Looper.app/Contents/MacOS/Looper" "$out/looper"; do
    if ! grep -a -q --fixed-strings "$hash" "$binary"; then
        echo "$binary doesn't contain $hash" > /dev/stderr
        exit 1
    fi
done

just completion
mkdir -p "$pack/bin"
cp -R "$out/Looper.app" "$pack/"
cp "$out/looper" "$pack/bin/"
cp -R .build/completion "$pack/shell-completion"
cp -R -L legal "$pack/legal"
(cd "$out" && zip -qry "Looper-v$version.zip" "Looper-v$version")

echo "$out/Looper-v$version.zip"
