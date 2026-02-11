#!/usr/bin/env bash

CONFIG="$HOME/.config/rofi/search.rasi"
QUICKLINKS_FILE="$HOME/.config/rofi/quicklinks.tsv"
CACHE_DIR="$HOME/.cache/rofi"
HISTORY_FILE="$CACHE_DIR/quicklinks_history.tsv"
STATS_FILE="$CACHE_DIR/quicklinks_stats.tsv"
SEARCH_HISTORY_FILE="$CACHE_DIR/search_history.tsv"
SORT_MODE_FILE="$CACHE_DIR/quicklinks_sort_mode"
TOGGLE_PREFIX="[⭐ Toggle sort:"
DEFAULT_SORT_MODE="frecency"

declare -a LINK_LABELS=()
declare -a LINK_NAMES=()
declare -a LINK_TYPES=()
declare -a LINK_ACTIONS=()
declare -A LINK_INDEX_BY_LABEL=()
declare -A STAT_FREQ_BY_NAME=()
declare -A STAT_LAST_BY_NAME=()

notify_error() {
    local message="$1"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Rofi Search" "$message" -u critical
    else
        printf 'Rofi Search: %s\n' "$message" >&2
    fi
}

notify_success() {
    local message="$1"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Rofi Search" "$message"
    else
        printf 'Rofi Search: %s\n' "$message" >&2
    fi
}

ensure_cache_files() {
    mkdir -p "$CACHE_DIR"
    touch "$HISTORY_FILE" "$STATS_FILE" "$SEARCH_HISTORY_FILE"
}

load_sort_mode() {
    if [[ -f "$SORT_MODE_FILE" ]]; then
        read -r SORT_MODE < "$SORT_MODE_FILE"
    fi

    if [[ "$SORT_MODE" != "frecency" && "$SORT_MODE" != "alpha" ]]; then
        SORT_MODE="$DEFAULT_SORT_MODE"
    fi
}

toggle_sort_mode() {
    if [[ "$SORT_MODE" == "frecency" ]]; then
        SORT_MODE="alpha"
    else
        SORT_MODE="frecency"
    fi
    printf '%s\n' "$SORT_MODE" > "$SORT_MODE_FILE"
}

