#!/bin/sh
# Alpine Workstation - turn an Alpine TTY into a daily-driver workstation.

set -eu

AW_VERSION="0.1.0"
AW_SUPPORTED_RELEASE="3.24"
AW_REPOSITORY="j4v3l/alpine-workstation"
AW_OMZ_REVISION="6421f8e104e4e87f2373362cbf61e46a918612a7"

AW_COMMAND="install"
AW_DEFAULTS=0
AW_DESKTOP="gnome"
AW_PROFILE="balanced"
AW_DISK=""
AW_ENCRYPT=0
AW_EDGE_PACKAGES=""
AW_USER=""
AW_HOSTNAME=""
AW_CONTEXT=""
AW_LIVE_TARGET="${AW_LIVE_TARGET:-0}"
AW_STATE_DIR="${AW_STATE_DIR:-/var/lib/alpine-workstation}"
AW_LOG_DIR="${AW_LOG_DIR:-/var/log/alpine-workstation}"
AW_LOG_FILE=""
AW_RUN_ID=""
AW_SSH_KEY=""
AW_SSH_ENABLED=1
AW_FINGERPRINT="auto"

AW_C_RESET=""
AW_C_BOLD=""
AW_C_BLUE=""
AW_C_GREEN=""
AW_C_YELLOW=""
AW_C_RED=""

if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ]; then
  AW_C_RESET="$(printf '\033[0m')"
  AW_C_BOLD="$(printf '\033[1m')"
  AW_C_BLUE="$(printf '\033[34m')"
  AW_C_GREEN="$(printf '\033[32m')"
  AW_C_YELLOW="$(printf '\033[33m')"
  AW_C_RED="$(printf '\033[31m')"
fi

aw_print() {
  printf '%s\n' "$*"
  if [ -n "$AW_LOG_FILE" ] && [ -d "$AW_LOG_DIR" ]; then
    printf '%s\n' "$*" >>"$AW_LOG_FILE"
  fi
}

aw_info() {
  aw_print "${AW_C_BLUE}[info]${AW_C_RESET} $*"
}

aw_ok() {
  aw_print "${AW_C_GREEN}[ok]${AW_C_RESET} $*"
}

aw_warn() {
  aw_print "${AW_C_YELLOW}[warn]${AW_C_RESET} $*"
}

aw_error() {
  aw_print "${AW_C_RED}[error]${AW_C_RESET} $*" >&2
}

aw_die() {
  aw_error "$*"
  exit 1
}

aw_have() {
  command -v "$1" >/dev/null 2>&1
}

aw_usage() {
  cat <<EOF
Alpine Workstation ${AW_VERSION}
Source: https://github.com/${AW_REPOSITORY}

Usage:
  sh install.sh [install] [options]
  sh install.sh plan [options]
  sh install.sh resume
  sh install.sh status
  sh install.sh doctor
  sh install.sh secure-ssh [--user NAME]

Install options:
  --defaults                  Use GNOME and the balanced profile
  --desktop NAME              gnome, plasma, xfce, or sway
  --profile NAME              core or balanced
  --disk DEVICE               Whole disk used only from an Alpine live ISO
  --encrypt                   Use Alpine's LUKS and LVM disk layout
  --edge-package PACKAGE@TAG  Install one package through edge-main,
                              edge-community, or edge-testing
  --user NAME                 Administrator account
  --hostname NAME             System hostname
  --fingerprint MODE          auto, yes, or no
  --plain                     Disable decorative terminal output
  -h, --help                  Show this help

No option bypasses disk confirmation or accepts a password on the command line.
EOF
}

aw_valid_name() {
  case "$1" in
    '' | *[!a-z_0-9-]* | [0-9-]*) return 1 ;;
    *) return 0 ;;
  esac
}

aw_valid_hostname() {
  case "$1" in
    '' | *[!A-Za-z0-9.-]* | .* | -* | *-) return 1 ;;
    *) return 0 ;;
  esac
}

aw_valid_edge_package() {
  case "$1" in
    *@edge-main | *@edge-community | *@edge-testing)
      pkg=${1%@*}
      case "$pkg" in
        '' | *[!A-Za-z0-9+_.-]*) return 1 ;;
        *) return 0 ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

aw_parse_args() {
  if [ "$#" -gt 0 ]; then
    case "$1" in
      install | plan | resume | status | doctor | secure-ssh | _postinstall)
        AW_COMMAND=$1
        shift
        ;;
    esac
  fi

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --defaults)
        AW_DEFAULTS=1
        ;;
      --desktop)
        [ "$#" -ge 2 ] || aw_die "--desktop requires a value"
        AW_DESKTOP=$2
        shift
        ;;
      --desktop=*) AW_DESKTOP=${1#*=} ;;
      --profile)
        [ "$#" -ge 2 ] || aw_die "--profile requires a value"
        AW_PROFILE=$2
        shift
        ;;
      --profile=*) AW_PROFILE=${1#*=} ;;
      --disk)
        [ "$#" -ge 2 ] || aw_die "--disk requires a value"
        AW_DISK=$2
        shift
        ;;
      --disk=*) AW_DISK=${1#*=} ;;
      --encrypt) AW_ENCRYPT=1 ;;
      --edge-package)
        [ "$#" -ge 2 ] || aw_die "--edge-package requires a value"
        aw_valid_edge_package "$2" || aw_die "edge packages must use NAME@edge-main, NAME@edge-community, or NAME@edge-testing"
        AW_EDGE_PACKAGES="${AW_EDGE_PACKAGES}${AW_EDGE_PACKAGES:+ }$2"
        shift
        ;;
      --edge-package=*)
        edge_value=${1#*=}
        aw_valid_edge_package "$edge_value" || aw_die "edge packages must use NAME@edge-main, NAME@edge-community, or NAME@edge-testing"
        AW_EDGE_PACKAGES="${AW_EDGE_PACKAGES}${AW_EDGE_PACKAGES:+ }$edge_value"
        ;;
      --user)
        [ "$#" -ge 2 ] || aw_die "--user requires a value"
        AW_USER=$2
        shift
        ;;
      --user=*) AW_USER=${1#*=} ;;
      --hostname)
        [ "$#" -ge 2 ] || aw_die "--hostname requires a value"
        AW_HOSTNAME=$2
        shift
        ;;
      --hostname=*) AW_HOSTNAME=${1#*=} ;;
      --fingerprint)
        [ "$#" -ge 2 ] || aw_die "--fingerprint requires a value"
        AW_FINGERPRINT=$2
        shift
        ;;
      --fingerprint=*) AW_FINGERPRINT=${1#*=} ;;
      --ssh-disabled) AW_SSH_ENABLED=0 ;;
      --plain)
        AW_C_RESET=""
        AW_C_BOLD=""
        AW_C_BLUE=""
        AW_C_GREEN=""
        AW_C_YELLOW=""
        AW_C_RED=""
        ;;
      -h | --help)
        aw_usage
        exit 0
        ;;
      *) aw_die "unknown option: $1" ;;
    esac
    shift
  done

  case "$AW_DESKTOP" in
    gnome | plasma | xfce | sway) ;;
    *) aw_die "unsupported desktop: $AW_DESKTOP" ;;
  esac
  case "$AW_PROFILE" in
    core | balanced) ;;
    *) aw_die "unsupported profile: $AW_PROFILE" ;;
  esac
  case "$AW_FINGERPRINT" in
    auto | yes | no) ;;
    *) aw_die "--fingerprint must be auto, yes, or no" ;;
  esac
  if [ -n "$AW_USER" ]; then
    aw_valid_name "$AW_USER" || aw_die "invalid user name: $AW_USER"
  fi
  if [ -n "$AW_HOSTNAME" ]; then
    aw_valid_hostname "$AW_HOSTNAME" || aw_die "invalid hostname: $AW_HOSTNAME"
  fi
}

