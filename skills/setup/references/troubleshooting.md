# Troubleshooting

Symptom first, then the check, then the fix.

## `ddcutil detect` finds nothing

- **DDC/CI is off in the monitor's OSD.** Most Dells: Menu → Others → DDC/CI →
  On. Some monitors reset it after a factory reset or firmware update.
- **A dock or MST hub is in the path.** Many docks (and all DP-MST branch
  devices before kernel 5.10 / ddcutil 1.1) drop the DDC channel. Connect the
  cable straight to the GPU to confirm, then decide.
- **i2c permissions.** ddcutil's udev rule (`60-ddcutil-i2c.rules`) tags GPU
  buses so the logged-in seat can use them. Otherwise add the user to the
  `i2c` group and re-login, or check `ls -l /dev/i2c-*`. `ddcutil environment`
  explains what it sees.
- **`i2c-dev` not loaded.** `modprobe i2c-dev`; ddcutil's package usually
  installs a `modules-load.d` entry.
- **NVIDIA proprietary driver.** DDC over DP/HDMI may need
  `Option "RegistryDwords" "RMUseSwI2c=0x01; RMI2cSpeed=100"` in xorg.conf, or
  is simply unavailable on some setups. See ddcutil's NVIDIA notes.
- **Not the active input.** DDC only works from the machine the monitor is
  showing. Switch to it first.

## `detect` finds the display, but `getvcp 60` fails or times out

- Retry once; DDC is slow and flaky by design. ddcutil 2.x retries by itself.
- `ddcutil --sleep-multiplier 2 getvcp 60` if the monitor is consistently slow.
- `ddcutil --bus N` with the bus from `detect` to skip re-detection.
- Check the OSD's DDC/CI switch again; some monitors expose EDID (so `detect`
  works) with DDC/CI disabled.

## `setvcp 60` prints an error but the switch happened

That is the read-back failing because the link dropped. Use `--noverify`.
`ddc-kvm` always does.

## `setvcp 60` returns "Invalid value" and nothing happens

The value is not one this monitor accepts on that input. Re-check with
`ddcutil capabilities` (candidate list) and the vendor table; then try the
other candidates one at a time while watching the OSD.

## The video switches but the keyboard/mouse do not

The USB upstream is not paired with that input in the OSD (Menu → USB, or the
KVM/USB Selection page). Pair each input with exactly one upstream. On Dell,
the Thunderbolt input is implicitly its own upstream.

## The keyboard follows but the video does not

Wrong `0x60` value (a valid input, but not the intended one) or the target
machine is asleep with no signal, so the monitor falls back. Wake the target.

## The hotkey does nothing

- Run the command from a terminal; the CLI prints the error and raises a
  critical desktop notification if a notifier exists.
- `ddc-kvm --dry-run <name>` shows what it would run.
- Compositor `PATH` is not the shell `PATH`; use the absolute script path.
- Hyprland: `hyprctl binds | grep -B7 <description>` confirms the bind is
  live; `hyprctl configerrors` shows parse problems.
- Keyboard in the wrong mode (Keychron-style Mac/Windows switch): F-keys send
  media keys. Use a modifier+letter chord.
- Two machines share a USB upstream, so the "self" that pressed the key is
  not the one the monitor thinks is active. Fix the OSD pairing.

## `ddc-kvm status` says "unknown"

The live value is not in the config. Add it: that value is the input you are
on right now, so it is the one thing you can be sure of.

## After switching away, nothing can switch back

Expected: see `one-way-problem.md`. The other machine needs its own command.

## macOS-specific

- `m1ddc` says "no display": built-in HDMI on M1/base-M2 is unsupported. Use a
  USB-C/Thunderbolt cable, or BetterDisplay.
- Two displays: `m1ddc display list`, then `m1ddc display <n> set input <v>`.
- DDPM occasionally goes stale after sleep; refresh it, or restart it, before
  trusting its screens.

## Useful diagnostics to include in a bug report

```bash
ddcutil --version
ddcutil detect
ddcutil capabilities
ddcutil getvcp 60 --brief
ddc-kvm --version; ddc-kvm list; ddc-kvm --dry-run <name>
```
