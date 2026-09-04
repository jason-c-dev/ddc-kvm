# Binding ddc-kvm to hotkeys

Use the absolute path (`/home/<user>/.local/bin/ddc-kvm`) in compositor and
desktop configs; their `PATH` is often not the user's shell `PATH`. One key per
remote machine. Always check for collisions first.

## Hyprland on Omarchy

Bindings live in `~/.config/hypr/bindings.lua`, loaded after the distro
defaults. Never edit `/usr/share/omarchy`.

```bash
omarchy menu keybindings --print | grep -E "SUPER CTRL \+ [A-Z]"   # what is taken
```

```lua
-- ~/.config/hypr/bindings.lua
o.bind("SUPER + CTRL + M", "Monitor to MacBook", "/home/user/.local/bin/ddc-kvm macbook")
o.bind("SUPER + CTRL + ALT + S", "Monitor to NUC", "/home/user/.local/bin/ddc-kvm nuc")
```

If a key is already bound, unbind it first: `hl.unbind("SUPER + CTRL + M")`.
Hyprland reloads on save; validate anyway:

```bash
hyprctl reload && hyprctl configerrors
hyprctl binds | grep -B7 "Monitor to"
```

Optional extras on Omarchy: an entry in
`~/.config/omarchy/extensions/omarchy-menu.jsonc` (hot-reloads), or a bar
widget plugin under `~/.config/omarchy/plugins/`.

**Keyboard mode trap:** some keyboards (Keychron with a Mac/Windows switch)
send media keys on the F-row in Mac mode, so F-key binds silently never fire.
Prefer modifier+letter chords.

## Hyprland (plain hyprland.conf)

```ini
bind = SUPER CTRL, M, exec, /home/user/.local/bin/ddc-kvm macbook
```

## Sway / i3

```
bindsym $mod+Ctrl+m exec /home/user/.local/bin/ddc-kvm macbook
```

## GNOME

Settings → Keyboard → Keyboard Shortcuts → Custom Shortcuts → `+`, command
`/home/user/.local/bin/ddc-kvm macbook`. Or from a terminal:

```bash
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
  "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ddckvm0/']"
P=org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ddckvm0/
gsettings set $P name 'Monitor to MacBook'
gsettings set $P command '/home/user/.local/bin/ddc-kvm macbook'
gsettings set $P binding '<Super><Control>m'
```

## KDE Plasma

System Settings → Shortcuts → Custom Shortcuts (or Add Command), or a `.desktop`
file in `~/.local/share/applications/` with `X-KDE-Shortcuts`, then assign the
key in System Settings → Shortcuts.

## macOS (for the return trip)

**Raycast** script command (`~/raycast-scripts/monitor-to-linux.sh`):

```bash
#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Monitor to Linux
# @raycast.mode silent
/opt/homebrew/bin/m1ddc set input 19
```

Then assign a hotkey to it in Raycast.

**Hammerspoon** (`~/.hammerspoon/init.lua`):

```lua
hs.hotkey.bind({"cmd", "ctrl"}, "L", function()
  hs.execute("/opt/homebrew/bin/m1ddc set input 19")
end)
```

**skhd** (`~/.config/skhd/skhdrc`): `cmd + ctrl - l : /opt/homebrew/bin/m1ddc set input 19`

**Shortcuts.app**: new shortcut → Run Shell Script → the same command; give it
a keyboard shortcut under its details, or pin it to the menu bar.

**DDPM**: its main screen has a "Hotkey" field per input, if the user prefers
Dell's app.

## Choosing keys

- Pick one chord family and stay in it, e.g. `Super+Ctrl+<letter>` with a
  mnemonic letter per machine.
- Avoid the F-row (keyboard mode traps) and single-modifier keys.
- Keep the most-used destination on the easiest chord.
- Show the user the final table: key → machine → command.
