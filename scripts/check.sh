#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$REPO_ROOT"

shell_files="install.sh tests/unit.sh tests/qemu/boot.sh scripts/build.sh scripts/check-packages.sh scripts/check.sh scripts/smoke.sh"

AW_LIBRARY_ONLY=1
export AW_LIBRARY_ONLY
# shellcheck source=install.sh
. "$REPO_ROOT/install.sh"
[ "$AW_VERSION" = "$(sed -n '1p' VERSION)" ] || {
  printf '%s\n' "VERSION and install.sh disagree" >&2
  exit 1
}

printf '%s\n' "Checking POSIX shell syntax"
# Intentional word splitting: this is a path manifest controlled by the repository.
# shellcheck disable=SC2086
sh -n $shell_files

if command -v shellcheck >/dev/null 2>&1; then
  printf '%s\n' "Running ShellCheck"
  # shellcheck disable=SC2086
  shellcheck -x -s sh $shell_files
else
  printf '%s\n' "shellcheck not installed; skipped"
fi

if command -v shfmt >/dev/null 2>&1; then
  printf '%s\n' "Checking shell formatting"
  # shellcheck disable=SC2086
  shfmt -d -i 2 -ci $shell_files
else
  printf '%s\n' "shfmt not installed; skipped"
fi

printf '%s\n' "Running unit tests"
sh tests/unit.sh

printf '%s\n' "Checking release bundle"
bundle_dir=$(mktemp -d)
trap 'rm -rf "$bundle_dir"' EXIT HUP INT TERM
sh scripts/build.sh "$bundle_dir/alpine-workstation" >/dev/null
cmp install.sh "$bundle_dir/alpine-workstation"

if [ -r /etc/alpine-release ] && [ "$(cut -d. -f1,2 /etc/alpine-release)" = "3.24" ]; then
  printf '%s\n' "Checking Alpine package manifests"
  sh scripts/check-packages.sh
  sh scripts/smoke.sh
fi

printf '%s\n' "All available checks passed"
