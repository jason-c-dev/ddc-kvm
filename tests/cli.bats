#!/usr/bin/env bats
# CLI behaviour: arguments, config loading, status/list/next, dry-run, notifications.

load test_helper

setup() { common_setup; }

@test "no arguments prints usage and exits 2" {
  run "$DDC_KVM"
  assert_failure 2
  assert_output --partial "Usage: ddc-kvm"
}

@test "--help exits 0 with usage" {
  run "$DDC_KVM" --help
  assert_success
  assert_output --partial "Usage: ddc-kvm"
}

@test "--version prints the version" {
  run "$DDC_KVM" --version
  assert_success
  assert_output --regexp '^ddc-kvm [0-9]+\.[0-9]+\.[0-9]+$'
}

@test "unknown option exits 2" {
  run "$DDC_KVM" --bogus status
  assert_failure 2
  assert_output --partial "unknown option --bogus"
}

@test "unknown machine exits 2 and lists the known names" {
  run "$DDC_KVM" nope
  assert_failure 2
  assert_output --partial 'unknown machine "nope"'
  assert_output --partial "known: mini nuc desktop macbook"
  refute_line --partial "setvcp"
}

@test "missing config exits 3 and names the path and the setup skill" {
  export DDC_KVM_CONFIG="$BATS_TEST_TMPDIR/absent"
  run "$DDC_KVM" status
  assert_failure 3
  assert_output --partial "$BATS_TEST_TMPDIR/absent"
  assert_output --partial "/ddc-kvm:setup"
}

@test "default config path is XDG_CONFIG_HOME/ddc-kvm/config" {
  unset DDC_KVM_CONFIG
  mkdir -p "$XDG_CONFIG_HOME/ddc-kvm"
  cp "$BATS_TEST_TMPDIR/config" "$XDG_CONFIG_HOME/ddc-kvm/config"
  run "$DDC_KVM" --dry-run macbook
  assert_success
  assert_output "ddcutil --bus 9 --noverify setvcp 60 0x11"
}

@test "--config overrides the environment" {
  cp "$DDC_KVM_CONFIG" "$BATS_TEST_TMPDIR/other"
  export DDC_KVM_CONFIG="$BATS_TEST_TMPDIR/absent"
  run "$DDC_KVM" --config "$BATS_TEST_TMPDIR/other" --dry-run macbook
  assert_success
  assert_output "ddcutil --bus 9 --noverify setvcp 60 0x11"
}

@test "bad hex value exits 3 naming the line" {
  printf 'self = a\n[machines]\na = 0x11 A\nb = eleven B\n' >"$DDC_KVM_CONFIG"
  run "$DDC_KVM" list
  assert_failure 3
  assert_output --partial "line 4"
  assert_output --partial 'bad input value "eleven"'
}

@test "self not in machines exits 3" {
  printf 'self = ghost\n[machines]\na = 0x11 A\n' >"$DDC_KVM_CONFIG"
  run "$DDC_KVM" list
  assert_failure 3
  assert_output --partial "self = ghost is not in [machines]"
}

@test "unknown setting exits 3" {
  write_config "colour = blue"
  run "$DDC_KVM" list
  assert_failure 3
  assert_output --partial 'unknown setting "colour"'
}

@test "config without machines exits 3" {
  printf 'connector = DP-1\n' >"$DDC_KVM_CONFIG"
  run "$DDC_KVM" list
  assert_failure 3
  assert_output --partial "no machines defined"
}

@test "comments and blank lines are ignored; hex is normalised" {
  printf '# top\nself = a   # trailing\n\n[machines]\nA = 0XF   Alpha # note\nb = 0x1B  Bravo\n' >"$DDC_KVM_CONFIG"
  run "$DDC_KVM" list
  assert_success
  assert_line --index 0 --regexp '^\*.? *a +0x0f  Alpha$'
  assert_line --index 1 --regexp '^ .? *b +0x1b  Bravo$'
}

@test "list marks self with * and the current input with >" {
  run "$DDC_KVM" list
  assert_success
  assert_line --index 0 --regexp '^   mini +0x19  Mac mini'
  assert_line --index 2 --regexp '^\*> desktop +0x13  Desktop'
  assert_line --index 3 --regexp '^   macbook +0x11  Work MacBook'
}

@test "list still works when the display is unreachable" {
  export FAKE_DETECT="/dev/null"
  run "$DDC_KVM" list
  assert_success
  assert_line --index 2 --regexp '^\*  desktop'
}

@test "status parses ddcutil --brief output" {
  export FAKE_GETVCP="VCP 60 SNC x13"
  run "$DDC_KVM" status
  assert_success
  assert_output "0x13 (19) desktop - Desktop (DisplayPort 2)"
}

