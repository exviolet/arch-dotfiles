import ipaddress
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


def output(*args):
    try:
        return subprocess.run(
            args, capture_output=True, text=True, timeout=4,
            env={**os.environ, "LC_ALL": "C"}, check=False,
        ).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def snapshot(interface):
    status = {}
    values = output("nmcli", "--terse", "--escape", "no",
                    "--fields", "IP4.ADDRESS,IP4.GATEWAY", "device", "show", interface)
    for line in values.splitlines():
        field, _, value = line.partition(":")
        if field.startswith("IP4.ADDRESS") and "address" not in status:
            status["address"] = value.partition("/")[0]
        elif field == "IP4.GATEWAY" and value not in ("", "--"):
            status["gateway"] = value

    counters = Path("/sys/class/net") / interface / "statistics"
    for direction in ("rx", "tx"):
        try:
            status[direction] = int((counters / f"{direction}_bytes").read_text())
        except (OSError, ValueError):
            pass
    status["time"] = time.monotonic()

    if "gateway" in status:
        try:
            gateway = str(ipaddress.IPv4Address(status["gateway"]))
        except ipaddress.AddressValueError:
            return status
        probe = output("ping", "-4", "-n", "-I", interface, "-c", "3",
                       "-i", "0.25", "-W", "1", "-w", "3", gateway)
        loss = re.search(r"([\d.]+)% packet loss", probe)
        latency = re.search(r"= [\d.]+/([\d.]+)/[\d.]+/[\d.]+ ms", probe)
        if loss:
            status["loss"] = float(loss[1])
        if latency:
            status["latency"] = float(latency[1])
    return status


if __name__ == "__main__":
    interface = sys.argv[1]
    if interface and interface not in (".", "..") and "/" not in interface and not interface.startswith("-"):
        print(json.dumps(snapshot(interface)))
