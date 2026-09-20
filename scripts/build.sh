#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT=${1:-"$REPO_ROOT/dist/alpine-workstation"}

mkdir -p "$(dirname "$OUTPUT")"
cp "$REPO_ROOT/install.sh" "$OUTPUT"
chmod 0755 "$OUTPUT"

printf '%s\n' "$OUTPUT"
