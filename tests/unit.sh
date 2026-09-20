#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
AW_LIBRARY_ONLY=1
export AW_LIBRARY_ONLY
# shellcheck source=install.sh
. "$REPO_ROOT/install.sh"

TESTS=0
FAILURES=0
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT HUP INT TERM

pass() {
  TESTS=$((TESTS + 1))
  printf 'ok %s - %s\n' "$TESTS" "$1"
}

fail() {
  TESTS=$((TESTS + 1))
  FAILURES=$((FAILURES + 1))
  printf 'not ok %s - %s\n' "$TESTS" "$1"
}

assert_true() {
  label=$1
  shift
  if "$@"; then pass "$label"; else fail "$label"; fi
}

assert_false() {
  label=$1
  shift
  if "$@"; then fail "$label"; else pass "$label"; fi
}

assert_contains() {
  label=$1
  haystack=$2
  needle=$3
  case "$haystack" in
    *"$needle"*) pass "$label" ;;
    *) fail "$label" ;;
  esac
}

printf 'TAP version 13\n'

assert_true "valid user name" aw_valid_name alpine_user
assert_false "user name cannot start with a number" aw_valid_name 9user
assert_false "user name rejects spaces" aw_valid_name "daily user"
assert_true "valid hostname" aw_valid_hostname alpine-laptop
assert_false "hostname rejects shell syntax" aw_valid_hostname 'host;reboot'
assert_true "tagged edge community package" aw_valid_edge_package ghostty@edge-community
assert_false "untagged edge package" aw_valid_edge_package ghostty
assert_false "unknown repository tag" aw_valid_edge_package ghostty@edge

quoted=$(aw_shell_quote "it's alpine")
assert_contains "shell quote escapes apostrophes" "$quoted" "'\\''"

AW_CONTEXT_OVERRIDE=live
export AW_CONTEXT_OVERRIDE
aw_detect_context
if [ "$AW_CONTEXT" = "live" ]; then pass "context override selects live"; else fail "context override selects live"; fi
unset AW_CONTEXT_OVERRIDE

if AW_LIBRARY_ONLY=1 AW_RELEASE_OVERRIDE=3.24.2 AW_ARCH_OVERRIDE=x86_64 AW_CONTEXT_OVERRIDE=installed sh -c '. ./install.sh; aw_detect_context; AW_COMMAND=plan; aw_preflight' >/dev/null 2>&1; then
  pass "supported Alpine release passes preflight"
else
  fail "supported Alpine release passes preflight"
fi

if AW_LIBRARY_ONLY=1 AW_RELEASE_OVERRIDE=3.12.12 AW_ARCH_OVERRIDE=x86_64 AW_CONTEXT_OVERRIDE=installed sh -c '. ./install.sh; aw_detect_context; AW_COMMAND=plan; aw_preflight' >/dev/null 2>&1; then
  fail "unsupported Alpine release is rejected"
else
  pass "unsupported Alpine release is rejected"
fi

AW_STATE_DIR="$TEST_TMP/state"
AW_LOG_DIR="$TEST_TMP/log"
AW_RUN_ID='test'
mkdir -p "$AW_STATE_DIR/managed" "$AW_STATE_DIR/backups/$AW_RUN_ID" "$AW_LOG_DIR"
managed_file="$TEST_TMP/config/example.conf"
aw_write_managed "$managed_file" 0644 "$(id -un):$(id -gn)" <<'EOF'
value=one
EOF
first_value=$(cat "$managed_file")
if [ "$first_value" = "value=one" ]; then pass "managed file initial write"; else fail "managed file initial write"; fi

printf '%s\n' 'local=change' >"$managed_file"
aw_write_managed "$managed_file" 0644 "$(id -un):$(id -gn)" <<'EOF'
value=two
EOF
if [ "$(cat "$managed_file")" = "local=change" ]; then pass "managed file preserves local edits"; else fail "managed file preserves local edits"; fi
if [ "$(cat "$managed_file.new")" = "value=two" ]; then pass "managed file writes update candidate"; else fail "managed file writes update candidate"; fi

capture=""
aw_apk_add() { capture="$*"; }
# shellcheck disable=SC2329
aw_detect_gpu() { printf '%s\n' 'VGA compatible controller: Intel Corporation Graphics'; }
aw_hardware_packages
assert_contains "Intel graphics selects Vulkan driver" "$capture" "mesa-vulkan-intel"

capture=""
# shellcheck disable=SC2329
aw_detect_gpu() { printf '%s\n' 'VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI]'; }
aw_hardware_packages
assert_contains "AMD graphics selects RADV driver" "$capture" "mesa-vulkan-ati"

capture=""
# shellcheck disable=SC2329
aw_detect_gpu() { printf '%s\n' '3D controller: NVIDIA Corporation Device'; }
aw_hardware_packages >/dev/null
assert_contains "NVIDIA graphics selects firmware" "$capture" "linux-firmware-nvidia"

AW_FINGERPRINT=no
assert_false "fingerprint no mode skips detection" aw_detect_fingerprint
AW_FINGERPRINT=yes
assert_true "fingerprint yes mode forces support" aw_detect_fingerprint

AW_USER=daily
AW_HOSTNAME=alpine-test
AW_SSH_KEY="ssh-ed25519 AAAATEST daily@example"
answer_file="$TEST_TMP/answerfile"
aw_write_answerfile "$answer_file"
if sh -n "$answer_file"; then pass "answer file is valid shell"; else fail "answer file is valid shell"; fi
if sh -c '. "$1"; test "$HOSTNAMEOPTS" = alpine-test && test "$DISKOPTS" = none' _ "$answer_file"; then
  pass "answer file preserves installer choices"
else
  fail "answer file preserves installer choices"
fi

AW_STATE_DIR="$TEST_TMP/resume"
mkdir -p "$AW_STATE_DIR/stages"
aw_state_set AW_DESKTOP gnome
aw_state_set AW_USER daily
aw_state_set AW_EDGE_PACKAGES_CSV 'ghostty@edge-community,hyfetch@edge-testing'
if [ "$(aw_state_get AW_DESKTOP)" = "gnome" ]; then pass "state returns latest value"; else fail "state returns latest value"; fi
assert_contains "state accepts tagged edge package list" "$(aw_state_get AW_EDGE_PACKAGES_CSV)" "hyfetch@edge-testing"

printf '1..%s\n' "$TESTS"
[ "$FAILURES" -eq 0 ]