aw_read() {
  prompt=$1
  default=${2:-}
  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$prompt" "$default" >/dev/tty
  else
    printf '%s: ' "$prompt" >/dev/tty
  fi
  IFS= read -r answer </dev/tty || answer=""
  if [ -z "$answer" ]; then
    answer=$default
  fi
  printf '%s' "$answer"
}

aw_confirm() {
  prompt=$1
  default=${2:-no}
  if [ "$default" = "yes" ]; then
    suffix="Y/n"
  else
    suffix="y/N"
  fi
  printf '%s [%s]: ' "$prompt" "$suffix" >/dev/tty
  IFS= read -r answer </dev/tty || answer=""
  case "$answer:$default" in
    y*:yes | Y*:yes | y*:no | Y*:no | :yes) return 0 ;;
    *) return 1 ;;
  esac
}

aw_detect_context() {
  if [ -n "${AW_CONTEXT_OVERRIDE:-}" ]; then
    AW_CONTEXT=$AW_CONTEXT_OVERRIDE
    return
  fi
  root_fs=$(awk '$2 == "/" {print $3; exit}' /proc/mounts 2>/dev/null || true)
  root_dev=$(awk '$2 == "/" {print $1; exit}' /proc/mounts 2>/dev/null || true)
  if aw_have setup-disk && { [ "$root_fs" = "tmpfs" ] || [ "$root_fs" = "squashfs" ] || [ "$root_dev" = "rootfs" ]; }; then
    AW_CONTEXT="live"
  else
    AW_CONTEXT="installed"
  fi
}

aw_alpine_release() {
  if [ -n "${AW_RELEASE_OVERRIDE:-}" ]; then
    printf '%s\n' "$AW_RELEASE_OVERRIDE"
  elif [ -r /etc/alpine-release ]; then
    sed -n '1p' /etc/alpine-release
  else
    printf '%s\n' "unknown"
  fi
}

aw_preflight() {
  [ -r /etc/alpine-release ] || [ -n "${AW_RELEASE_OVERRIDE:-}" ] || aw_die "this installer only supports Alpine Linux"
  arch=${AW_ARCH_OVERRIDE:-$(uname -m)}
  [ "$arch" = "x86_64" ] || aw_die "unsupported architecture: $arch; v1 supports x86_64"
  release=$(aw_alpine_release)
  release_branch=$(printf '%s' "$release" | awk -F. '{print $1 "." $2}')
  if [ "$release_branch" != "$AW_SUPPORTED_RELEASE" ]; then
    aw_die "Alpine $release is unsupported. Install Alpine $AW_SUPPORTED_RELEASE from current media, then run this installer again."
  fi
  if [ "$AW_COMMAND" != "plan" ] && [ "$(id -u)" -ne 0 ]; then
    aw_die "installation must run as root; use doas or log in as root"
  fi
  if [ "$AW_CONTEXT" = "live" ] && aw_secure_boot_enabled; then
    aw_die "UEFI Secure Boot is enabled. Disable it in firmware before installing Alpine."
  fi
}

aw_secure_boot_enabled() {
  [ -d /sys/firmware/efi/efivars ] || return 1
  for secure_boot_file in /sys/firmware/efi/efivars/SecureBoot-*; do
    [ -r "$secure_boot_file" ] || continue
    secure_boot_value=$(od -An -t u1 "$secure_boot_file" 2>/dev/null | awk '{value=$NF} END {print value}')
    [ "$secure_boot_value" = "1" ] && return 0
  done
  return 1
}

aw_start_run() {
  AW_RUN_ID=$(date -u +%Y%m%dT%H%M%SZ)-$$
  mkdir -p "$AW_STATE_DIR/stages" "$AW_STATE_DIR/managed" "$AW_STATE_DIR/backups/$AW_RUN_ID" "$AW_LOG_DIR"
  AW_LOG_FILE="$AW_LOG_DIR/$AW_RUN_ID.log"
  : >"$AW_LOG_FILE"
  lock_dir="$AW_STATE_DIR/lock"
  if ! mkdir "$lock_dir" 2>/dev/null; then
    aw_die "another installer process is active; remove $lock_dir only after confirming it is stale"
  fi
  trap 'rmdir "$AW_STATE_DIR/lock" 2>/dev/null || true' EXIT HUP INT TERM
  aw_print "${AW_C_BOLD}Alpine Workstation ${AW_VERSION}${AW_C_RESET}"
  aw_info "context=$AW_CONTEXT release=$(aw_alpine_release) desktop=$AW_DESKTOP profile=$AW_PROFILE"
}

aw_state_set() {
  key=$1
  value=$2
  case "$key" in
    *[!A-Z0-9_]*) aw_die "invalid state key" ;;
  esac
  case "$value" in
    *[!A-Za-z0-9_+.,/@:-]*) aw_die "invalid state value for $key" ;;
  esac
  printf '%s=%s\n' "$key" "$value" >>"$AW_STATE_DIR/state.env"
}

aw_state_get() {
  key=$1
  [ -r "$AW_STATE_DIR/state.env" ] || return 1
  awk -F= -v key="$key" '$1 == key {value=substr($0, length(key) + 2)} END {if (value != "") print value; else exit 1}' "$AW_STATE_DIR/state.env"
}

aw_stage_done() {
  [ -e "$AW_STATE_DIR/stages/$AW_VERSION.$1" ]
}

aw_stage_mark() {
  : >"$AW_STATE_DIR/stages/$AW_VERSION.$1"
}

aw_run_stage() {
  stage_name=$1
  stage_function=$2
  if aw_stage_done "$stage_name"; then
    aw_ok "$stage_name already complete"
    return 0
  fi
  aw_info "stage: $stage_name"
  "$stage_function"
  aw_stage_mark "$stage_name"
  aw_ok "$stage_name complete"
}

aw_sha256() {
  if aw_have sha256sum; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

aw_managed_key() {
  printf '%s' "$1" | sed 's#^/##; s#[^A-Za-z0-9_.-]#_#g'
}

aw_write_managed() {
  target=$1
  mode=$2
  owner=$3
  temp_file=$(mktemp)
  cat >"$temp_file"
  target_dir=$(dirname "$target")
  mkdir -p "$target_dir"
  key=$(aw_managed_key "$target")
  hash_file="$AW_STATE_DIR/managed/$key.sha256"

  if [ -e "$target" ]; then
    current_hash=$(aw_sha256 "$target")
    previous_hash=""
    [ -r "$hash_file" ] && previous_hash=$(sed -n '1p' "$hash_file")
    if [ -n "$previous_hash" ] && [ "$current_hash" != "$previous_hash" ]; then
      candidate="$target.new"
      cp "$temp_file" "$candidate"
      chmod "$mode" "$candidate"
      chown "$owner" "$candidate" 2>/dev/null || true
      aw_warn "$target has local changes; wrote $candidate"
      rm -f "$temp_file"
      return 0
    fi
    backup="$AW_STATE_DIR/backups/$AW_RUN_ID$target"
    mkdir -p "$(dirname "$backup")"
    cp -p "$target" "$backup"
  fi

  cp "$temp_file" "$target"
  chmod "$mode" "$target"
  chown "$owner" "$target" 2>/dev/null || true
  aw_sha256 "$target" >"$hash_file"
  rm -f "$temp_file"
}

aw_desktop_label() {
  case "$AW_DESKTOP" in
    gnome) printf '%s' "GNOME with GDM" ;;
    plasma) printf '%s' "Plasma with SDDM" ;;
    xfce) printf '%s' "Xfce with LightDM" ;;
    sway) printf '%s' "Sway with greetd" ;;
  esac
}

