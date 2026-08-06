#!/usr/bin/env bash
set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

LIGHT_THEME="${GTK_LIGHT_THEME:-Graphite}"
DARK_THEME="${GTK_DARK_THEME:-Graphite-Dark}"
LIGHT_ICON_THEME="${GTK_LIGHT_ICON_THEME:-Papirus-Light}"
DARK_ICON_THEME="${GTK_DARK_ICON_THEME:-Papirus}"
COLOR_SCHEME_LIGHT="prefer-light"
COLOR_SCHEME_DARK="prefer-dark"

ROFI_THEME_DIR="$CONFIG_HOME/rofi/themes"
WAYBAR_THEME_DIR="$CONFIG_HOME/waybar/themes"
SWAYNC_THEME_DIR="$CONFIG_HOME/swaync/themes"
ALACRITTY_THEME_DIR="$CONFIG_HOME/alacritty/themes"
TMUX_THEME_DIR="$CONFIG_HOME/tmux/themes"
P10K_THEME_DIR="$CONFIG_HOME/zsh/p10k-themes"

WALLPAPER_DIR="$CONFIG_HOME/wallpapers"
LIGHT_WALLPAPER="${LIGHT_WALLPAPER:-$WALLPAPER_DIR/_.jpeg}"
DARK_WALLPAPER="${DARK_WALLPAPER:-$WALLPAPER_DIR/solid-dark.png}"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [toggle|light|dark|status]

Switches the desktop color mode between:
  light: $LIGHT_THEME / $LIGHT_ICON_THEME / $COLOR_SCHEME_LIGHT
  dark:  $DARK_THEME / $DARK_ICON_THEME / $COLOR_SCHEME_DARK

Also updates rofi, Waybar, swaync, Alacritty, Herdr, tmux and Powerlevel10k.
USAGE
}

settings_get() {
  gsettings get org.gnome.desktop.interface "$1" 2>/dev/null | sed "s/^'//; s/'$//"
}

current_theme() {
  settings_get gtk-theme || true
}

current_scheme() {
  settings_get color-scheme || true
}

update_settings_ini() {
  local file="$1"
  local theme="$2"
  local icon_theme="$3"
  local prefer_dark="$4"

  mkdir -p "$(dirname "$file")"

  python3 - "$file" "$theme" "$icon_theme" "$prefer_dark" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1]).expanduser()
theme, icon, prefer_dark = sys.argv[2:5]

if path.exists():
    lines = path.read_text().splitlines()
else:
    lines = ["[Settings]"]

if not any(line.strip() == "[Settings]" for line in lines):
    lines.insert(0, "[Settings]")

def set_key(key: str, value: str) -> None:
    prefix = key + "="
    for i, line in enumerate(lines):
        if line.startswith(prefix):
            lines[i] = f"{key}={value}"
            return
    lines.append(f"{key}={value}")

set_key("gtk-theme-name", theme)
set_key("gtk-icon-theme-name", icon)
set_key("gtk-application-prefer-dark-theme", prefer_dark)
path.write_text("\n".join(lines) + "\n")
PY
}

update_gtkrc_2() {
  local file="$HOME/.gtkrc-2.0"
  local theme="$1"
  local icon_theme="$2"

  [ -e "$file" ] || return 0

  python3 - "$file" "$theme" "$icon_theme" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1]).expanduser()
theme, icon = sys.argv[2:4]
lines = path.read_text().splitlines()

def set_key(key: str, value: str) -> None:
    prefix = key + "="
    rendered = f'{key}="{value}"'
    for i, line in enumerate(lines):
        if line.startswith(prefix):
            lines[i] = rendered
            return
    lines.append(rendered)

set_key("gtk-theme-name", theme)
set_key("gtk-icon-theme-name", icon)
path.write_text("\n".join(lines) + "\n")
PY
}

update_xsettingsd() {
  local file="$CONFIG_HOME/xsettingsd/xsettingsd.conf"
  local theme="$1"
  local icon_theme="$2"

  [ -e "$file" ] || return 0

  python3 - "$file" "$theme" "$icon_theme" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1]).expanduser()
theme, icon = sys.argv[2:4]
lines = path.read_text().splitlines()

def set_key(key: str, value: str) -> None:
    prefix = key + " "
    rendered = f'{key} "{value}"'
    for i, line in enumerate(lines):
        if line.startswith(prefix):
            lines[i] = rendered
            return
    lines.append(rendered)

set_key("Net/ThemeName", theme)
set_key("Net/IconThemeName", icon)
path.write_text("\n".join(lines) + "\n")
PY

  if pgrep -x xsettingsd >/dev/null 2>&1; then
    pkill -HUP xsettingsd || true
  fi
}

link_current_theme() {
  local dir="$1"
  local target="$2"
  local link_name="$3"

  [ -d "$dir" ] || return 0
  [ -e "$dir/$target" ] || return 0
  ln -sfn "$target" "$dir/$link_name"
}

