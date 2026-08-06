#!/usr/bin/env bash
set -euo pipefail

updater="$HOME/.config/niri/scripts/update-renderer-profile.sh"
active_file="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/niri-renderer-profile-active"
last_notified=""

check_profile() {
    local wanted active
    wanted="$($updater)"
    active="$(<"$active_file" 2>/dev/null || printf 'unknown')"

    if [[ "$wanted" == "$active" ]]; then
        last_notified=""
        return
    fi

    [[ "$wanted" == "$last_notified" ]] && return
    last_notified="$wanted"

    if [[ "$wanted" == "external" ]]; then
        notify-send --urgency=critical \
            "Niri: HDMI подключён" \
            "Для плавной работы нужен renderer NVIDIA. Выйди и снова войди в сессию Niri."
    else
        notify-send --urgency=normal \
            "Niri: внешний монитор отключён" \
            "Сейчас активен renderer NVIDIA. Перелогинься, чтобы вернуться на Intel."
    fi

    if [[ -x "$HOME/.config/quickshell/scripts/sidecarctl" ]]; then
        "$HOME/.config/quickshell/scripts/sidecarctl" renderer >/dev/null 2>&1 || true
    fi
}

check_profile

while IFS= read -r event; do
    [[ -n "$event" ]] || continue
    sleep 0.4
    check_profile
done < <(udevadm monitor --kernel --subsystem-match=drm)