read_quicklinks() {
    if [[ ! -f "$QUICKLINKS_FILE" ]]; then
        notify_error "Quicklinks file not found: $QUICKLINKS_FILE"
        return 1
    fi

    while IFS=$'\t' read -r emoji name type action; do
        [[ -z "$emoji$name$type$action" ]] && continue
        [[ "$emoji" =~ ^# ]] && continue

        LINK_LABELS+=("${emoji} ${name}")
        LINK_NAMES+=("$name")
        LINK_TYPES+=("$type")
        LINK_ACTIONS+=("$action")
    done < "$QUICKLINKS_FILE"
}

load_stats() {
    while IFS=$'\t' read -r name frequency last_access; do
        [[ -z "$name$frequency$last_access" ]] && continue
        STAT_FREQ_BY_NAME["$name"]="$frequency"
        STAT_LAST_BY_NAME["$name"]="$last_access"
    done < "$STATS_FILE"
}

calculate_frecency() {
    local frequency="$1"
    local last_access="$2"
    local current_time age weight

    current_time=$(date +%s)
    age=$((current_time - last_access))

    if [[ "$age" -lt 3600 ]]; then
        weight=4.0
    elif [[ "$age" -lt 86400 ]]; then
        weight=2.0
    elif [[ "$age" -lt 604800 ]]; then
        weight=0.5
    else
        weight=0.25
    fi

    awk -v f="$frequency" -v w="$weight" 'BEGIN { printf "%.2f", f * w }'
}

get_sorted_labels_frecency() {
    local i name frequency last_access score
    local -a rows=()

    for i in "${!LINK_LABELS[@]}"; do
        name="${LINK_NAMES[$i]}"
        frequency="${STAT_FREQ_BY_NAME[$name]:-0}"
        last_access="${STAT_LAST_BY_NAME[$name]:-0}"

        if [[ "$frequency" -gt 0 && "$last_access" -gt 0 ]]; then
            score=$(calculate_frecency "$frequency" "$last_access")
        else
            score="0.00"
        fi

        rows+=("$(printf '%09.2f|%s' "$score" "${LINK_LABELS[$i]}")")
    done

    [[ "${#rows[@]}" -eq 0 ]] && return 0
    printf '%s\n' "${rows[@]}" | sort -t'|' -k1,1nr -k2,2 | cut -d'|' -f2-
}

get_sorted_labels_alpha() {
    printf '%s\n' "${LINK_LABELS[@]}" | sort
}

build_menu_list() {
    local toggle_line

    if [[ "$SORT_MODE" == "frecency" ]]; then
        toggle_line="$TOGGLE_PREFIX frecency -> alpha]"
        printf '%s\n' "$toggle_line"
        get_sorted_labels_frecency
    else
        toggle_line="$TOGGLE_PREFIX alpha -> frecency]"
        printf '%s\n' "$toggle_line"
        get_sorted_labels_alpha
    fi
}

update_stats() {
    local name="$1"
    local current_time tmp_file

    current_time=$(date +%s)
    tmp_file=$(mktemp)

    awk -F'\t' -v OFS='\t' -v name="$name" -v now="$current_time" '
        $1 == name { $2 = $2 + 1; $3 = now; updated = 1 }
        { print }
        END {
            if (!updated) {
                print name, 1, now
            }
        }
    ' "$STATS_FILE" > "$tmp_file"

    mv "$tmp_file" "$STATS_FILE"
}

log_usage() {
    local name="$1"
    local type="$2"
    local action="$3"
    local timestamp

    timestamp=$(date +%s)
    printf '%s\t%s\t%s\t%s\n' "$timestamp" "$name" "$type" "$action" >> "$HISTORY_FILE"
    update_stats "$name"
}

execute_action() {
    local type="$1"
    local action="$2"

    case "$type" in
        url)
            xdg-open "$action"
            return $?
            ;;
        path)
            local expanded_action="$action"
            local normalized_path

            expanded_action="${expanded_action/#\~/$HOME}"
            expanded_action="${expanded_action//\$HOME/$HOME}"
            normalized_path=$(realpath -m "$expanded_action")

            if [[ -e "$normalized_path" ]]; then
                if command -v zeditor >/dev/null 2>&1; then
                    zeditor "$normalized_path"
                else
                    xdg-open "$normalized_path"
                fi
                return $?
            else
                notify_error "Path not found: $normalized_path"
                return 1
            fi
            ;;
        cmd)
            bash -lc "$action" >/dev/null 2>&1 &
            return 0
            ;;
        *)
            notify_error "Unknown action type: $type"
            return 1
            ;;
    esac
}

urlencode() {
    python3 -c 'import sys; from urllib.parse import quote_plus; print(quote_plus(sys.argv[1]))' "$1"
}

trim_search_history() {
    local current_time tmp_file
    current_time=$(date +%s)
    tmp_file=$(mktemp)

    awk -F'\t' -v now="$current_time" '
        NF >= 4 {
            age = now - $1
            if (age < 3600) {
                weight = 4.0
            } else if (age < 86400) {
                weight = 2.0
            } else if (age < 604800) {
                weight = 0.5
            } else {
                weight = 0.25
            }
            score = $2 * weight
            printf "%.6f\t%010d\t%s\n", score, NR, $0
        }
    ' "$SEARCH_HISTORY_FILE" \
        | sort -t$'\t' -k1,1nr -k2,2n \
        | head -n 25 \
        | cut -f3- > "$tmp_file"

    mv "$tmp_file" "$SEARCH_HISTORY_FILE"
}