update_theme_links() {
  local mode="$1"

  link_current_theme "$ROFI_THEME_DIR" "$mode.rasi" "current.rasi"
  link_current_theme "$WAYBAR_THEME_DIR" "$mode.css" "current.css"
  link_current_theme "$SWAYNC_THEME_DIR" "$mode.css" "current.css"
  link_current_theme "$ALACRITTY_THEME_DIR" "$mode.toml" "current.toml"
  link_current_theme "$TMUX_THEME_DIR" "$mode.tmux" "current.tmux"
  link_current_theme "$P10K_THEME_DIR" "$mode.zsh" "current.zsh"
}

set_wallpaper() {
  local mode="$1"
  local wallpaper=""

  case "$mode" in
    light) wallpaper="$LIGHT_WALLPAPER" ;;
    dark) wallpaper="$DARK_WALLPAPER" ;;
  esac

  [ -n "$wallpaper" ] || return 0
  [ -f "$wallpaper" ] || return 0
  command -v awww >/dev/null 2>&1 || return 0

  awww img "$wallpaper" --transition-type=wipe --transition-angle=30 --transition-fps=165 >/dev/null 2>&1 || true
}

reload_apps() {
  touch "$CONFIG_HOME/alacritty/alacritty.toml" 2>/dev/null || true
  touch "$CONFIG_HOME/waybar/style.css" 2>/dev/null || true
  touch "$CONFIG_HOME/swaync/style.css" 2>/dev/null || true

  if pgrep -x waybar >/dev/null 2>&1; then
    pkill -SIGUSR2 waybar || true
  fi

  if command -v swaync-client >/dev/null 2>&1; then
    swaync-client -rs >/dev/null 2>&1 || true
    swaync-client -R >/dev/null 2>&1 || true
  fi

  if command -v alacritty >/dev/null 2>&1; then
    alacritty msg config -r >/dev/null 2>&1 || true
  fi

  if command -v herdr >/dev/null 2>&1; then
    herdr server reload-config >/dev/null 2>&1 || true
  fi

  if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "$CONFIG_HOME/tmux/tmux.conf" >/dev/null 2>&1 || true
    tmux display-message "Theme switched" >/dev/null 2>&1 || true
  fi
}

apply_theme() {
  local mode="$1"
  local theme icon_theme scheme prefer_dark label

  case "$mode" in
    light)
      theme="$LIGHT_THEME"
      icon_theme="$LIGHT_ICON_THEME"
      scheme="$COLOR_SCHEME_LIGHT"
      prefer_dark=0
      label="Light"
      ;;
    dark)
      theme="$DARK_THEME"
      icon_theme="$DARK_ICON_THEME"
      scheme="$COLOR_SCHEME_DARK"
      prefer_dark=1
      label="Dark"
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac

  gsettings set org.gnome.desktop.interface gtk-theme "$theme"
  gsettings set org.gnome.desktop.interface icon-theme "$icon_theme"
  gsettings set org.gnome.desktop.interface color-scheme "$scheme"

  update_settings_ini "$CONFIG_HOME/gtk-3.0/settings.ini" "$theme" "$icon_theme" "$prefer_dark"
  update_settings_ini "$CONFIG_HOME/gtk-4.0/settings.ini" "$theme" "$icon_theme" "$prefer_dark"
  update_gtkrc_2 "$theme" "$icon_theme"
  update_xsettingsd "$theme" "$icon_theme"
  update_theme_links "$mode"
  set_wallpaper "$mode"
  reload_apps

  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Desktop theme" "$label theme: $theme" --icon=preferences-desktop-theme >/dev/null 2>&1 || true
  fi

  printf '%s theme enabled: %s / %s (%s)\n' "$label" "$theme" "$icon_theme" "$scheme"
}

show_status() {
  printf 'gtk-theme=%s\n' "$(current_theme)"
  printf 'icon-theme=%s\n' "$(settings_get icon-theme || true)"
  printf 'color-scheme=%s\n' "$(current_scheme)"
  if command -v herdr >/dev/null 2>&1; then
    printf 'herdr-theme='
    herdr config check >/dev/null 2>&1 && printf 'auto (host terminal)\n' || printf 'invalid config\n'
  fi
  for item in \
    "$ROFI_THEME_DIR/current.rasi" \
    "$WAYBAR_THEME_DIR/current.css" \
    "$SWAYNC_THEME_DIR/current.css" \
    "$ALACRITTY_THEME_DIR/current.toml" \
    "$TMUX_THEME_DIR/current.tmux" \
    "$P10K_THEME_DIR/current.zsh"; do
    if [ -L "$item" ]; then
      printf '%s -> %s\n' "$item" "$(readlink "$item")"
    elif [ -e "$item" ]; then
      printf '%s exists but is not a symlink\n' "$item"
    else
      printf '%s missing\n' "$item"
    fi
  done
  if command -v awww >/dev/null 2>&1; then
    awww query 2>/dev/null || true
  fi
}

cmd="${1:-toggle}"
case "$cmd" in
  toggle)
    theme="$(current_theme)"
    scheme="$(current_scheme)"
    if [[ "$theme" == "$DARK_THEME" || "$scheme" == "$COLOR_SCHEME_DARK" ]]; then
      apply_theme light
    else
      apply_theme dark
    fi
    ;;
  light|dark)
    apply_theme "$cmd"
    ;;
  status)
    show_status
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