aw_choose_desktop() {
  [ "$AW_DEFAULTS" -eq 0 ] || return 0
  cat >/dev/tty <<'EOF'

Desktop environment
  1) GNOME (default)
  2) Plasma
  3) Xfce
  4) Sway
EOF
  choice=$(aw_read "Choose a desktop" "1")
  case "$choice" in
    1 | gnome) AW_DESKTOP="gnome" ;;
    2 | plasma) AW_DESKTOP="plasma" ;;
    3 | xfce) AW_DESKTOP="xfce" ;;
    4 | sway) AW_DESKTOP="sway" ;;
    *) aw_die "invalid desktop choice: $choice" ;;
  esac
}

aw_default_user() {
  awk -F: '$3 >= 1000 && $3 < 65000 {print $1; exit}' /etc/passwd 2>/dev/null || true
}

aw_collect_identity() {
  if [ -z "$AW_USER" ]; then
    default_user=$(aw_default_user)
    [ -n "$default_user" ] || default_user="user"
    AW_USER=$(aw_read "Administrator user name" "$default_user")
  fi
  aw_valid_name "$AW_USER" || aw_die "invalid user name: $AW_USER"

  if [ -z "$AW_HOSTNAME" ]; then
    current_hostname=$(hostname 2>/dev/null || true)
    case "$current_hostname" in
      '' | localhost | '(none)') current_hostname="alpine" ;;
    esac
    AW_HOSTNAME=$(aw_read "System hostname" "$current_hostname")
  fi
  aw_valid_hostname "$AW_HOSTNAME" || aw_die "invalid hostname: $AW_HOSTNAME"
}

