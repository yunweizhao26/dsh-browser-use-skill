# Parallel agents and swarm setup

## The model

- One daemon per `BU_NAME`; each name gets its own IPC endpoint (`bu-<NAME>.port`), log and screenshot stem, so names can run concurrently.
- A **named** daemon (`BU_NAME != 'default'`) that shares a browser with others gets its **own dedicated background tab**, created on first attach. This exists precisely because first-page attach makes parallel daemons fight over one tab: navigations clobber each other.
- The **default** daemon attaches to a real page of the user's browser — their visible tab. Never run parallel work on it.

## Tiers

| Tier | Setup | Isolation | Cost |
|---|---|---|---|
| Shared name | everyone uses `default` or one name | none — same attached tab, clicks and navigations collide | free, broken |
| Named daemons | one `BU_NAME` per agent | own tab; **same Chrome, same cookies**, same downloads dir, same dialogs | free, 1 tab + ~1 daemon each |
| One browser per agent | distinct `--user-data-dir` + distinct port, then `BU_CDP_URL` | process-level: separate cookies, logins, extensions | RAM; each profile logs in once |
| Cloud | `start_remote_daemon(name)` | fully hosted and exclusive per task | billed per browser-hour |

## Per-agent setup

```powershell
$env:BU_NAME = 'agent3'
$env:BU_CDP_URL = 'http://127.0.0.1:9223'   # omit to reuse the main Chrome
@'
print(list_tabs())     # verify: only this agent's tabs should matter
'@ | browser-use
```

An agent should verify it is attached where it expects before acting: `list_tabs()` on a fresh name shows just its dedicated tab.

Sub-agents inherit the parent environment, so a shared shell variable does not give them distinct names. Tell each child its name explicitly and have it set `$env:BU_NAME` (plus `BU_CDP_URL` when it owns a browser) before its first call.

## Launch N local browsers

This skill ships `scripts/ensure-browser.ps1`: it starts any instance that is missing and leaves running ones alone, so it is safe to call before every swarm.

```powershell
& ./scripts/ensure-browser.ps1 -BasePort 9333 -Count 3    # relative to this skill's directory
```

Each instance keeps its own profile, so logins survive between runs.

Agent *i* then uses `BU_NAME=agent$i` and `BU_CDP_URL=http://127.0.0.1:<port of instance i>`. Verify with `browser-use --doctor` per agent, or `Invoke-WebRequest http://127.0.0.1:<port>/json/version` — flag mode answers 200, a toggle-mode profile answers 404.

`--remote-debugging-port` is silently ignored on Chrome's **default** user-data-dir (Chrome 136+), which is why the launcher always passes a dedicated `--user-data-dir`. Non-default profiles are also exempt from the per-connection "Allow remote debugging?" prompt.

## Limits worth planning around

- **Cookies are per browser, not per tab.** Two agents on one Chrome are the same logged-in user; concurrent actions on one account can invalidate each other's session.
- **Memory**: each instance is a full Chrome plus an agent process. Past roughly four, prefer cloud browsers.
- **Downloads** land in one browser's download directory; parallel agents overwriting each other is a real failure mode.
- **Dialogs, clipboard, focus** belong to the browser process, not the tab.
- **Cloud billing** continues until `stop_remote_daemon(name)`; ask before leaving one running.

## Measured (Windows 11, Chrome 158)

Three sub-agents, one dedicated Chrome each (`9223`–`9225`, own profile), one stdin call per agent (`new_tab` + `wait_for_load` + one `js()`):

| agent | port | browser call |
|---|---|---:|
| agent-1 | 9223 | 1,576 ms |
| agent-2 | 9224 | 441 ms |
| agent-3 | 9225 | 2,110 ms |

Serial sum 4.1 s versus 2.1 s parallel wall clock for the browser layer. That is the *small* half of the win: an agent turn costs seconds, so the real gain is overlapping model latency, not CDP time. Keep each agent's call narrow for the same reason — one call, few helpers, bounded prints.

## Shutting a swarm down safely

Stop each agent's daemon first (`BU_NAME=<name> browser-use --reload`), then close only that agent's browser by its exact browser PID.

Do **not** sweep with `taskkill /F /PID … /T` over a command-line filter: process trees and Chrome's startup handoff make that reach instances you did not mean to kill, including the user's own Chrome. Close per instance instead — either the browser PID started for that profile, or over CDP:

```powershell
# per instance, exact PID from the launcher
Stop-Process -Id $browserPid
```

A `/json/version` probe is not a liveness test for a toggle-mode profile: that endpoint answers 404 there, so a failed HTTP probe does not mean the browser is down. Trust `DevToolsActivePort` plus `Get-NetTCPConnection -LocalPort <port>`.

## Choosing

- Independent pages of the same site, same account → named daemons on one Chrome.
- Different accounts, or fragile sites, or >4 agents → one browser per agent, or cloud.
- Anything a swarm writes into one file must be arbitrated outside the browser: give each agent its own output path and merge afterwards.
