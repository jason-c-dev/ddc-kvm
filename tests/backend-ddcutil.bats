#!/usr/bin/env bats
# ddcutil backend: bus detection, the exact set command, failure handling,
# and platform/backend selection.

load test_helper

setup() { common_setup; }

@test "detects the i2c bus by matching the connector in ddcutil detect output" {
  run "$DDC_KVM" --dry-run macbook
  assert_success
  assert_output "ddcutil --bus 9 --noverify setvcp 60 0x11"
  run fake_log
  assert_line --index 0 "ddcutil --skip-ddc-checks detect --brief"
}

@test "matches a different connector to its own bus" {
  write_config "connector = HDMI-A-1"
  sed -i.bak 's/^connector = DP-1$//' "$DDC_KVM_CONFIG"
  run "$DDC_KVM" --dry-run macbook
  assert_success
  assert_output "ddcutil --bus 5 --noverify setvcp 60 0x11"
}

@test "an unmatched connector exits 1 and names it" {
  sed -i.bak 's/^connector = DP-1$/connector = DP-3/' "$DDC_KVM_CONFIG"
  run "$DDC_KVM" macbook
  assert_failure 1
  assert_output --partial "no DDC/CI display found on connector DP-3"
  run fake_log
  refute_output --partial "setvcp"
}

@test "without a connector the first detected display is used" {
  sed -i.bak 's/^connector = DP-1$//' "$DDC_KVM_CONFIG"
  run "$DDC_KVM" --dry-run macbook
  assert_success
  assert_output "ddcutil --bus 5 --noverify setvcp 60 0x11"
}

@test "no display at all exits 1" {
  export FAKE_DETECT="/dev/null"
  run "$DDC_KVM" macbook
  assert_failure 1
  assert_output --partial "no DDC/CI display found"
}

@test "bus = N in the config skips detection" {
  write_config "bus = 7"
  run "$DDC_KVM" --dry-run macbook
  assert_success
  assert_output "ddcutil --bus 7 --noverify setvcp 60 0x11"
  run fake_log
  refute_output --partial "detect"
}

@test "--bus overrides the config" {
  write_config "bus = 7"
  run "$DDC_KVM" --bus 3 --dry-run macbook
  assert_success
  assert_output "ddcutil --bus 3 --noverify setvcp 60 0x11"
}

@test "--bus rejects non-numbers" {
  run "$DDC_KVM" --bus nine macbook
  assert_failure 2
  assert_output --partial "--bus expects a number"
}

@test "the real set call passes --noverify and the exact value" {
  run "$DDC_KVM" macbook
  assert_success
  run fake_log
  assert_line "ddcutil --bus 9 --noverify setvcp 60 0x11"
}

@test "status reads with getvcp 60 --brief on the detected bus" {
  run "$DDC_KVM" status
  assert_success
  run fake_log
  assert_line "ddcutil --bus 9 getvcp 60 --brief"
}

@test "a failing setvcp exits 1" {
  export FAKE_SETVCP_RC=1
  run "$DDC_KVM" macbook
  assert_failure 1
  assert_output --partial "switch to macbook failed"
}

@test "macOS exits 4 and points at m1ddc" {
  export FAKE_UNAME=Darwin
  run "$DDC_KVM" macbook
  assert_failure 4
  assert_output --partial "macOS is not supported by this version yet"
  assert_output --partial "m1ddc"
}

@test "an unknown platform exits 4" {
  export FAKE_UNAME=FreeBSD
  run "$DDC_KVM" macbook
  assert_failure 4
  assert_output --partial "unsupported platform: FreeBSD"
}

@test "backend = ddcutil in the config bypasses platform detection" {
  export FAKE_UNAME=Darwin
  write_config "backend = ddcutil"
  run "$DDC_KVM" --dry-run macbook
  assert_success
  assert_output "ddcutil --bus 9 --noverify setvcp 60 0x11"
}

@test "an unknown backend exits 3" {
  write_config "backend = magic"
  run "$DDC_KVM" macbook
  assert_failure 3
  assert_output --partial 'unknown backend "magic"'
}

@test "a missing ddcutil exits 4 with install hints" {
  minimal_path uname
  run "$DDC_KVM" macbook
  assert_failure 4
  assert_output --partial "ddcutil is not installed"
}
