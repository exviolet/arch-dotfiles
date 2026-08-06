#!/usr/bin/env bash
set -euo pipefail

# Rofi screenshot manager for Niri screenshots.
# Override these when needed:
#   SCREENSHOT_DIR="$HOME/Other/Screenshots" screenshots.sh
#   SCREENSHOT_MAX_ITEMS=120 screenshots.sh

SCREENSHOT_DIR="${SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"
THEME="${ROFI_SCREENSHOTS_THEME:-$HOME/.config/rofi/menus/screenshots.rasi}"
# Keep the default modest: rofi only shows a few rows, and every extra image icon
# can cost time on launch. Override with SCREENSHOT_MAX_ITEMS when needed.
MAX_ITEMS="${SCREENSHOT_MAX_ITEMS:-50}"

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$@"
    fi
}

mime_type() {
    local file="$1"
    if command -v file >/dev/null 2>&1; then
        file --brief --mime-type "$file" 2>/dev/null && return
    fi

    case "${file,,}" in
        *.png)  printf 'image/png\n' ;;
        *.jpg|*.jpeg) printf 'image/jpeg\n' ;;
        *.webp) printf 'image/webp\n' ;;
        *.gif)  printf 'image/gif\n' ;;
        *)      printf 'application/octet-stream\n' ;;
    esac
}

human_size() {
    local bytes="${1:-0}"

    if (( bytes >= 1073741824 )); then
        printf '%d.%dGiB' "$((bytes / 1073741824))" "$(((bytes % 1073741824) * 10 / 1073741824))"
    elif (( bytes >= 1048576 )); then
        printf '%d.%dMiB' "$((bytes / 1048576))" "$(((bytes % 1048576) * 10 / 1048576))"
    elif (( bytes >= 1024 )); then
        printf '%d.%dKiB' "$((bytes / 1024))" "$(((bytes % 1024) * 10 / 1024))"
    else
        printf '%sB' "$bytes"
    fi
}

choose_screenshot() {
    local rows_file map_file found selection id path
    rows_file=$(mktemp --tmpdir rofi-screenshots.rows.XXXXXX)
    map_file=$(mktemp --tmpdir rofi-screenshots.map.XXXXXX)
    trap 'rm -f "$rows_file" "$map_file"' RETURN

    if [[ ! -d "$SCREENSHOT_DIR" ]]; then
        printf 'Папка скриншотов не найдена: %s\n' "$SCREENSHOT_DIR" | \
            rofi -dmenu -no-custom -p 'Screenshots' -theme "$THEME" >/dev/null || true
        return 1
    fi

    found=0
    while IFS=$'\t' read -r -d '' _ts date_txt bytes file; do
        local id size name
        [[ -f "$file" ]] || continue

        found=$((found + 1))
        id=$(printf '%03d' "$found")
        size=$(human_size "$bytes")
        name="${file##*/}"

        printf '%s\t%s\n' "$id" "$file" >> "$map_file"
        printf '%s  %s  %s  %s\0icon\x1f%s\n' "$id" "$date_txt" "$size" "$name" "$file" >> "$rows_file"

        if [[ "$found" -ge "$MAX_ITEMS" ]]; then
            break
        fi
    done < <(
        find "$SCREENSHOT_DIR" -maxdepth 1 -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \) \
            -printf '%T@\t%Td.%Tm %TH:%TM\t%s\t%p\0' 2>/dev/null | sort -z -nr
    )

    if [[ "$found" -eq 0 ]]; then
        printf 'В %s пока нет скриншотов\n' "$SCREENSHOT_DIR" | \
            rofi -dmenu -no-custom -p 'Screenshots' -theme "$THEME" >/dev/null || true
        return 1
    fi

    selection=$(rofi -dmenu -i -no-custom -p 'Screenshots' -mesg "$SCREENSHOT_DIR" -theme "$THEME" < "$rows_file") || return 1
    [[ -n "$selection" ]] || return 1

    id="${selection%% *}"
    path=$(awk -F '\t' -v id="$id" '$1 == id { print $2; exit }' "$map_file")
    [[ -n "$path" && -f "$path" ]] || return 1
    printf '%s\n' "$path"
}

choose_action() {
    local file="$1"
    printf '%s\0icon\x1f%s\n' 'Открыть' "$file"
    printf '%s\0icon\x1f%s\n' 'Скопировать изображение' 'edit-copy'
    printf '%s\0icon\x1f%s\n' 'Скопировать путь' 'edit-copy'
    printf '%s\0icon\x1f%s\n' 'Показать в Thunar' 'folder'
    printf '%s\0icon\x1f%s\n' 'Удалить в корзину' 'user-trash'
}

confirm_trash() {
    local file="$1"
    local answer
    answer=$(printf 'Нет\nДа, в корзину\n' | \
        rofi -dmenu -i -no-custom -p 'Удалить?' -mesg "$(basename "$file")" -theme "$THEME") || return 1
    [[ "$answer" == 'Да, в корзину' ]]
}

main() {
    local file action mime
    file=$(choose_screenshot) || exit 0

    action=$(choose_action "$file" | \
        rofi -dmenu -i -no-custom -p 'Действие' -mesg "$(basename "$file")" -theme "$THEME") || exit 0

    case "$action" in
        'Открыть')
            nohup xdg-open "$file" >/dev/null 2>&1 &
            ;;
        'Скопировать изображение')
            mime=$(mime_type "$file")
            wl-copy --type "$mime" < "$file"
            notify -i "$file" 'Скриншот скопирован' "$(basename "$file")"
            ;;
        'Скопировать путь')
            printf '%s' "$file" | wl-copy
            notify -i "$file" 'Путь скриншота скопирован' "$file"
            ;;
        'Показать в Thunar')
            if command -v thunar >/dev/null 2>&1; then
                nohup thunar --select "$file" >/dev/null 2>&1 &
            else
                nohup xdg-open "$(dirname "$file")" >/dev/null 2>&1 &
            fi
            ;;
        'Удалить в корзину')
            confirm_trash "$file" || exit 0
            if command -v gio >/dev/null 2>&1; then
                gio trash "$file"
                notify 'Скриншот отправлен в корзину' "$(basename "$file")"
            elif command -v trash-put >/dev/null 2>&1; then
                trash-put "$file"
                notify 'Скриншот отправлен в корзину' "$(basename "$file")"
            else
                notify 'Не удалил скриншот' 'Не найден gio или trash-put'
                exit 1
            fi
            ;;
    esac
}

main "$@"
