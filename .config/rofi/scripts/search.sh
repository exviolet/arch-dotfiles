#!/usr/bin/env bash

CONFIG="$HOME/.config/rofi/search.rasi"
QUICKLINKS_FILE="$HOME/.config/rofi/quicklinks.tsv"
SEARCH_GROUPS_FILE="$HOME/.config/rofi/search_groups.tsv"
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
declare -A SEARCH_GROUP_EMOJI=()
declare -A SEARCH_GROUP_NAME=()
declare -A SEARCH_GROUP_URL_TEMPLATE=()
declare -A SEARCH_GROUP_BASE_URL=()
declare -A SEARCH_GROUP_SUBS=()
declare -A SEARCH_GROUP_COUNT=()

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

ensure_search_groups_file() {
    touch "$SEARCH_GROUPS_FILE"
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

resolve_quicklink_identity() {
    local raw_name="$1"
    local type="$2"
    local first_char

    QUICKLINK_EMOJI=""
    QUICKLINK_NAME=""

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
        QUICKLINK_EMOJI="$first_char"
        if [[ "$raw_name" == *" "* ]]; then
            QUICKLINK_NAME="${raw_name#* }"
        else
            return 1
        fi
    else
        QUICKLINK_NAME="$raw_name"
        case "$type" in
            url) QUICKLINK_EMOJI="🔗" ;;
            path) QUICKLINK_EMOJI="📁" ;;
            cmd) QUICKLINK_EMOJI="⚡" ;;
            *) return 1 ;;
        esac
    fi

    [[ -n "$QUICKLINK_NAME" ]]
}

