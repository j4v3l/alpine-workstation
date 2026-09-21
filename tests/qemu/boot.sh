#!/bin/sh
set -eu

ALPINE_VERSION=${ALPINE_VERSION:-3.24.2}
ARCH=${ARCH:-x86_64}
MEMORY=${MEMORY:-3072}
CPUS=${CPUS:-2}
DISK_SIZE=${DISK_SIZE:-24G}
FIRMWARE=${FIRMWARE:-bios}
TEST_DIR=${TEST_DIR:-"${TMPDIR:-/tmp}/alpine-workstation-qemu"}
ISO_NAME="alpine-standard-$ALPINE_VERSION-$ARCH.iso"
BASE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/$ARCH"
ISO_PATH="$TEST_DIR/$ISO_NAME"
DISK_PATH="$TEST_DIR/workstation-$FIRMWARE.qcow2"

command -v qemu-system-x86_64 >/dev/null 2>&1 || {
  printf '%s\n' "qemu-system-x86_64 is required" >&2
  exit 1
}
command -v qemu-img >/dev/null 2>&1 || {
  printf '%s\n' "qemu-img is required" >&2
  exit 1
}

mkdir -p "$TEST_DIR"

if [ ! -f "$ISO_PATH" ]; then
  printf 'Downloading %s\n' "$ISO_NAME"
  if command -v curl >/dev/null 2>&1; then
    curl -fL "$BASE_URL/$ISO_NAME" -o "$ISO_PATH"
    curl -fsSL "$BASE_URL/$ISO_NAME.sha256" -o "$ISO_PATH.sha256"
  else
    wget -O "$ISO_PATH" "$BASE_URL/$ISO_NAME"
    wget -O "$ISO_PATH.sha256" "$BASE_URL/$ISO_NAME.sha256"
  fi
  (cd "$TEST_DIR" && sha256sum -c "$ISO_NAME.sha256")
fi

if [ ! -f "$DISK_PATH" ]; then
  qemu-img create -f qcow2 "$DISK_PATH" "$DISK_SIZE"
fi

accel="tcg"
cpu_model="max"
if [ -c /dev/kvm ]; then
  accel="kvm"
  cpu_model="host"
fi

firmware_args=""
if [ "$FIRMWARE" = "uefi" ]; then
  for firmware_path in \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/edk2/x64/OVMF_CODE.fd \
    /usr/share/qemu/edk2-x86_64-code.fd; do
    if [ -r "$firmware_path" ]; then
      firmware_args="-drive if=pflash,format=raw,readonly=on,file=$firmware_path"
      break
    fi
  done
  [ -n "$firmware_args" ] || {
    printf '%s\n' "UEFI firmware was not found; install OVMF or edk2-ovmf" >&2
    exit 1
  }
elif [ "$FIRMWARE" != "bios" ]; then
  printf '%s\n' "FIRMWARE must be bios or uefi" >&2
  exit 1
fi

printf '%s\n' "Guest disk: $DISK_PATH"
printf '%s\n' "At the Alpine prompt, configure networking, download install.sh, and use /dev/vda."

# Intentional word splitting: firmware_args contains QEMU argument pairs.
# shellcheck disable=SC2086
exec qemu-system-x86_64 \
  -machine "accel=$accel" \
  -m "$MEMORY" \
  -smp "$CPUS" \
  -cpu "$cpu_model" \
  -drive "file=$DISK_PATH,if=virtio,format=qcow2" \
  -cdrom "$ISO_PATH" \
  -boot d \
  -nic user,model=virtio-net-pci \
  -device virtio-vga \
  -serial mon:stdio \
  -display none \
  $firmware_args