aw_resolve_ssh_key() {
  source_value=$1
  case "$source_value" in
    github:*)
      github_user=${source_value#github:}
      aw_valid_name "$github_user" || aw_die "invalid GitHub user name"
      aw_have curl || aw_die "curl is required to import a GitHub key"
      key_data=$(curl -fsSL "https://github.com/$github_user.keys") || aw_die "could not import keys for $github_user"
      ;;
    https://* | http://*)
      aw_have curl || aw_die "curl is required to import a key URL"
      key_data=$(curl -fsSL "$source_value") || aw_die "could not import SSH key URL"
      ;;
    /* | ./* | ../*)
      [ -r "$source_value" ] || aw_die "cannot read SSH key file: $source_value"
      key_data=$(cat "$source_value")
      ;;
    *) key_data=$source_value ;;
  esac
  key_data=$(printf '%s\n' "$key_data" | awk 'NF && $1 ~ /^(ssh-|ecdsa-|sk-)/ {print; exit}')
  [ -n "$key_data" ] || aw_die "no valid public SSH key was found"
  AW_SSH_KEY=$key_data
}

aw_collect_ssh_key() {
  existing_key=""
  if id "$AW_USER" >/dev/null 2>&1; then
    existing_home=$(awk -F: -v user="$AW_USER" '$1 == user {print $6}' /etc/passwd)
    if [ -r "$existing_home/.ssh/authorized_keys" ]; then
      existing_key=$(awk 'NF && $1 ~ /^(ssh-|ecdsa-|sk-)/ {print; exit}' "$existing_home/.ssh/authorized_keys")
    fi
  fi
  if [ -z "$existing_key" ] && [ -r /root/.ssh/authorized_keys ]; then
    existing_key=$(awk 'NF && $1 ~ /^(ssh-|ecdsa-|sk-)/ {print; exit}' /root/.ssh/authorized_keys)
  fi
  if [ -n "$existing_key" ] && aw_confirm "Use the existing SSH public key for $AW_USER" "yes"; then
    AW_SSH_KEY=$existing_key
    return
  fi
  aw_print "Enter a public key, a readable file, a URL, or github:USERNAME."
  key_source=$(aw_read "SSH key source; leave empty to disable SSH" "")
  if [ -z "$key_source" ]; then
    AW_SSH_ENABLED=0
    aw_warn "SSH will be disabled because no administrator key was supplied"
    return
  fi
  aw_resolve_ssh_key "$key_source"
}

aw_prepare_live_tools() {
  [ "$AW_CONTEXT" = "live" ] || return 0
  aw_have lsblk && return 0
  aw_info "installing live-media disk inspection tools"
  if ! apk add --no-cache \
    --repository "https://dl-cdn.alpinelinux.org/alpine/v${AW_SUPPORTED_RELEASE}/main" \
    util-linux; then
    aw_die "could not install util-linux; configure networking on the live ISO and retry"
  fi
  aw_have lsblk || aw_die "lsblk is unavailable after installing util-linux"
}

aw_list_candidate_disks() {
  aw_have lsblk || return 0
  lsblk -dnpo NAME,TYPE,SIZE,MODEL,SERIAL,RM 2>/dev/null | while IFS= read -r disk_line; do
    disk_name=$(printf '%s\n' "$disk_line" | awk '{print $1}')
    disk_type=$(printf '%s\n' "$disk_line" | awk '{print $2}')
    [ "$disk_type" = "disk" ] || continue
    aw_validate_disk "$disk_name" || continue
    printf '%s\n' "$disk_line"
  done
}

aw_validate_disk() {
  [ -b "$1" ] || return 1
  [ "$(lsblk -dnro TYPE "$1" 2>/dev/null)" = "disk" ] || return 1
  disk_size=$(lsblk -bdnro SIZE "$1" 2>/dev/null || true)
  case "$disk_size" in
    '' | *[!0-9]*) return 1 ;;
  esac
  [ "$disk_size" -gt 0 ] || return 1
  if lsblk -lnpo MOUNTPOINT "$1" 2>/dev/null | awk 'NF {found=1} END {exit !found}'; then
    return 1
  fi
  return 0
}

aw_collect_disk() {
  [ "$AW_CONTEXT" = "live" ] || return 0
  aw_print ""
  aw_print "Available unmounted whole disks:"
  aw_list_candidate_disks | sed 's/^/  /'
  if [ -z "$AW_DISK" ]; then
    AW_DISK=$(aw_read "Target whole disk, for example /dev/sda" "")
  fi
  aw_validate_disk "$AW_DISK" || aw_die "$AW_DISK is not an unmounted whole disk"
  if [ "$AW_DEFAULTS" -eq 0 ] && aw_confirm "Encrypt the disk with LUKS and LVM" "no"; then
    AW_ENCRYPT=1
  fi
}

aw_collect_edge_packages() {
  [ "$AW_DEFAULTS" -eq 0 ] || return 0
  if aw_confirm "Add explicitly tagged packages from Alpine edge" "no"; then
    aw_print "Use PACKAGE@edge-main, PACKAGE@edge-community, or PACKAGE@edge-testing."
    edge_line=$(aw_read "Space-separated edge packages" "")
    for edge_pkg in $edge_line; do
      aw_valid_edge_package "$edge_pkg" || aw_die "invalid edge package: $edge_pkg"
      AW_EDGE_PACKAGES="${AW_EDGE_PACKAGES}${AW_EDGE_PACKAGES:+ }$edge_pkg"
    done
  fi
}

aw_collect_inputs() {
  aw_choose_desktop
  aw_collect_identity
  aw_collect_ssh_key
  aw_collect_disk
  aw_collect_edge_packages
}

aw_detect_gpu() {
  if aw_have lspci; then
    lspci -nn 2>/dev/null | awk 'tolower($0) ~ /(vga compatible controller|3d controller|display controller)/ {print}'
  fi
}

aw_detect_fingerprint() {
  [ "$AW_FINGERPRINT" != "no" ] || return 1
  [ "$AW_FINGERPRINT" = "yes" ] && return 0
  aw_have lsusb || return 1
  lsusb 2>/dev/null | grep -Eiq 'finger|synaptics|goodix|elan|validity|06cb:|27c6:'
}

aw_plan() {
  aw_detect_context
  aw_preflight
  gpu_info=$(aw_detect_gpu || true)
  cat <<EOF
Alpine Workstation ${AW_VERSION} plan

  Context:       $AW_CONTEXT
  Alpine:        $(aw_alpine_release)
  Architecture:  ${AW_ARCH_OVERRIDE:-$(uname -m)}
  Desktop:       $(aw_desktop_label)
  Profile:       $AW_PROFILE
  Administrator: ${AW_USER:-prompt during install}
  Hostname:      ${AW_HOSTNAME:-prompt during install}
  Disk:          ${AW_DISK:-not selected}
  Encryption:    $([ "$AW_ENCRYPT" -eq 1 ] && printf enabled || printf disabled)
  Edge packages: ${AW_EDGE_PACKAGES:-none}

Detected graphics:
${gpu_info:-  none reported}

Planned stages:
  repositories -> packages -> desktop -> hardware -> services -> shell -> validation
EOF
  if [ "$AW_CONTEXT" = "live" ]; then
    printf '%s\n' "  base-install runs before those stages and erases only the confirmed disk"
  fi
}

aw_status() {
  aw_print "Alpine Workstation ${AW_VERSION} status"
  if [ ! -r "$AW_STATE_DIR/state.env" ]; then
    aw_print "  not installed"
    return 0
  fi
  sed 's/^/  /' "$AW_STATE_DIR/state.env"
  aw_print "  stages:"
  found_stage=0
  for stage_file in "$AW_STATE_DIR"/stages/*; do
    [ -e "$stage_file" ] || continue
    found_stage=1
    aw_print "    $(basename "$stage_file")"
  done
  [ "$found_stage" -eq 1 ] || aw_print "    none"
}

aw_check() {
  label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    aw_ok "$label"
    return 0
  fi
  aw_warn "$label"
  return 1
}

aw_doctor() {
  failures=0
  aw_print "Alpine Workstation ${AW_VERSION} doctor"
  release=$(aw_alpine_release)
  [ "$(printf '%s' "$release" | awk -F. '{print $1 "." $2}')" = "$AW_SUPPORTED_RELEASE" ] || {
    aw_warn "release: Alpine $release is unsupported"
    failures=$((failures + 1))
  }
  aw_check "apk database" apk audit --system || failures=$((failures + 1))
  aw_check "D-Bus enabled" sh -c "rc-update show 2>/dev/null | grep -q 'dbus'" || failures=$((failures + 1))
  aw_check "desktop command available" sh -c "command -v gnome-shell >/dev/null 2>&1 || command -v startplasma-wayland >/dev/null 2>&1 || command -v startxfce4 >/dev/null 2>&1 || command -v sway >/dev/null 2>&1" || failures=$((failures + 1))
  aw_check "PipeWire installed" sh -c "apk info -e pipewire >/dev/null 2>&1" || failures=$((failures + 1))
  aw_check "WirePlumber installed" sh -c "apk info -e wireplumber >/dev/null 2>&1" || failures=$((failures + 1))
  aw_check "nftables enabled" sh -c "rc-update show 2>/dev/null | grep -q 'nftables'" || failures=$((failures + 1))
  aw_check "SSH configuration" sshd -t || failures=$((failures + 1))
  if [ -n "${XDG_RUNTIME_DIR:-}" ] && aw_have wpctl; then
    aw_check "PipeWire session" wpctl status || failures=$((failures + 1))
  else
    aw_info "PipeWire runtime check deferred until a graphical user session"
  fi
  if [ "$failures" -gt 0 ]; then
    aw_error "$failures health checks need attention"
    return 1
  fi
  aw_ok "all available health checks passed"
}

AW_PKGS_CORE="alpine-conf ca-certificates curl wget git openssh doas bash shadow util-linux pciutils usbutils coreutils findutils grep sed less mandoc man-pages tzdata musl-locales musl-utils iproute2 eudev dbus elogind polkit-elogind fontconfig xdg-user-dirs nftables nftables-openrc"
AW_PKGS_BALANCED="firefox libreoffice ffmpeg gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav celluloid flatpak gnome-software-plugin-apk gnome-software-plugin-flatpak xdg-desktop-portal xdg-utils gvfs gvfs-avahi udisks2 networkmanager networkmanager-openrc networkmanager-wifi networkmanager-openvpn networkmanager-openconnect networkmanager-cli networkmanager-bluetooth bluez bluez-openrc pipewire-spa-bluez blueman cups cups-openrc cups-filters cups-pdf cups-pk-helper gutenprint avahi avahi-openrc avahi-tools sane sane-backends simple-scan fwupd power-profiles-daemon font-noto font-noto-cjk font-noto-emoji font-jetbrains-mono-nerd font-dejavu"
AW_PKGS_SHELL="zsh zsh-autosuggestions zsh-syntax-highlighting starship zoxide fzf eza bat fd ripgrep btop neovim tmux tree jq unzip p7zip xz file"
AW_PKGS_AUDIO="pipewire pipewire-openrc pipewire-alsa pipewire-pulse pipewire-pulse-openrc pipewire-jack pipewire-tools wireplumber wireplumber-openrc alsa-utils pavucontrol rtkit openrc-user openrc-user-pam"

aw_apk_add() {
  [ "$#" -gt 0 ] || return 0
  aw_info "installing packages: $*"
  apk add "$@"
}

aw_enable_repositories() {
  repository_file=$(mktemp)
  cat >"$repository_file" <<EOF
https://dl-cdn.alpinelinux.org/alpine/v${AW_SUPPORTED_RELEASE}/main
https://dl-cdn.alpinelinux.org/alpine/v${AW_SUPPORTED_RELEASE}/community
EOF
  if [ -n "$AW_EDGE_PACKAGES" ]; then
    cat >>"$repository_file" <<'EOF'
@edge-main https://dl-cdn.alpinelinux.org/alpine/edge/main
@edge-community https://dl-cdn.alpinelinux.org/alpine/edge/community
@edge-testing https://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF
  fi
  aw_write_managed /etc/apk/repositories 0644 root:root <"$repository_file"
  rm -f "$repository_file"
  apk update
}

aw_install_packages() {
  # Intentional word splitting: package groups are space-delimited manifests.
  # shellcheck disable=SC2086
  aw_apk_add $AW_PKGS_CORE $AW_PKGS_SHELL $AW_PKGS_AUDIO
  if [ "$AW_PROFILE" = "balanced" ]; then
    # shellcheck disable=SC2086
    aw_apk_add $AW_PKGS_BALANCED
  fi
  if [ -n "$AW_EDGE_PACKAGES" ]; then
    # shellcheck disable=SC2086
    aw_apk_add $AW_EDGE_PACKAGES
  fi
}

aw_install_desktop() {
  existing_desktops=0
  for desktop_command in gnome-shell startplasma-wayland startxfce4 sway; do
    if aw_have "$desktop_command"; then
      existing_desktops=$((existing_desktops + 1))
    fi
  done
  if [ "$existing_desktops" -gt 0 ]; then
    case "$AW_DESKTOP" in
      gnome) aw_have gnome-shell || aw_die "another desktop is already installed; desktop stacking is not supported" ;;
      plasma) aw_have startplasma-wayland || aw_die "another desktop is already installed; desktop stacking is not supported" ;;
      xfce) aw_have startxfce4 || aw_die "another desktop is already installed; desktop stacking is not supported" ;;
      sway) aw_have sway || aw_die "another desktop is already installed; desktop stacking is not supported" ;;
    esac
    aw_ok "requested desktop is already present"
    return 0
  fi
  if [ "$AW_LIVE_TARGET" -eq 1 ]; then
    service_wrapper_dir=$(mktemp -d)
    cat >"$service_wrapper_dir/rc-service" <<'EOF'
#!/bin/sh
# Services cannot be started while the target filesystem is in a chroot.
exit 0
EOF
    chmod 0755 "$service_wrapper_dir/rc-service"
    PATH="$service_wrapper_dir:$PATH" setup-desktop "$AW_DESKTOP"
    rm -rf "$service_wrapper_dir"
  else
    setup-desktop "$AW_DESKTOP"
  fi
  case "$AW_DESKTOP" in
    gnome) aw_apk_add xdg-desktop-portal-gnome ;;
    plasma) aw_apk_add xdg-desktop-portal-kde ;;
    xfce) aw_apk_add xdg-desktop-portal-gtk ;;
    sway) aw_apk_add xdg-desktop-portal-wlr ;;
  esac
  if [ "$AW_DESKTOP" = "sway" ]; then
    aw_apk_add greetd greetd-tuigreet
    aw_write_managed /etc/greetd/config.toml 0644 root:root <<'EOF'
[terminal]
vt = 7

[default_session]
command = "tuigreet --time --remember --cmd sway"
user = "greetd"
EOF
    rc-update add greetd default
  fi
}

aw_hardware_packages() {
  hardware_packages="mesa-dri-gallium mesa-va-gallium"
  gpu_info=$(aw_detect_gpu || true)
  if printf '%s\n' "$gpu_info" | grep -Eiq 'Intel'; then
    hardware_packages="$hardware_packages mesa-vulkan-intel intel-media-driver linux-firmware-i915"
  fi
  if printf '%s\n' "$gpu_info" | grep -Eiq 'AMD|ATI'; then
    hardware_packages="$hardware_packages mesa-vulkan-ati linux-firmware-amdgpu"
  fi
  if printf '%s\n' "$gpu_info" | grep -Eiq 'NVIDIA'; then
    hardware_packages="$hardware_packages linux-firmware-nvidia"
    aw_warn "NVIDIA detected: Alpine supports Nouveau, not the proprietary driver. CUDA and some power/performance features will be unavailable."
  fi
  if grep -Eiq 'GenuineIntel' /proc/cpuinfo 2>/dev/null; then
    hardware_packages="$hardware_packages intel-ucode"
  fi
  if grep -Eiq 'AuthenticAMD' /proc/cpuinfo 2>/dev/null; then
    hardware_packages="$hardware_packages amd-ucode"
  fi
  if grep -Eiq 'intel.*audio|audio.*intel' /proc/bus/pci/devices 2>/dev/null || printf '%s\n' "$(lspci 2>/dev/null || true)" | grep -Eiq 'audio.*intel'; then
    hardware_packages="$hardware_packages sof-firmware"
  fi
  if grep -Eiq 'hypervisor' /proc/cpuinfo 2>/dev/null; then
    hardware_packages="$hardware_packages qemu-guest-agent spice-vdagent"
  fi
  # shellcheck disable=SC2086
  aw_apk_add $hardware_packages
}

aw_fix_nomodeset() {
  grep -qw nomodeset /proc/cmdline 2>/dev/null || return 0
  [ -n "$(aw_detect_gpu || true)" ] || return 0
  aw_warn "removing nomodeset so kernel graphics drivers can initialize"
  if [ -f /etc/update-extlinux.conf ]; then
    cp -p /etc/update-extlinux.conf "$AW_STATE_DIR/backups/$AW_RUN_ID/etc-update-extlinux.conf"
    sed -i 's/[[:space:]]*nomodeset//g' /etc/update-extlinux.conf
    aw_have update-extlinux && update-extlinux
  elif [ -f /etc/default/grub ]; then
    cp -p /etc/default/grub "$AW_STATE_DIR/backups/$AW_RUN_ID/etc-default-grub"
    sed -i 's/[[:space:]]*nomodeset//g' /etc/default/grub
    aw_have grub-mkconfig && grub-mkconfig -o /boot/grub/grub.cfg
  else
    aw_warn "nomodeset is active but the bootloader configuration was not recognized"
  fi
}

aw_install_hardware() {
  aw_hardware_packages
  aw_fix_nomodeset
}

aw_enable_service() {
  service_name=$1
  runlevel=${2:-default}
  if [ -e "/etc/init.d/$service_name" ]; then
    rc-update add "$service_name" "$runlevel" >/dev/null 2>&1 || true
  fi
}

aw_configure_services() {
  aw_enable_service dbus default
  aw_enable_service elogind boot
  aw_enable_service networkmanager default
  aw_enable_service bluetooth default
  aw_enable_service cups default
  aw_enable_service avahi-daemon default
  aw_enable_service nftables default
  aw_enable_service power-profiles-daemon default
  aw_enable_service qemu-guest-agent default

  aw_write_managed /etc/NetworkManager/conf.d/10-alpine-workstation.conf 0644 root:root <<'EOF'
[main]
plugins=keyfile,ifupdown

[ifupdown]
managed=false
EOF

  ssh_firewall_rule=""
  if [ "$AW_SSH_ENABLED" -eq 1 ]; then
    ssh_firewall_rule="    tcp dport 22 accept"
  fi
  aw_write_managed /etc/nftables.nft 0600 root:root <<EOF
#!/usr/sbin/nft -f
flush ruleset

table inet alpine_workstation {
  chain input {
    type filter hook input priority filter; policy drop;
    iifname "lo" accept
    ct state invalid drop
    ct state established,related accept
    ip protocol icmp accept
    ip6 nexthdr ipv6-icmp accept
$ssh_firewall_rule
  }

  chain forward {
    type filter hook forward priority filter; policy drop;
  }

  chain output {
    type filter hook output priority filter; policy accept;
  }
}
EOF

  if [ "$AW_PROFILE" = "balanced" ] && aw_have flatpak; then
    flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi
}

aw_ensure_user() {
  user_created=0
  if ! id "$AW_USER" >/dev/null 2>&1; then
    adduser -D -s /bin/zsh "$AW_USER"
    user_created=1
  fi
  if [ "$user_created" -eq 1 ] || [ "$AW_LIVE_TARGET" -eq 1 ]; then
    aw_print "Set the local password for $AW_USER."
    passwd "$AW_USER"
  fi
  for group_name in wheel audio video input netdev plugdev users lp; do
    if getent group "$group_name" >/dev/null 2>&1; then
      addgroup "$AW_USER" "$group_name" >/dev/null 2>&1 || true
    fi
  done
  user_home=$(awk -F: -v user="$AW_USER" '$1 == user {print $6}' /etc/passwd)
  [ -n "$user_home" ] || aw_die "could not determine home directory for $AW_USER"
  chsh -s /bin/zsh "$AW_USER" >/dev/null 2>&1 || true

  aw_write_managed /etc/doas.d/alpine-workstation.conf 0600 root:root <<'EOF'
permit persist :wheel
EOF

  if [ -n "$AW_SSH_KEY" ]; then
    mkdir -p "$user_home/.ssh"
    chmod 0700 "$user_home/.ssh"
    aw_write_managed "$user_home/.ssh/authorized_keys" 0600 "$AW_USER:$AW_USER" <<EOF
$AW_SSH_KEY
EOF
    chown "$AW_USER:$AW_USER" "$user_home/.ssh"
  fi
}

aw_configure_ssh() {
  if [ "$AW_SSH_ENABLED" -eq 0 ]; then
    rc-update del sshd default >/dev/null 2>&1 || true
    aw_warn "SSH is disabled"
    return 0
  fi
  user_home=$(awk -F: -v user="$AW_USER" '$1 == user {print $6}' /etc/passwd)
  [ -s "$user_home/.ssh/authorized_keys" ] || aw_die "refusing to harden SSH without an administrator authorized_keys file"
  mkdir -p /etc/ssh/sshd_config.d
  ssh_target=/etc/ssh/sshd_config.d/20-alpine-workstation.conf
  if [ -n "${SSH_CONNECTION:-}" ] && [ "$AW_LIVE_TARGET" -ne 1 ]; then
    ssh_target=/etc/ssh/sshd_config.d/20-alpine-workstation.conf.pending
    aw_warn "root SSH hardening is pending; test a second login as $AW_USER, then run: sh install.sh secure-ssh --user $AW_USER"
  fi
  aw_write_managed "$ssh_target" 0600 root:root <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
EOF
  aw_enable_service sshd default
  if [ "$ssh_target" = "/etc/ssh/sshd_config.d/20-alpine-workstation.conf" ]; then
    sshd -t
  fi
}

aw_secure_ssh() {
  [ "$(id -u)" -eq 0 ] || aw_die "secure-ssh must run as root"
  [ -n "$AW_USER" ] || AW_USER=$(aw_default_user)
  [ -n "$AW_USER" ] || aw_die "specify --user NAME"
  user_home=$(awk -F: -v user="$AW_USER" '$1 == user {print $6}' /etc/passwd)
  [ -s "$user_home/.ssh/authorized_keys" ] || aw_die "$AW_USER has no authorized SSH keys"
  pending=/etc/ssh/sshd_config.d/20-alpine-workstation.conf.pending
  active=/etc/ssh/sshd_config.d/20-alpine-workstation.conf
  [ -f "$pending" ] || aw_die "no pending SSH hardening configuration"
  cp "$pending" "$active"
  if ! sshd -t; then
    rm -f "$active"
    aw_die "SSH validation failed; the pending configuration was not activated"
  fi
  rm -f "$pending"
  rc-service sshd reload
  aw_ok "root and password SSH access are disabled"
}

aw_install_oh_my_zsh() {
  user_home=$1
  omz_dir="$user_home/.local/share/oh-my-zsh"
  if [ -d "$omz_dir/.git" ]; then
    if [ -z "$(git -C "$omz_dir" status --porcelain 2>/dev/null)" ]; then
      git -C "$omz_dir" fetch --quiet origin "$AW_OMZ_REVISION"
      git -C "$omz_dir" checkout --quiet "$AW_OMZ_REVISION"
    else
      aw_warn "$omz_dir has local changes; leaving it unchanged"
    fi
  elif [ -e "$omz_dir" ]; then
    aw_warn "$omz_dir already exists and is not managed; Oh My Zsh was not installed"
  else
    mkdir -p "$(dirname "$omz_dir")"
    git clone --quiet https://github.com/ohmyzsh/ohmyzsh.git "$omz_dir"
    git -C "$omz_dir" checkout --quiet "$AW_OMZ_REVISION"
  fi
  chown -R "$AW_USER:$AW_USER" "$user_home/.local"
}

aw_configure_shell() {
  user_home=$(awk -F: -v user="$AW_USER" '$1 == user {print $6}' /etc/passwd)
  mkdir -p "$user_home/.config/zsh" "$user_home/.config/alpine-workstation"
  aw_install_oh_my_zsh "$user_home"

  aw_write_managed "$user_home/.zshrc" 0644 "$AW_USER:$AW_USER" <<'EOF'
export ZSH="$HOME/.local/share/oh-my-zsh"
ZSH_THEME=""
plugins=(git)

source "$HOME/.config/zsh/environment.zsh"
source "$ZSH/oh-my-zsh.sh"
source "$HOME/.config/zsh/core.zsh"
source "$HOME/.config/zsh/tools.zsh"
source "$HOME/.config/zsh/aliases.zsh"
EOF

  aw_write_managed "$user_home/.config/zsh/environment.zsh" 0644 "$AW_USER:$AW_USER" <<'EOF'
export LANG="${LANG:-en_US.UTF-8}"
export EDITOR="${EDITOR:-nvim}"
export VISUAL="$EDITOR"
export PAGER="less"
export LESS="-R"
export GPG_TTY="$(tty 2>/dev/null || true)"
typeset -U path PATH
path=("$HOME/.local/bin" "$HOME/bin" $path)
EOF

  aw_write_managed "$user_home/.config/zsh/core.zsh" 0644 "$AW_USER:$AW_USER" <<'EOF'
autoload -Uz compinit
zmodload zsh/complist
mkdir -p "$HOME/.cache/zsh"
compinit -d "$HOME/.cache/zsh/zcompdump"

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

setopt autocd interactivecomments magicequalsubst notify numericglobsort promptsubst
setopt appendhistory sharehistory hist_expire_dups_first hist_ignore_dups
setopt hist_ignore_space hist_reduce_blanks hist_verify
unsetopt beep

HISTFILE="$HOME/.local/state/zsh/history"
HISTSIZE=10000
SAVEHIST=10000
mkdir -p "${HISTFILE:h}"
WORDCHARS=${WORDCHARS//\/}
PROMPT_EOL_MARK=""
EOF

  aw_write_managed "$user_home/.config/zsh/tools.zsh" 0644 "$AW_USER:$AW_USER" <<'EOF'
export STARSHIP_CONFIG="$HOME/.config/starship.toml"
if [[ "${ALPINE_WORKSTATION_PLAIN:-0}" == "1" ]]; then
  export STARSHIP_CONFIG="$HOME/.config/starship-plain.toml"
fi
command -v starship >/dev/null && eval "$(starship init zsh)"
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border'
EOF

  aw_write_managed "$user_home/.config/zsh/aliases.zsh" 0644 "$AW_USER:$AW_USER" <<'EOF'
alias c='clear'
alias l='eza --all --group-directories-first'
alias ll='eza --all --long --header --git --group-directories-first'
alias tree='eza --tree --group-directories-first'
alias v='nvim'
alias e='$EDITOR'
alias g='git'
alias gst='git status --short --branch'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --decorate --graph -20'
alias i='doas apk add'
alias update='doas apk update && doas apk upgrade'
alias search='apk search'
alias info='apk info'
alias services='rc-status -a'
alias ports='ss -lntup'
alias reload='exec zsh'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
EOF

  aw_write_managed "$user_home/.config/starship.toml" 0644 "$AW_USER:$AW_USER" <<'EOF'
add_newline = true
format = "$os$username$hostname$directory$git_branch$git_status$cmd_duration$line_break$character"

[os]
disabled = false
format = "[$symbol]($style)"
style = "bold #0D597F"

[os.symbols]
Alpine = "  "

[username]
show_always = false
format = "[$user]($style)"
style_user = "bold cyan"

[hostname]
ssh_only = true
format = "[@$hostname]($style) "
style = "bold cyan"

[directory]
truncation_length = 4
truncate_to_repo = false
style = "bold blue"

[git_branch]
symbol = "git:"
style = "bold purple"

[git_status]
style = "yellow"

[cmd_duration]
min_time = 1500
format = " [took $duration]($style)"
style = "dimmed yellow"

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"
EOF

  aw_write_managed "$user_home/.config/starship-plain.toml" 0644 "$AW_USER:$AW_USER" <<'EOF'
add_newline = true
format = "[alpine ](bold blue)$username$hostname$directory$git_branch$git_status$line_break$character"

[hostname]
ssh_only = true
format = "[@$hostname]($style) "

[git_branch]
symbol = "git:"

[character]
success_symbol = ">"
error_symbol = "!"
EOF

  chown -R "$AW_USER:$AW_USER" "$user_home/.config" "$user_home/.zshrc"
}

aw_configure_audio_user() {
  user_home=$(awk -F: -v user="$AW_USER" '$1 == user {print $6}' /etc/passwd)
  for runlevel in gui default; do
    runlevel_dir="$user_home/.config/rc/runlevels/$runlevel"
    mkdir -p "$runlevel_dir"
    for audio_service in pipewire wireplumber pipewire-pulse; do
      if [ -e "/etc/user/init.d/$audio_service" ]; then
        ln -sfn "/etc/user/init.d/$audio_service" "$runlevel_dir/$audio_service"
      fi
    done
  done
  mkdir -p "$user_home/.config/autostart"
  aw_write_managed "$user_home/.config/autostart/pipewire.desktop" 0644 "$AW_USER:$AW_USER" <<'EOF'
[Desktop Entry]
Type=Application
Name=PipeWire compatibility autostart
Hidden=true
EOF
  chown -R "$AW_USER:$AW_USER" "$user_home/.config/rc" "$user_home/.config/autostart"
}

aw_install_fingerprint_helper() {
  aw_write_managed /usr/local/bin/alpine-workstation-fingerprint 0755 root:root <<'EOF'
#!/bin/sh
set -eu

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this helper as the desktop user, not root." >&2
  exit 1
fi

command -v fprintd-enroll >/dev/null 2>&1 || {
  echo "fprintd is not installed." >&2
  exit 1
}

echo "Enrolling a fingerprint for $(id -un). Password login remains available."
fprintd-enroll
fprintd-verify
doas /usr/local/libexec/alpine-workstation-enable-fingerprint
echo "Fingerprint login and unlock are enabled."
EOF

  aw_write_managed /usr/local/libexec/alpine-workstation-enable-fingerprint 0755 root:root <<'EOF'
#!/bin/sh
set -eu

[ "$(id -u)" -eq 0 ] || {
  echo "This helper requires root." >&2
  exit 1
}

for pam_file in /etc/pam.d/gdm-password /etc/pam.d/sddm /etc/pam.d/lightdm /etc/pam.d/swaylock; do
  [ -f "$pam_file" ] || continue
  grep -q 'pam_fprintd.so' "$pam_file" && continue
  cp -p "$pam_file" "$pam_file.alpine-workstation.bak"
  temp_file=$(mktemp)
  awk '
    !inserted && $1 == "auth" {
      print "auth       sufficient   pam_fprintd.so"
      inserted=1
    }
    {print}
    END {
      if (!inserted) print "auth       sufficient   pam_fprintd.so"
    }
  ' "$pam_file" >"$temp_file"
  cat "$temp_file" >"$pam_file"
  chmod 0644 "$pam_file"
  rm -f "$temp_file"
done
EOF
}

aw_configure_fingerprint() {
  if ! aw_detect_fingerprint; then
    aw_info "no fingerprint reader selected or detected"
    return 0
  fi
  aw_apk_add fprintd fprintd-pam linux-pam
  aw_install_fingerprint_helper
  aw_info "after reboot, run alpine-workstation-fingerprint as $AW_USER to enroll and enable login/unlock"
}

aw_prepare_user() {
  aw_write_managed /etc/hostname 0644 root:root <<EOF
$AW_HOSTNAME
EOF
  hostname "$AW_HOSTNAME" 2>/dev/null || true
  aw_write_managed /etc/profile.d/locale.sh 0644 root:root <<'EOF'
export LANG=en_US.UTF-8
export LC_COLLATE=C
EOF
  aw_ensure_user
}

aw_configure_system() {
  aw_configure_services
  aw_configure_ssh
  aw_configure_audio_user
  aw_configure_shell
  aw_configure_fingerprint
}

aw_validate_install() {
  apk audit --system || true
  sshd -t
  nft -c -f /etc/nftables.nft
  id "$AW_USER" >/dev/null
  [ "$(getent passwd "$AW_USER" | cut -d: -f7)" = "/bin/zsh" ] || aw_die "zsh is not the login shell for $AW_USER"
  [ -s "$(getent passwd "$AW_USER" | cut -d: -f6)/.zshrc" ] || aw_die "zsh configuration is missing"
  [ -f /etc/nftables.nft ] || aw_die "firewall configuration is missing"
  case "$AW_DESKTOP" in
    gnome) aw_have gnome-shell ;;
    plasma) aw_have startplasma-wayland ;;
    xfce) aw_have startxfce4 ;;
    sway) aw_have sway ;;
  esac || aw_die "desktop validation failed"
  aw_ok "installation validation passed"
}

aw_save_install_state() {
  aw_state_set AW_VERSION "$AW_VERSION"
  aw_state_set AW_DESKTOP "$AW_DESKTOP"
  aw_state_set AW_PROFILE "$AW_PROFILE"
  aw_state_set AW_USER "$AW_USER"
  aw_state_set AW_HOSTNAME "$AW_HOSTNAME"
  aw_state_set AW_CONTEXT "$AW_CONTEXT"
  aw_state_set AW_SSH_ENABLED "$AW_SSH_ENABLED"
  if [ -n "$AW_EDGE_PACKAGES" ]; then
    edge_csv=$(printf '%s' "$AW_EDGE_PACKAGES" | tr ' ' ',')
    aw_state_set AW_EDGE_PACKAGES_CSV "$edge_csv"
  fi
  aw_state_set AW_INSTALLED_AT "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

aw_run_postinstall() {
  aw_detect_context
  aw_preflight
  aw_start_run
  aw_save_install_state
  aw_run_stage repositories aw_enable_repositories
  aw_run_stage packages aw_install_packages
  aw_run_stage user aw_prepare_user
  aw_run_stage hardware aw_install_hardware
  aw_run_stage desktop aw_install_desktop
  aw_run_stage system aw_configure_system
  aw_run_stage validation aw_validate_install
  aw_print ""
  aw_ok "Alpine Workstation is ready"
  aw_info "log: $AW_LOG_FILE"
  aw_info "reboot to enter $(aw_desktop_label)"
}

aw_shell_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

aw_write_answerfile() {
  answer_file=$1
  user_opts="-a -g audio,video,input,netdev,wheel $AW_USER"
  {
    printf 'KEYMAPOPTS=%s\n' "$(aw_shell_quote 'us us')"
    printf 'HOSTNAMEOPTS=%s\n' "$(aw_shell_quote "$AW_HOSTNAME")"
    printf 'DEVDOPTS=%s\n' "$(aw_shell_quote 'udev')"
    printf 'INTERFACESOPTS=%s\n' "$(aw_shell_quote 'none')"
    printf 'DNSOPTS=%s\n' "$(aw_shell_quote 'none')"
    printf 'TIMEZONEOPTS=%s\n' "$(aw_shell_quote 'UTC')"
    printf 'PROXYOPTS=%s\n' "$(aw_shell_quote 'none')"
    printf 'APKREPOSOPTS=%s\n' "$(aw_shell_quote '-1 -c')"
    printf 'USEROPTS=%s\n' "$(aw_shell_quote "$user_opts")"
    if [ -n "$AW_SSH_KEY" ]; then
      printf 'USERSSHKEY=%s\n' "$(aw_shell_quote "$AW_SSH_KEY")"
    fi
    printf 'SSHDOPTS=%s\n' "$(aw_shell_quote 'openssh')"
    printf 'NTPOPTS=%s\n' "$(aw_shell_quote 'chrony')"
    printf 'DISKOPTS=%s\n' "$(aw_shell_quote 'none')"
    printf 'LBUOPTS=%s\n' "$(aw_shell_quote 'none')"
    printf 'APKCACHEOPTS=%s\n' "$(aw_shell_quote 'none')"
  } >"$answer_file"
  chmod 0600 "$answer_file"
}

aw_confirm_disk_erase() {
  aw_print ""
  aw_error "ALL DATA ON $AW_DISK WILL BE ERASED"
  lsblk -dnpo NAME,SIZE,MODEL,SERIAL "$AW_DISK" 2>/dev/null || true
  printf 'Type the exact device path (%s) to continue: ' "$AW_DISK" >/dev/tty
  IFS= read -r typed_disk </dev/tty || typed_disk=""
  [ "$typed_disk" = "$AW_DISK" ] || aw_die "disk confirmation did not match; nothing was erased"
}

aw_mount_target() {
  mkdir -p /mnt
  if [ "$AW_ENCRYPT" -eq 1 ]; then
    luks_device=$(lsblk -lnpo NAME,FSTYPE "$AW_DISK" | awk '$2 == "crypto_LUKS" {print $1; exit}')
    [ -n "$luks_device" ] || aw_die "could not locate the encrypted root container"
    cryptsetup open "$luks_device" alpine-workstation-root
    vgchange -ay
    root_device=$(lvs --noheadings -o lv_path 2>/dev/null | awk '/lv_root/ {gsub(/^[[:space:]]+/, ""); print; exit}')
  else
    root_device=$(lsblk -bnrpo NAME,FSTYPE,SIZE "$AW_DISK" | awk '$2 == "ext4" && $3 > max {max=$3; dev=$1} END {print dev}')
  fi
  [ -n "${root_device:-}" ] || aw_die "could not locate the installed root filesystem"
  mount "$root_device" /mnt

  boot_device=$(lsblk -bnrpo NAME,FSTYPE,SIZE "$AW_DISK" | awk -v root="$root_device" '$1 != root && ($2 == "vfat" || $2 == "ext4") {if (smallest == 0 || $3 < smallest) {smallest=$3; dev=$1}} END {print dev}')
  if [ -n "$boot_device" ]; then
    boot_type=$(lsblk -dnro FSTYPE "$boot_device")
    if [ "$boot_type" = "vfat" ]; then
      mkdir -p /mnt/boot/efi
      mount "$boot_device" /mnt/boot/efi
    elif [ "$boot_device" != "$root_device" ]; then
      mkdir -p /mnt/boot
      mount "$boot_device" /mnt/boot
    fi
  fi
}

aw_unmount_target() {
  for bind_path in run dev proc sys; do
    umount -l "/mnt/$bind_path" 2>/dev/null || true
  done
  umount /mnt/boot/efi 2>/dev/null || true
  umount /mnt/boot 2>/dev/null || true
  umount /mnt 2>/dev/null || true
  if [ "$AW_ENCRYPT" -eq 1 ]; then
    vgchange -an >/dev/null 2>&1 || true
    cryptsetup close alpine-workstation-root >/dev/null 2>&1 || true
  fi
}

aw_run_live_install() {
  answer_file="/tmp/alpine-workstation-answer.$$"
  aw_write_answerfile "$answer_file"
  aw_confirm_disk_erase
  aw_info "running Alpine base configuration; password prompts come directly from setup-alpine"
  setup-alpine -f "$answer_file"
  rm -f "$answer_file"

  if [ "$AW_ENCRYPT" -eq 1 ]; then
    USE_EFI=$([ -d /sys/firmware/efi ] && printf 1 || printf '') ROOTFS=ext4 setup-disk -e -L -m sys "$AW_DISK"
  else
    USE_EFI=$([ -d /sys/firmware/efi ] && printf 1 || printf '') ROOTFS=ext4 setup-disk -m sys "$AW_DISK"
  fi

  aw_mount_target
  trap 'aw_unmount_target; rmdir "$AW_STATE_DIR/lock" 2>/dev/null || true' EXIT HUP INT TERM
  cp "$0" /mnt/root/alpine-workstation-install.sh
  chmod 0700 /mnt/root/alpine-workstation-install.sh
  for bind_path in dev proc sys run; do
    mkdir -p "/mnt/$bind_path"
    mount --rbind "/$bind_path" "/mnt/$bind_path"
    mount --make-rslave "/mnt/$bind_path" 2>/dev/null || true
  done
  cp /etc/resolv.conf /mnt/etc/resolv.conf

  postinstall_args="_postinstall --defaults --desktop $(aw_shell_quote "$AW_DESKTOP") --profile $(aw_shell_quote "$AW_PROFILE") --user $(aw_shell_quote "$AW_USER") --hostname $(aw_shell_quote "$AW_HOSTNAME") --fingerprint $(aw_shell_quote "$AW_FINGERPRINT")"
  for edge_pkg in $AW_EDGE_PACKAGES; do
    postinstall_args="$postinstall_args --edge-package $(aw_shell_quote "$edge_pkg")"
  done
  if [ "$AW_SSH_ENABLED" -eq 0 ]; then
    postinstall_args="$postinstall_args --ssh-disabled"
  fi
  chroot /mnt /bin/sh -c "AW_LIVE_TARGET=1 AW_CONTEXT_OVERRIDE=installed /bin/sh /root/alpine-workstation-install.sh $postinstall_args"
  aw_unmount_target
  trap 'rmdir "$AW_STATE_DIR/lock" 2>/dev/null || true' EXIT HUP INT TERM
  aw_ok "installation completed on $AW_DISK"
  if aw_confirm "Reboot now" "yes"; then
    reboot
  else
    aw_info "remove the installation media before rebooting"
  fi
}

aw_load_resume_state() {
  [ -r "$AW_STATE_DIR/state.env" ] || aw_die "no saved installation state"
  AW_DESKTOP=$(aw_state_get AW_DESKTOP || printf '%s' "$AW_DESKTOP")
  AW_PROFILE=$(aw_state_get AW_PROFILE || printf '%s' "$AW_PROFILE")
  AW_USER=$(aw_state_get AW_USER || printf '%s' "$AW_USER")
  AW_HOSTNAME=$(aw_state_get AW_HOSTNAME || printf '%s' "$AW_HOSTNAME")
  AW_SSH_ENABLED=$(aw_state_get AW_SSH_ENABLED || printf '%s' "$AW_SSH_ENABLED")
  edge_csv=$(aw_state_get AW_EDGE_PACKAGES_CSV || true)
  if [ -n "$edge_csv" ]; then
    AW_EDGE_PACKAGES=$(printf '%s' "$edge_csv" | tr ',' ' ')
  fi
  if [ "$AW_SSH_ENABLED" -eq 1 ]; then
    user_home=$(awk -F: -v user="$AW_USER" '$1 == user {print $6}' /etc/passwd 2>/dev/null || true)
    if [ -z "$user_home" ] || [ ! -s "$user_home/.ssh/authorized_keys" ]; then
      aw_collect_ssh_key
    fi
  fi
}

aw_install() {
  aw_detect_context
  aw_preflight
  aw_prepare_live_tools
  if [ "$AW_CONTEXT" = "installed" ] && [ -r "$AW_STATE_DIR/state.env" ]; then
    aw_load_resume_state
    AW_DEFAULTS=1
  fi
  aw_collect_inputs
  if [ "$AW_CONTEXT" = "live" ]; then
    aw_start_run
    aw_state_set AW_DESKTOP "$AW_DESKTOP"
    aw_state_set AW_PROFILE "$AW_PROFILE"
    aw_state_set AW_USER "$AW_USER"
    aw_state_set AW_HOSTNAME "$AW_HOSTNAME"
    aw_run_live_install
  else
    aw_run_postinstall
  fi
}

aw_main() {
  aw_parse_args "$@"
  case "$AW_COMMAND" in
    plan) aw_plan ;;
    status) aw_status ;;
    doctor) aw_doctor ;;
    secure-ssh) aw_secure_ssh ;;
    resume)
      aw_load_resume_state
      aw_detect_context
      aw_preflight
      aw_run_postinstall
      ;;
    _postinstall) aw_run_postinstall ;;
    install) aw_install ;;
  esac
}

if [ "${AW_LIBRARY_ONLY:-0}" != "1" ]; then
  aw_main "$@"
fi
