#!/usr/bin/env bash
# Turn a crash into an offer: notify, and hand the dump to an agent on click.
#
# Follows systemd-coredump's journal entries rather than polling coredumpctl,
# so nothing runs between crashes.
set -euo pipefail

MESSAGE_ID=fc2e22bc6ee647b6b90729ab34a250b1
DIAGNOSE="$HOME/.config/niri/scripts/crash-diagnose.sh"

# Hermes managed four dumps in eleven minutes once; one card per program per
# window is enough to know it is unhappy.
DEBOUNCE_SECONDS=300

declare -A last_seen

offer() {
    local pid="$1" comm="$2" signal="$3" action

    # notify-send blocks until the notification is acted on or closed, which is
    # how the click gets back here.
    action="$(notify-send \
        --urgency=critical \
        --app-name="coredump" \
        --icon=dialog-error \
        --action="diagnose=Разобрать" \
        "$comm упал" \
        "$signal, pid $pid. Отдать краш агенту?" 2>/dev/null)" || return 0

    [[ "$action" == "diagnose" ]] || return 0
    "$DIAGNOSE" "$pid" >/dev/null 2>&1 || true
}

journalctl --follow --since=now --output=json "MESSAGE_ID=$MESSAGE_ID" 2>/dev/null |
while IFS= read -r line; do
    [[ -n "$line" ]] || continue

    if ! readarray -d '' -t fields < <(
        printf '%s' "$line" | python3 -c '
import json, os, sys

try:
    dump = json.loads(sys.stdin.read())
except ValueError:
    raise SystemExit(1)

# Other users crashing is not this session'"'"'s business.
if str(dump.get("COREDUMP_OWNER_UID") or dump.get("COREDUMP_UID") or "") != str(os.getuid()):
    raise SystemExit(1)

for name in ["COREDUMP_PID", "COREDUMP_COMM", "COREDUMP_SIGNAL_NAME", "COREDUMP_EXE"]:
    sys.stdout.write(str(dump.get(name) or "-") + "\0")
'
    ); then
        continue
    fi

    [[ ${#fields[@]} -ge 4 ]] || continue

    pid="${fields[0]}"
    comm="${fields[1]}"
    signal="${fields[2]}"
    exe="${fields[3]}"

    now="$(printf '%(%s)T' -1)"
    previous="${last_seen[$exe]:-0}"
    (( now - previous < DEBOUNCE_SECONDS )) && continue
    last_seen["$exe"]="$now"

    # Backgrounded because notify-send waits for the click, and the next crash
    # must not queue behind an unanswered card.
    offer "$pid" "$comm" "$signal" &
done
