#!/usr/bin/env bash
# Hand one coredump to a coding agent, with the facts already gathered.
#
# Also the manual entry point: pick any pid out of `coredumpctl list` and run
# this against it.
set -euo pipefail

MESSAGE_ID=fc2e22bc6ee647b6b90729ab34a250b1

usage() {
    printf 'Usage: %s <pid>\n\n  pid comes from `coredumpctl list`.\n' "${0##*/}" >&2
    exit 2
}

pid="${1:-}"
[[ -n "$pid" ]] || usage

# Deliberately narrow. COREDUMP_ENVIRON holds the crashed process's entire
# environment — API keys and tokens included — so it never reaches the agent,
# and the skill is told not to go looking for it either.
#
# NUL-separated because a command line is one field that contains spaces.
if ! readarray -d '' -t fields < <(
    journalctl -o json -n 1 "MESSAGE_ID=$MESSAGE_ID" "COREDUMP_PID=$pid" 2>/dev/null |
    python3 -c '
import json, sys

line = sys.stdin.readline()
if not line.strip():
    raise SystemExit(1)

dump = json.loads(line)
for name in ["COREDUMP_EXE", "COREDUMP_COMM", "COREDUMP_SIGNAL_NAME", "COREDUMP_CWD"]:
    sys.stdout.write(str(dump.get(name) or "-") + "\0")
'
) || [[ ${#fields[@]} -lt 4 ]]; then
    printf 'No coredump journal entry for pid %s\n' "$pid" >&2
    exit 1
fi

exe="${fields[0]}"
comm="${fields[1]}"
signal="${fields[2]}"
cwd="${fields[3]}"

prompt="Процесс упал на этой машине, разберись.

Используй скилл diagnose-crash.

- pid: $pid
- исполняемый файл: $exe
- процесс: $comm
- сигнал: $signal
- рабочий каталог: $cwd

Начни с \`coredumpctl info $pid\`. Не выводи и не пересылай блок окружения
процесса — там бывают ключи и токены."

label="Краш: $comm"
workdir="$cwd"
[[ -d "$workdir" ]] || workdir="$HOME"

# The tab label is for a human; the agent name is an identifier herdr validates
# as [a-z][a-z0-9_-]{0,31}. They are not the same string and cannot be.
slug="$(printf '%s' "$comm" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-' | cut -c1-15)"
slug="${slug%-}"
[[ -n "$slug" ]] || slug="unknown"
agent_name="crash-${slug}-${pid}"

if command -v herdr >/dev/null 2>&1 && herdr status >/dev/null 2>&1; then
    pane="$(
        herdr tab create --cwd "$workdir" --label "$label" --focus 2>/dev/null |
        python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])' 2>/dev/null || true
    )"

    if [[ -n "$pane" ]]; then
        # Start bare, then submit the prompt. Passing it as an argv argument
        # fails outright — herdr refuses text it cannot encode safely for the
        # target shell, and this prompt has newlines and backticks in it.
        herdr agent start "$agent_name" --kind claude --pane "$pane" >/dev/null || exit 1
        herdr agent prompt "$agent_name" "$prompt" >/dev/null
        exit 0
    fi
fi

# herdr is where the agents live, but a crash is exactly when things are
# already going wrong, so do not depend on it being up.
exec alacritty --class Alacritty-Float -e claude "$prompt"
