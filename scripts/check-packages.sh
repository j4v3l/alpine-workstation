#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
AW_LIBRARY_ONLY=1
export AW_LIBRARY_ONLY
# shellcheck source=install.sh
. "$REPO_ROOT/install.sh"

apk update >/dev/null

packages="$AW_PKGS_CORE $AW_PKGS_BALANCED $AW_PKGS_SHELL $AW_PKGS_AUDIO
fprintd fprintd-pam linux-pam
mesa-dri-gallium mesa-va-gallium mesa-vulkan-intel mesa-vulkan-ati
intel-media-driver libva-intel-driver linux-firmware-i915
linux-firmware-amdgpu linux-firmware-nvidia amd-ucode intel-ucode
sof-firmware qemu-guest-agent spice-vdagent
greetd greetd-tuigreet
xdg-desktop-portal-gnome xdg-desktop-portal-kde
xdg-desktop-portal-gtk xdg-desktop-portal-wlr"

missing=0
# Intentional word splitting: package groups are space-delimited manifests.
# shellcheck disable=SC2086
for package in $(printf '%s\n' $packages | sort -u); do
  [ -n "$package" ] || continue
  if ! apk search -x "$package" | grep -q .; then
    printf 'missing package: %s\n' "$package" >&2
    missing=1
  fi
done

[ "$missing" -eq 0 ]
