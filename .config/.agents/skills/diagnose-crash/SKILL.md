---
name: diagnose-crash
description: Establish why a program crashed on this machine from its systemd-coredump core dump, and decide whether the crash is worth reporting upstream. Use when handed a crash, a coredump, or a pid from `coredumpctl list`, or when the user says a program segfaulted or died unexpectedly.
---

# Diagnose a crash

A core dump answers one question well — *where* the process was when it died —
and hints at a second: whether this is worth anyone else's time. Answer both,
in that order, and stop.

## Never do this

The journal entry for a dump carries `COREDUMP_ENVIRON`: the crashed process's
entire environment, API keys and session tokens included. Never print it, never
paste it into a bug report, never include it in a summary. `coredumpctl info`
prints it too — read past it, do not echo it.

The same goes for the command line when it carries credentials as arguments.
Say "the command line contains a token, redacted" rather than reproducing it.

## 1. Establish the facts

```
coredumpctl info <pid>
```

Note the signal, the executable, the package it belongs to, and whether the
dump is `present` or `truncated` — a truncated dump limits everything below,
so say so early rather than guessing past it.

Check whether this is a repeat:

```
coredumpctl list <executable>
```

A program that dumps on a schedule is a different problem from one that died
once, and the fix for the first is usually not a backtrace.

## 2. Get a backtrace

```
coredumpctl debug <pid>
```

Then in gdb: `bt full`, and `thread apply all bt` when the crash looks like a
race or a deadlock.

Without debug symbols the trace is addresses and `??`. On Arch, install
`debuginfod` and set `DEBUGINFOD_URLS=https://debuginfod.archlinux.org` before
launching gdb; for AUR or hand-built binaries the symbols usually do not exist
at all. Say the trace is unsymbolized instead of reading meaning into it.

## 3. Classify

Name which of these it is, and say what in the evidence decided it:

- **Known upstream bug** — the trace matches a report that already exists.
  Search before concluding this.
- **Environment** — missing library, driver mismatch, GPU or NVIDIA/Intel
  profile trouble, out of memory, a file that should be there and is not.
- **Genuine bug in the program** — a reproducible fault in its own code.
- **Not determinable** — truncated dump, no symbols, single occurrence with no
  pattern. This is a legitimate answer. Reach it quickly rather than slowly.

## 4. Decide about reporting

Worth reporting when: it reproduces, the trace is symbolized enough to point
somewhere specific, and no existing report matches.

Not worth reporting when: symbols are missing, the build is local or AUR, the
cause is this machine's environment, or it happened once and never again.

If it is worth reporting, draft the report: distribution and package version,
signal, the trimmed backtrace, and the reproduction steps if any. Hand the
draft over. **Do not file it** — that is the user's call, not yours.

## Scope

Stop at diagnosis. Do not patch the program, rebuild the package, change system
configuration, or delete dumps. If the fix is obvious, say what it is and let
the user decide whether to take it.