save_search_query() {
    local prefix="$1"
    local query="$2"
    local current_time tmp_file

    [[ -z "$prefix" || -z "$query" ]] && return 0

    current_time=$(date +%s)
    tmp_file=$(mktemp)

    awk -F'\t' -v OFS='\t' -v now="$current_time" -v pfx="$prefix" -v qry="$query" '
        $3 == pfx && $4 == qry { $1 = now; $2 = $2 + 1; updated = 1 }
        { print }
        END {
            if (!updated) {
                print now, 1, pfx, qry
            }
        }
    ' "$SEARCH_HISTORY_FILE" > "$tmp_file"

    mv "$tmp_file" "$SEARCH_HISTORY_FILE"
    trim_search_history
}

delete_search_entry() {
    local prefix="$1"
    local query="$2"
    local tmp_file

    [[ -z "$prefix" || -z "$query" ]] && return 0
    tmp_file=$(mktemp)

    awk -F'\t' -v OFS='\t' -v pfx="$prefix" -v qry="$query" '
        !($3 == pfx && $4 == qry) { print }
    ' "$SEARCH_HISTORY_FILE" > "$tmp_file"

    mv "$tmp_file" "$SEARCH_HISTORY_FILE"
}

get_prefix_history_entries() {
    local prefix="$1"
    local current_time
    current_time=$(date +%s)

    awk -F'\t' -v pfx="$prefix" -v now="$current_time" '
        $3 == pfx {
            age = now - $1
            if (age < 3600) {
                weight = 4.0
            } else if (age < 86400) {
                weight = 2.0
            } else if (age < 604800) {
                weight = 0.5
            } else {
                weight = 0.25
            }
            score = $2 * weight
            printf "%.6f\t%010d\t%s\n", score, $1, $4
        }
    ' "$SEARCH_HISTORY_FILE" \
        | sort -t$'\t' -k1,1nr -k2,2nr \
        | cut -f3-
}

show_prefix_history() {
    local prefix="$1"
    local entries selected exit_code

    while true; do
        entries="$(get_prefix_history_entries "$prefix")"
        selected=$(printf '%s' "$entries" | rofi -dmenu -config "$CONFIG" \
            -p "${prefix} " \
            -kb-custom-1 "Alt+1" \
            -theme-str 'entry { placeholder: "Type query or pick from history..."; }')
        exit_code=$?

        if [[ "$exit_code" -eq 10 ]]; then
            [[ -n "$selected" ]] && delete_search_entry "$prefix" "$selected"
            continue
        fi

        if [[ "$exit_code" -ne 0 ]]; then
            printf '\n'
            return 0
        fi

        printf '%s\n' "$selected"
        return 0
    done
}

add_quicklink() {
    local input="$1"
    local raw_name type action
    local emoji name first_char

    IFS='|' read -r raw_name type action <<< "$input"

    raw_name=$(echo "$raw_name" | xargs)
    type=$(echo "$type" | xargs)
    action=$(echo "$action" | xargs)

    if [[ -z "$raw_name" || -z "$type" || -z "$action" ]]; then
        notify_error "Format: add! [emoji] name | type | action"
        return 1
    fi

    if [[ ! "$type" =~ ^(url|path|cmd)$ ]]; then
        notify_error "Type must be: url, path, or cmd"
        return 1
    fi

    first_char="${raw_name%% *}"
    if [[ -n "$first_char" ]] && python3 -c '
import sys, unicodedata
s = sys.argv[1]
if not s:
    raise SystemExit(1)
c = s[0]
cat = unicodedata.category(c)
raise SystemExit(0 if cat == "So" or ord(c) > 0x1F000 else 1)
' "$first_char" 2>/dev/null; then
        emoji="$first_char"
        if [[ "$raw_name" == *" "* ]]; then
            name="${raw_name#* }"
        else
            notify_error "Format: add! [emoji] name | type | action"
            return 1
        fi
    else
        name="$raw_name"
        case "$type" in
            url) emoji="🔗" ;;
            path) emoji="📁" ;;
            cmd) emoji="⚡" ;;
        esac
    fi

    if awk -F'\t' -v n="$name" 'NF >= 2 && !/^#/ && $2 == n { found=1; exit } END { exit found ? 0 : 1 }' "$QUICKLINKS_FILE"; then
        notify_error "Quicklink '$name' already exists"
        return 1
    fi

    printf '%s\t%s\t%s\t%s\n' "$emoji" "$name" "$type" "$action" >> "$QUICKLINKS_FILE"
    notify_success "Added: $emoji $name"
}

