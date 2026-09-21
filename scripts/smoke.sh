#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

sh "$REPO_ROOT/install.sh" --help >/dev/null
AW_CONTEXT_OVERRIDE=installed sh "$REPO_ROOT/install.sh" plan --defaults >/tmp/alpine-workstation-plan
grep -q 'GNOME with GDM' /tmp/alpine-workstation-plan
grep -q 'Planned stages' /tmp/alpine-workstation-plan