@test "status parses the verbose sl= form" {
  export FAKE_GETVCP="VCP code 0x60 (Input Source                  ): Invalid value (sl=0x11)"
  run "$DDC_KVM" status
  assert_success
  assert_line --index 0 "0x11 (17) macbook - Work MacBook (HDMI 1)"
}

@test "status parses the current value form" {
  export FAKE_GETVCP="VCP code 0x60 (Input Source                  ): current value =    15, max value =   255"
  run "$DDC_KVM" status
  assert_success
  assert_line --index 0 "0x0f (15) nuc - NUC (DisplayPort 1)"
}

@test "status reports unknown for an unconfigured value" {
  export FAKE_GETVCP="VCP 60 SNC x1b"
  run "$DDC_KVM" status
  assert_success
  assert_output "0x1b (27) unknown"
}

@test "status notes when the live input disagrees with self" {
  export FAKE_GETVCP="VCP 60 SNC x11"
  run "$DDC_KVM" status
  assert_success
  assert_line --partial "monitor reports macbook but this config says self = desktop"
}

@test "status exits 1 when the read fails" {
  export FAKE_GETVCP="" FAKE_GETVCP_RC=1
  run "$DDC_KVM" status
  assert_failure 1
  assert_output --partial "could not read the current input"
}

@test "switching to self is a no-op when the monitor already shows self" {
  export FAKE_GETVCP="VCP 60 SNC x13"
  run "$DDC_KVM" desktop
  assert_success
  assert_output "ddc-kvm: already on desktop"
  run fake_log
  refute_output --partial "setvcp"
}

@test "switching to self pulls the monitor back when the live input differs" {
  export FAKE_GETVCP="VCP 60 SNC x11"
  run "$DDC_KVM" desktop
  assert_success
  run fake_log
  assert_line "ddcutil --bus 9 --noverify setvcp 60 0x13"
}

@test "switching to self still tries when the current input cannot be read" {
  export FAKE_GETVCP="" FAKE_GETVCP_RC=1
  run "$DDC_KVM" desktop
  assert_success
  run fake_log
  assert_line "ddcutil --bus 9 --noverify setvcp 60 0x13"
}

@test "machine names are case-insensitive on the command line" {
  run "$DDC_KVM" --dry-run MacBook
  assert_success
  assert_output "ddcutil --bus 9 --noverify setvcp 60 0x11"
}

@test "next picks the entry after self and wraps around" {
  run "$DDC_KVM" --dry-run next
  assert_success
  assert_output "ddcutil --bus 9 --noverify setvcp 60 0x11"

  printf 'self = macbook\nconnector = DP-1\n[machines]\nmini = 0x19 A\nmacbook = 0x11 B\n' >"$DDC_KVM_CONFIG"
  run "$DDC_KVM" --dry-run next
  assert_success
  assert_output "ddcutil --bus 9 --noverify setvcp 60 0x19"
}

@test "next without self exits 3" {
  printf '[machines]\na = 0x11 A\nb = 0x12 B\n' >"$DDC_KVM_CONFIG"
  run "$DDC_KVM" next
  assert_failure 3
  assert_output --partial '"next" needs self'
}

@test "--dry-run prints the command and runs nothing" {
  run "$DDC_KVM" --dry-run macbook
  assert_success
  assert_output "ddcutil --bus 9 --noverify setvcp 60 0x11"
  run fake_log
  refute_output --partial "setvcp"
}

@test "a switch sends a notification first, preferring omarchy-notification-send" {
  run "$DDC_KVM" macbook
  assert_success
  run fake_log
  assert_line --index 1 "omarchy-notification-send -u low Switching monitor to Work MacBook (HDMI 1)"
  assert_line --index 2 "ddcutil --bus 9 --noverify setvcp 60 0x11"
}

@test "falls back to notify-send when omarchy-notification-send is absent" {
  minimal_path ddcutil notify-send uname
  run "$DDC_KVM" macbook
  assert_success
  run fake_log
  assert_line --partial "notify-send -u low Switching monitor to"
}

@test "--no-notify suppresses the notification" {
  run "$DDC_KVM" --no-notify macbook
  assert_success
  run fake_log
  refute_output --partial "notification"
  refute_output --partial "notify-send"
}

@test "notify = off in the config suppresses the notification" {
  write_config "notify = off"
  run "$DDC_KVM" macbook
  assert_success
  run fake_log
  refute_output --partial "notification"
}

@test "a failure raises a critical notification so hotkeys are not silent" {
  export FAKE_DETECT="/dev/null"
  run "$DDC_KVM" macbook
  assert_failure 1
  run fake_log
  assert_line --partial "omarchy-notification-send -u critical ddc-kvm failed"
}