rm_quicklink() {
    local input="$1"

    if [[ -n "$input" ]]; then
        local name tmp_file
        name=$(echo "$input" | xargs)

        if ! awk -F'\t' -v n="$name" 'NF >= 2 && !/^#/ && $2 == n { found=1; exit } END { exit found ? 0 : 1 }' "$QUICKLINKS_FILE"; then
            notify_error "Quicklink '$name' not found"
            return 1
        fi

        tmp_file=$(mktemp)
        awk -F'\t' -v OFS='\t' -v n="$name" '!(!/^#/ && NF >= 2 && $2 == n) { print }' "$QUICKLINKS_FILE" > "$tmp_file"
        mv "$tmp_file" "$QUICKLINKS_FILE"
        notify_success "Removed: $name"
    else
        local labels selected selected_name
        labels=$(awk -F'\t' '!/^#/ && NF >= 2 { print $1 " " $2 }' "$QUICKLINKS_FILE")

        if [[ -z "$labels" ]]; then
            notify_error "No quicklinks to remove"
            return 1
        fi

        selected=$(printf '%s\n' "$labels" | rofi -dmenu -config "$CONFIG" \
            -p "rm " \
            -theme-str 'entry { placeholder: "Select quicklink to remove..."; }')

        [[ -z "$selected" ]] && return 0
        selected_name="${selected#* }"
        rm_quicklink "$selected_name"
    fi
}

SORT_MODE="$DEFAULT_SORT_MODE"
ensure_cache_files
load_sort_mode
read_quicklinks || true
load_stats

LIST=$(build_menu_list)

CHOICE=$(echo -e "$LIST" | rofi -dmenu -config "$CONFIG" -p " " -theme-str 'entry { placeholder: "Search, select, add! or rm!"; }')

[[ -z "$CHOICE" ]] && exit 0

if [[ "$CHOICE" =~ ^add!\ (.+)$ ]]; then
    add_quicklink "${BASH_REMATCH[1]}"
    exit 0
fi

if [[ "$CHOICE" == "rm!" ]]; then
    rm_quicklink ""
    exit 0
elif [[ "$CHOICE" =~ ^rm!\ (.+)$ ]]; then
    rm_quicklink "${BASH_REMATCH[1]}"
    exit 0
fi

if [[ "$CHOICE" == "$TOGGLE_PREFIX"* ]]; then
    toggle_sort_mode
    exec "$0"
fi

for i in "${!LINK_LABELS[@]}"; do
    LINK_INDEX_BY_LABEL["${LINK_LABELS[$i]}"]="$i"
done

MATCH_INDEX="${LINK_INDEX_BY_LABEL[$CHOICE]:--1}"

if [[ "$MATCH_INDEX" -ge 0 ]]; then
    if execute_action "${LINK_TYPES[$MATCH_INDEX]}" "${LINK_ACTIONS[$MATCH_INDEX]}"; then
        log_usage "${LINK_NAMES[$MATCH_INDEX]}" "${LINK_TYPES[$MATCH_INDEX]}" "${LINK_ACTIONS[$MATCH_INDEX]}"
    fi