load_search_groups() {
    local prefix sub emoji name url_template base_url key

    if [[ ! -f "$SEARCH_GROUPS_FILE" ]]; then
        return 0
    fi

    while IFS=$'\t' read -r prefix sub emoji name url_template base_url; do
        [[ -z "$prefix$sub$emoji$name$url_template$base_url" ]] && continue
        [[ "$prefix" =~ ^# ]] && continue
        [[ -z "$prefix" || -z "$sub" || -z "$url_template" || -z "$base_url" ]] && continue

        key="${prefix}:${sub}"
        SEARCH_GROUP_EMOJI["$key"]="$emoji"
        SEARCH_GROUP_NAME["$key"]="$name"
        SEARCH_GROUP_URL_TEMPLATE["$key"]="$url_template"
        SEARCH_GROUP_BASE_URL["$key"]="$base_url"

        if [[ -z "${SEARCH_GROUP_SUBS[$prefix]}" ]]; then
            SEARCH_GROUP_SUBS["$prefix"]="$sub"
        else
            SEARCH_GROUP_SUBS["$prefix"]+=" $sub"
        fi
        SEARCH_GROUP_COUNT["$prefix"]=$(( ${SEARCH_GROUP_COUNT["$prefix"]:-0} + 1 ))
    done < "$SEARCH_GROUPS_FILE"
}

search_group_key_exists() {
    local prefix="$1"
    local sub="$2"
    local key="${prefix}:${sub}"
    [[ -n "${SEARCH_GROUP_URL_TEMPLATE[$key]}" ]]
}

get_default_sub() {
    local prefix="$1"
    local key="${prefix}:s"
    local first_sub

    if [[ -n "${SEARCH_GROUP_URL_TEMPLATE[$key]}" ]]; then
        printf 's\n'
        return 0
    fi

    first_sub="${SEARCH_GROUP_SUBS[$prefix]%% *}"
    printf '%s\n' "$first_sub"
}

is_group() {
    local prefix="$1"
    [[ "${SEARCH_GROUP_COUNT[$prefix]:-0}" -gt 1 ]]
}

show_group_menu() {
    local prefix="$1"
    local sub key emoji name label selected
    local -a labels=()
    declare -A label_to_sub=()

    for sub in ${SEARCH_GROUP_SUBS[$prefix]}; do
        key="${prefix}:${sub}"
        emoji="${SEARCH_GROUP_EMOJI[$key]}"
        name="${SEARCH_GROUP_NAME[$key]}"
        label="${emoji} ${name} (${sub})"
        labels+=("$label")
        label_to_sub["$label"]="$sub"
    done

    [[ "${#labels[@]}" -eq 0 ]] && return 1

    selected=$(printf '%s\n' "${labels[@]}" | rofi -dmenu -config "$CONFIG" \
        -p "${prefix}! " \
        -theme-str 'entry { placeholder: "Select service..."; }')

    [[ -z "$selected" ]] && return 1
    printf '%s\n' "${label_to_sub[$selected]}"
}

open_base_url() {
    local prefix="$1"
    local sub="$2"
    local key="${prefix}:${sub}"
    local base_url="${SEARCH_GROUP_BASE_URL[$key]}"

    if [[ -z "$base_url" ]]; then
        notify_error "Unknown search target: ${prefix}:${sub}"
        return 1
    fi

    xdg-open "$base_url"
}

execute_search() {
    local prefix="$1"
    local sub="$2"
    local query="$3"
    local key="${prefix}:${sub}"
    local template="${SEARCH_GROUP_URL_TEMPLATE[$key]}"
    local encoded url

    if [[ -z "$template" ]]; then
        notify_error "Unknown search target: ${prefix}:${sub}"
        return 1
    fi

    encoded=$(urlencode "$query")
    url="${template//%s/$encoded}"

    if xdg-open "$url"; then
        save_search_query "$prefix" "$query"
        return 0
    fi

    return 1
}

add_quicklink() {
    local input="$1"
    local raw_name type action
    local emoji name

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

    if ! resolve_quicklink_identity "$raw_name" "$type"; then
        notify_error "Format: add! [emoji] name | type | action"
        return 1
    fi
    emoji="$QUICKLINK_EMOJI"
    name="$QUICKLINK_NAME"

    if awk -F'\t' -v n="$name" 'NF >= 2 && !/^#/ && $2 == n { found=1; exit } END { exit found ? 0 : 1 }' "$QUICKLINKS_FILE"; then
        notify_error "Quicklink '$name' already exists"
        return 1
    fi

    printf '%s\t%s\t%s\t%s\n' "$emoji" "$name" "$type" "$action" >> "$QUICKLINKS_FILE"
    notify_success "Added: $emoji $name"
}

edit_quicklink() {
    local input="$1"
    local raw_name type action
    local emoji name tmp_file

    IFS='|' read -r raw_name type action <<< "$input"

    raw_name=$(echo "$raw_name" | xargs)
    type=$(echo "$type" | xargs)
    action=$(echo "$action" | xargs)

    if [[ -z "$raw_name" || -z "$type" || -z "$action" ]]; then
        notify_error "Format: edit! [emoji] name | type | action"
        return 1
    fi

    if [[ ! "$type" =~ ^(url|path|cmd)$ ]]; then
        notify_error "Type must be: url, path, or cmd"
        return 1
    fi

    if ! resolve_quicklink_identity "$raw_name" "$type"; then
        notify_error "Format: edit! [emoji] name | type | action"
        return 1
    fi
    emoji="$QUICKLINK_EMOJI"
    name="$QUICKLINK_NAME"

    if ! awk -F'\t' -v n="$name" 'NF >= 2 && !/^#/ && $2 == n { found=1; exit } END { exit found ? 0 : 1 }' "$QUICKLINKS_FILE"; then
        notify_error "Quicklink '$name' not found"
        return 1
    fi

    tmp_file=$(mktemp)
    awk -F'\t' -v OFS='\t' -v n="$name" -v e="$emoji" -v t="$type" -v a="$action" '
        !/^#/ && NF >= 2 && $2 == n { $1 = e; $2 = n; $3 = t; $4 = a }
        { print }
    ' "$QUICKLINKS_FILE" > "$tmp_file"
    mv "$tmp_file" "$QUICKLINKS_FILE"

    notify_success "Updated: $emoji $name"
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

add_search_group() {
    local input="$1"
    local prefix sub name url_template base_url

    IFS='|' read -r prefix sub name url_template base_url <<< "$input"

    prefix=$(echo "$prefix" | xargs)
    sub=$(echo "$sub" | xargs)
    name=$(echo "$name" | xargs)
    url_template=$(echo "$url_template" | xargs)
    base_url=$(echo "$base_url" | xargs)

    if [[ -z "$prefix" || -z "$sub" || -z "$name" || -z "$url_template" || -z "$base_url" ]]; then
        notify_error "Format: padd! prefix | sub | name | url_template | base_url"
        return 1
    fi

    if [[ ! "$prefix" =~ ^[a-z]+$ ]]; then
        notify_error "Prefix must match: [a-z]+"
        return 1
    fi

    if [[ ! "$sub" =~ ^[a-z0-9]+$ ]]; then
        notify_error "Sub must match: [a-z0-9]+"
        return 1
    fi

    if [[ "$url_template" != *"%s"* ]]; then
        notify_error "url_template must contain %s"
        return 1
    fi

    if [[ ! "$base_url" =~ ^https?:// ]]; then
        notify_error "base_url must start with http/https"
        return 1
    fi

    if awk -F'\t' -v p="$prefix" -v s="$sub" '!/^#/ && NF >= 2 && $1 == p && $2 == s { found=1; exit } END { exit found ? 0 : 1 }' "$SEARCH_GROUPS_FILE"; then
        notify_error "Prefix '${prefix}:${sub}' already exists"
        return 1
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$prefix" "$sub" "$name" "$url_template" "$base_url" >> "$SEARCH_GROUPS_FILE"
    notify_success "Added prefix: ${prefix}:${sub} -> $name"
}

rm_search_group() {
    local input="$1"
    local key prefix sub tmp_file selected label
    local -a labels=()
    declare -A label_to_key=()

    input=$(echo "$input" | xargs)

    if [[ -z "$input" ]]; then
        while IFS=$'\t' read -r prefix sub name _ _; do
            [[ -z "$prefix$sub" ]] && continue
            [[ "$prefix" =~ ^# ]] && continue
            key="${prefix}:${sub}"
            label="${key} ${name}"
            labels+=("$label")
            label_to_key["$label"]="$key"
        done < "$SEARCH_GROUPS_FILE"

        if [[ "${#labels[@]}" -eq 0 ]]; then
            notify_error "No prefix groups to remove"
            return 1
        fi

        selected=$(printf '%s\n' "${labels[@]}" | rofi -dmenu -config "$CONFIG" \
            -p "prm " \
            -theme-str 'entry { placeholder: "Select prefix:sub to remove..."; }')
        [[ -z "$selected" ]] && return 0
        rm_search_group "${label_to_key[$selected]}"
        return $?
    fi

    tmp_file=$(mktemp)
    if [[ "$input" == *:* ]]; then
        prefix="${input%%:*}"
        sub="${input##*:}"

        if ! awk -F'\t' -v p="$prefix" -v s="$sub" '!/^#/ && NF >= 2 && $1 == p && $2 == s { found=1; exit } END { exit found ? 0 : 1 }' "$SEARCH_GROUPS_FILE"; then
            rm -f "$tmp_file"
            notify_error "Prefix '${prefix}:${sub}' not found"
            return 1
        fi

        awk -F'\t' -v OFS='\t' -v p="$prefix" -v s="$sub" '!(!/^#/ && NF >= 2 && $1 == p && $2 == s) { print }' "$SEARCH_GROUPS_FILE" > "$tmp_file"
        mv "$tmp_file" "$SEARCH_GROUPS_FILE"
        notify_success "Removed prefix: ${prefix}:${sub}"
    else
        prefix="$input"

        if ! awk -F'\t' -v p="$prefix" '!/^#/ && NF >= 1 && $1 == p { found=1; exit } END { exit found ? 0 : 1 }' "$SEARCH_GROUPS_FILE"; then
            rm -f "$tmp_file"
            notify_error "Prefix '$prefix' not found"
            return 1
        fi

        awk -F'\t' -v OFS='\t' -v p="$prefix" '!(!/^#/ && NF >= 1 && $1 == p) { print }' "$SEARCH_GROUPS_FILE" > "$tmp_file"
        mv "$tmp_file" "$SEARCH_GROUPS_FILE"
        notify_success "Removed all groups for prefix: $prefix"
    fi
}

edit_search_group() {
    local input="$1"
    local key prefix sub name url_template base_url tmp_file

    IFS='|' read -r key name url_template base_url <<< "$input"

    key=$(echo "$key" | xargs)
    name=$(echo "$name" | xargs)
    url_template=$(echo "$url_template" | xargs)
    base_url=$(echo "$base_url" | xargs)

    if [[ -z "$key" || -z "$name" || -z "$url_template" || -z "$base_url" ]]; then
        notify_error "Format: pedit! prefix:sub | name | url_template | base_url"
        return 1
    fi

    prefix="${key%%:*}"
    sub="${key##*:}"
    if [[ -z "$prefix" || -z "$sub" || "$key" != *:* ]]; then
        notify_error "Format: pedit! prefix:sub | name | url_template | base_url"
        return 1
    fi

    if [[ ! "$prefix" =~ ^[a-z]+$ ]]; then
        notify_error "Prefix must match: [a-z]+"
        return 1
    fi

    if [[ ! "$sub" =~ ^[a-z0-9]+$ ]]; then
        notify_error "Sub must match: [a-z0-9]+"
        return 1
    fi

    if [[ "$url_template" != *"%s"* ]]; then
        notify_error "url_template must contain %s"
        return 1
    fi

    if [[ ! "$base_url" =~ ^https?:// ]]; then
        notify_error "base_url must start with http/https"
        return 1
    fi

    if ! awk -F'\t' -v p="$prefix" -v s="$sub" '!/^#/ && NF >= 2 && $1 == p && $2 == s { found=1; exit } END { exit found ? 0 : 1 }' "$SEARCH_GROUPS_FILE"; then
        notify_error "Prefix '${prefix}:${sub}' not found"
        return 1
    fi

    tmp_file=$(mktemp)
    awk -F'\t' -v OFS='\t' -v p="$prefix" -v s="$sub" -v n="$name" -v u="$url_template" -v b="$base_url" '
        !/^#/ && NF >= 2 && $1 == p && $2 == s { $1 = p; $2 = s; $3 = e; $4 = n; $5 = u; $6 = b }
        { print }
    ' "$SEARCH_GROUPS_FILE" > "$tmp_file"
    mv "$tmp_file" "$SEARCH_GROUPS_FILE"
    notify_success "Updated prefix: ${prefix}:${sub} -> $name"
}

SORT_MODE="$DEFAULT_SORT_MODE"
ensure_cache_files
ensure_search_groups_file
load_sort_mode
load_search_groups
read_quicklinks || true
load_stats

LIST=$(build_menu_list)

CHOICE=$(echo -e "$LIST" | rofi -dmenu -config "$CONFIG" -p " " -theme-str 'entry { placeholder: "Search, add!/rm!/edit!, padd!/prm!/pedit!"; }')

[[ -z "$CHOICE" ]] && exit 0

if [[ "$CHOICE" =~ ^add!\ (.+)$ ]]; then
    add_quicklink "${BASH_REMATCH[1]}"
    exit 0
fi

if [[ "$CHOICE" =~ ^edit!\ (.+)$ ]]; then
    edit_quicklink "${BASH_REMATCH[1]}"
    exit 0
fi

if [[ "$CHOICE" == "rm!" ]]; then
    rm_quicklink ""
    exit 0
elif [[ "$CHOICE" =~ ^rm!\ (.+)$ ]]; then
    rm_quicklink "${BASH_REMATCH[1]}"
    exit 0
fi

if [[ "$CHOICE" =~ ^padd!\ (.+)$ ]]; then
    add_search_group "${BASH_REMATCH[1]}"
    exit 0
elif [[ "$CHOICE" =~ ^pedit!\ (.+)$ ]]; then
    edit_search_group "${BASH_REMATCH[1]}"
    exit 0
elif [[ "$CHOICE" == "prm!" ]]; then
    rm_search_group ""
    exit 0
elif [[ "$CHOICE" =~ ^prm!\ (.+)$ ]]; then
    rm_search_group "${BASH_REMATCH[1]}"
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
    if [[ "$QUERY" =~ ^([a-z]+):h!$ ]]; then
        prefix="${BASH_REMATCH[1]}"
        default_sub="$(get_default_sub "$prefix")"
        if [[ -z "$default_sub" ]]; then
            notify_error "Unknown prefix: $prefix"
            exit 0
        fi
        history_query="$(show_prefix_history "$prefix")"
        [[ -z "$history_query" ]] && exit 0
        execute_search "$prefix" "$default_sub" "$history_query"
    elif [[ "$QUERY" =~ ^([a-z]+):([a-z0-9]+)!\ (.+)$ ]]; then
        prefix="${BASH_REMATCH[1]}"
        sub="${BASH_REMATCH[2]}"
        query_text="${BASH_REMATCH[3]}"
        execute_search "$prefix" "$sub" "$query_text"
    elif [[ "$QUERY" =~ ^([a-z]+):([a-z0-9]+)!$ ]]; then
        prefix="${BASH_REMATCH[1]}"
        sub="${BASH_REMATCH[2]}"
        open_base_url "$prefix" "$sub"
    elif [[ "$QUERY" =~ ^([a-z]+)!\ (.+)$ ]]; then
        prefix="${BASH_REMATCH[1]}"
        query_text="${BASH_REMATCH[2]}"
        default_sub="$(get_default_sub "$prefix")"
        if [[ -n "$default_sub" ]]; then
            execute_search "$prefix" "$default_sub" "$query_text"
        else
            xdg-open "https://www.perplexity.ai/search?q=$(urlencode "$QUERY")"
        fi
    elif [[ "$QUERY" =~ ^([a-z]+)!$ ]]; then
        prefix="${BASH_REMATCH[1]}"
        default_sub="$(get_default_sub "$prefix")"
        if [[ -z "$default_sub" ]]; then
            xdg-open "https://www.perplexity.ai/search?q=$(urlencode "$QUERY")"
            exit 0
        fi

        if is_group "$prefix"; then
            selected_sub="$(show_group_menu "$prefix")"
            [[ -z "$selected_sub" ]] && exit 0
            open_base_url "$prefix" "$selected_sub"
        else
            open_base_url "$prefix" "$default_sub"
        fi
    else
        xdg-open "https://www.perplexity.ai/search?q=$(urlencode "$QUERY")"
    fi
fi
