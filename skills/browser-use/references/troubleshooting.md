# Troubleshooting and environment

`browser-use --doctor` prints one line per layer — install, local browser, Chrome state, daemon, own Chromium, cloud key. Read it before changing anything; `doctor --json` is the machine-readable form.

## Environment variables

| Variable | Effect |
|---|---|
| `BU_NAME` | Named daemon, e.g. one per cloud browser. Must match between starting and using it. |
| `BU_CDP_URL` / `BU_CDP_WS` | Explicit DevTools endpoint; overrides local Chrome discovery. `BU_CDP_URL` is HTTP, the daemon resolves it to WebSocket. |
| `BH_REQUIRE_EXISTING_DAEMON=1` | Health-check and reuse an exact provisioned daemon; never auto-start or discover another browser. |
| `BU_AUTOSPAWN` | Opt in to auto-starting a cloud browser when a key is configured. |
| `BH_TAB_MARKER=0` | Stop rewriting tab titles (the marker; harmless, but it edits titles). |
| `BH_DOMAIN_SKILLS=1` | Enable site-specific skill lookup under `$BH_AGENT_WORKSPACE/domain-skills/<host>/`. |
| `BH_HOME` | Daemon/config home when `~/.config` is not writable (sandboxes, CI). |
| `ANONYMIZED_TELEMETRY=false` | Disable telemetry; `browser-use telemetry disable` persists it. The INFO banner prints on every call otherwise. |
| `BU_AUTO_LOGIN=false` | Do not open the Browser Use login page when a key is missing. |

## Local Chrome will not attach

0. **Stale daemon after the browser restarted** (the dedicated profile's last tab was closed, or Chrome was killed): the daemon may report `Chrome is asking "Allow remote debugging?"` and `permission-blocked` even for a flag-mode profile that needs no approval. Run `browser-use --reload` and retry before changing any browser setting.
1. Is Chrome running? `browser-use --doctor` says; if it is not, the harness launches it.
2. Is remote debugging on? Open `chrome://inspect/#remote-debugging` and tick *Allow remote debugging for this browser instance*, then `browser-use --reload`.
3. Explicit endpoint: start Chrome with `--remote-debugging-port=9222` and set `BU_CDP_URL=http://127.0.0.1:9222`. Discovery itself probes ports 9222 and 9223 (`/json/version`).
4. Windows: driving a *copy* of an existing Chrome profile is not available (upstream restriction); either attach to the running Chrome or accept a fresh temporary profile.

## Newer Chrome without the chrome://inspect checkbox

Some Chrome builds (158 confirmed) no longer render *Allow remote debugging for this browser instance*, but the preference it sets is still honoured. Close Chrome completely, then set the key in `<User Data>/Local State` (back the file up first):

```text
devtools.remote_debugging.user-enabled = true
```

Start Chrome normally afterwards — no flags: it listens on `127.0.0.1:9222` and writes `DevToolsActivePort` beside the profile, so discovery works. Confirm both before blaming another layer. Chrome still shows a one-off **Allow remote debugging?** dialog on attach; the user clicks Allow. `chrome://inspect` remains a dead end on those builds.

`--remote-debugging-port` is silently ignored on the default user-data-dir since Chrome 136, and a copied everyday profile cannot be reused as a custom one (app-bound cookie encryption) — do not spend time on either.

## macOS approval

If Chrome shows an "Allow remote debugging?" sheet, keep the waiting command running and call `browser-use mac-approve` once from another call, with the same `BU_NAME` if one was used:

```text
BU_NAME=r7k2 browser-use mac-approve
```

`accessibility-required` means the app that launched `browser-use` (Terminal, iTerm, Codex) needs System Settings → Privacy & Security → Accessibility; ask once, then retry `mac-approve`. Only local Chrome needs this — never for `BU_CDP_URL`, `BU_CDP_WS` or cloud browsers.

## Tab and rendering gotchas

- **Closing the last tab closes the browser.** A dedicated agent instance dies with its final tab, and the next call fails on a dead endpoint. Keep one `about:blank` tab, or re-run `scripts/ensure-browser.ps1` to restart the instance.
- Omnibox popups and internal pages are not work tabs.
- CDP target order is not the visible tab-strip order; use `list_tabs()`.
- A background tab can pause rendering, so `scroll()` times out: `activate_tab(current_tab())`, retry once, re-read the scroll position. Do not invent a JS scroll replacement.
- `new_tab()` and `switch_tab()` move the harness marker without changing the visible tab; screenshots and input work in the background. `activate_tab()` only when the user asks or rendering demonstrably pauses.
- One tab per task/site; do not leave duplicate tabs or close tabs you did not open.

## Scope limits

Domain allow/block lists and the CDP guard are protections for an aligned model, not a sandbox. Model-written Python can reach the network and anything the page can read. No helper guarantees that a CAPTCHA can be avoided or that a site tolerates automation.