else
    QUERY="$CHOICE"
    QUERY_ENCODED=$(urlencode "$QUERY")
    SEARCH_PREFIX=""
    SEARCH_QUERY=""
    
    case "$QUERY" in
        "y!")
            SEARCH_PREFIX="y!"
            SEARCH_QUERY="$(show_prefix_history "$SEARCH_PREFIX")"
            [[ -z "$SEARCH_QUERY" ]] && exit 0
            SEARCH_TERM=$(urlencode "$SEARCH_QUERY")
            URL="https://www.youtube.com/results?search_query=$SEARCH_TERM"
            ;;
        "y! "*)
            SEARCH_PREFIX="y!"
            SEARCH_QUERY="${QUERY#y! }"
            SEARCH_TERM=$(urlencode "$SEARCH_QUERY")
            URL="https://www.youtube.com/results?search_query=$SEARCH_TERM"
            ;;
        "g!")
            SEARCH_PREFIX="g!"
            SEARCH_QUERY="$(show_prefix_history "$SEARCH_PREFIX")"
            [[ -z "$SEARCH_QUERY" ]] && exit 0
            SEARCH_TERM=$(urlencode "$SEARCH_QUERY")
            URL="https://www.google.com/search?q=$SEARCH_TERM"
            ;;
        "g! "*)
            SEARCH_PREFIX="g!"
            SEARCH_QUERY="${QUERY#g! }"
            SEARCH_TERM=$(urlencode "$SEARCH_QUERY")
            URL="https://www.google.com/search?q=$SEARCH_TERM"
            ;;
        "aw!")
            SEARCH_PREFIX="aw!"
            SEARCH_QUERY="$(show_prefix_history "$SEARCH_PREFIX")"
            [[ -z "$SEARCH_QUERY" ]] && exit 0
            SEARCH_TERM=$(urlencode "$SEARCH_QUERY")
            URL="https://wiki.archlinux.org/index.php?search=$SEARCH_TERM"
            ;;
        "aw! "*)
            SEARCH_PREFIX="aw!"
            SEARCH_QUERY="${QUERY#aw! }"
            SEARCH_TERM=$(urlencode "$SEARCH_QUERY")
            URL="https://wiki.archlinux.org/index.php?search=$SEARCH_TERM"
            ;;
        "au!")
            SEARCH_PREFIX="au!"
            SEARCH_QUERY="$(show_prefix_history "$SEARCH_PREFIX")"
            [[ -z "$SEARCH_QUERY" ]] && exit 0
            SEARCH_TERM=$(urlencode "$SEARCH_QUERY")
            URL="https://aur.archlinux.org/packages?O=0&K=$SEARCH_TERM"
            ;;
        "au! "*)
            SEARCH_PREFIX="au!"
            SEARCH_QUERY="${QUERY#au! }"
            SEARCH_TERM=$(urlencode "$SEARCH_QUERY")
            URL="https://aur.archlinux.org/packages?O=0&K=$SEARCH_TERM"
            ;;
        "gh!")
            SEARCH_PREFIX="gh!"
            SEARCH_QUERY="$(show_prefix_history "$SEARCH_PREFIX")"
            [[ -z "$SEARCH_QUERY" ]] && exit 0
            SEARCH_TERM=$(urlencode "$SEARCH_QUERY")
            URL="https://www.github.com/search?q=$SEARCH_TERM"
            ;;
        "gh! "*)
            SEARCH_PREFIX="gh!"
            SEARCH_QUERY="${QUERY#gh! }"
            SEARCH_TERM=$(urlencode "$SEARCH_QUERY")
            URL="https://www.github.com/search?q=$SEARCH_TERM"
            ;;
        "yt!")
            SEARCH_PREFIX="yt!"
            SEARCH_QUERY="$(show_prefix_history "$SEARCH_PREFIX")"
            [[ -z "$SEARCH_QUERY" ]] && exit 0
            TEXT=$(urlencode "$SEARCH_QUERY")
            URL="https://translate.yandex.com/?source_lang=en&target_lang=ru&text=$TEXT"
            ;;
        "yt! "*)
            SEARCH_PREFIX="yt!"
            SEARCH_QUERY="${QUERY#yt! }"
            TEXT=$(urlencode "$SEARCH_QUERY")
            URL="https://translate.yandex.com/?source_lang=en&target_lang=ru&text=$TEXT"
            ;;
        *)
            URL="https://www.perplexity.ai/search?q=$QUERY_ENCODED"
            ;;
    esac

    if xdg-open "$URL"; then
        if [[ -n "$SEARCH_PREFIX" && -n "$SEARCH_QUERY" ]]; then
            save_search_query "$SEARCH_PREFIX" "$SEARCH_QUERY"
        fi
    fi
fi
