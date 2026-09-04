#!/usr/bin/env bash
# Shared setup for the bats suites.
#
# Loads bats-support and bats-assert from wherever they are installed:
#   - BATS_LIB_PATH (set by bats-core/bats-action in CI, or by hand)
#   - /usr/lib (Arch packages bats-support / bats-assert)
#   - /usr/local/lib, /opt/homebrew/lib (Homebrew)

_load_lib() {
  local lib=$1 dir
  for dir in ${BATS_LIB_PATH//:/ } /usr/lib /usr/local/lib /opt/homebrew/lib; do
    if [[ -f "$dir/$lib/load.bash" ]]; then
      # shellcheck disable=SC1090
      source "$dir/$lib/load.bash"
      return 0
    fi
  done
  echo "cannot find $lib; install bats-support and bats-assert or set BATS_LIB_PATH" >&2
  return 1
}
_load_lib bats-support
_load_lib bats-assert

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC2034  # used by the .bats files
DDC_KVM="$REPO_ROOT/scripts/ddc-kvm"
FIXTURES="$REPO_ROOT/tests/fixtures"

# Put the fakes first on PATH, point the CLI at a temp config, and give every
# test a fresh invocation log.
common_setup() {
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export FAKE_LOG="$BATS_TEST_TMPDIR/fake.log"
  export FAKE_DETECT="$FIXTURES/detect-brief.txt"
  unset FAKE_GETVCP FAKE_GETVCP_RC FAKE_SETVCP_RC FAKE_UNAME DDC_KVM_BACKEND
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg"
  export DDC_KVM_CONFIG="$BATS_TEST_TMPDIR/config"
  : >"$FAKE_LOG"
  # shellcheck disable=SC2119
  write_config
}

# write_config [extra settings...] - the standard four-machine config, with
# optional extra scalar lines inserted before [machines].
# shellcheck disable=SC2120
write_config() {
  {
    printf 'self = desktop\nconnector = DP-1\n'
    for line in "$@"; do printf '%s\n' "$line"; done
    cat <<'CFG'

[machines]
mini = 0x19  Mac mini (Thunderbolt 4)
nuc  = 0x0F  NUC (DisplayPort 1)
desktop  = 0x13  Desktop (DisplayPort 2)
macbook = 0x11  Work MacBook (HDMI 1)
CFG
  } >"$DDC_KVM_CONFIG"
}

fake_log() { cat "$FAKE_LOG"; }

# minimal_path [fake...] - replace PATH with one directory holding only the
# coreutils the CLI needs plus the named fakes. Lets a test prove what happens
# when a tool (ddcutil, omarchy-notification-send) is genuinely absent, even on
# a machine where the real one is installed.
minimal_path() {
  local dir="$BATS_TEST_TMPDIR/minimal-path" tool
  mkdir -p "$dir"
  for tool in bash awk tr cat sed grep rm mkdir date; do
    ln -sf "$(command -v "$tool")" "$dir/$tool"
  done
  for tool in "$@"; do
    cp "$REPO_ROOT/tests/fakes/$tool" "$dir/$tool"
  done
  export PATH="$dir"
}
