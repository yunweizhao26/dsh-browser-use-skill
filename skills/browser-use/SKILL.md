---
name: browser-use
description: "Drive a real Chrome over CDP: navigate, click, type, extract, screenshot. Persistent daemon, one stdin call runs many steps, named daemons for parallel agents."
whenToUse: "The task needs a live browser — the user's logged-in session, a JS-rendered or bot-protected page, or hover/drag/upload — so a plain HTTP fetch cannot deliver the result. Prefer swarm execution for anything bigger than one page."
---

# Browser Use (local CDP)

`browser-use` reads Python from stdin and runs it in a persistent REPL against Chrome over CDP. Helpers are pre-imported; the daemon starts on the first call and keeps the attached tab between calls. Print only what you need — stdout goes into the prompt verbatim.

## Invoke

PowerShell (this host; the upstream `<<'PY'` heredoc is bash-only and does not run here):

```powershell
@'
new_tab("https://example.com")
wait_for_load()
print(page_info())
'@ | browser-use
```

bash/zsh: `browser-use <<'PY' … PY`. Env vars: PowerShell `$env:BU_NAME='x'`; bash `export BU_NAME=x`.

## Cost model — batch, don't chat

Measured on Windows with PowerShell: each CLI call costs a fixed ~0.95 s (process start + daemon handshake) whether it prints one value or drives ten steps; the Python import is only ~65 ms of that. Ten separate calls ≈ 10 s plus ten model round-trips. So make one call per decision point and several helper calls inside it. Call `new_tab(url)` once per task, not once per call.

## Which browser it drives

`BU_CDP_URL` decides which browser you drive. Point it at a dedicated profile's endpoint (for example `http://127.0.0.1:9333`) and agents get a browser that opens with **no consent prompt** and keeps its own logins, isolated from the user's own browsing Chrome.

- **Dedicated agent browser (default)**: `scripts/ensure-browser.ps1` starts it on demand (own profile, own port).
- **The user's own Chrome** (their live tabs and logins), only when they ask for it: clear `BU_CDP_URL`, tick *Allow remote debugging for this browser instance* at `chrome://inspect/#remote-debugging`, `browser-use --reload`, then confirm with `list_tabs()`. Expect one Allow click per connection — there is no way to persist that consent.
- **No flag and no toggle**: a throwaway temporary profile with no logins.
- No Chrome at all: `browser-use --doctor` says so.

## Parallel agents

Default posture for browser work: **one agent per browser session**, and spread multi-page or multi-site work across agents rather than inside one session. `BU_NAME` selects a daemon; the `default` daemon attaches to the user's own tab, so any parallel work must use names.

```powershell
$env:BU_NAME = 'agent3'                      # own daemon + own background tab
$env:BU_CDP_URL = 'http://127.0.0.1:9223'    # optional: its own browser instance
```

- Two agents on the same `BU_NAME` clobber each other's tab and navigations — never share one.
- Different names share one Chrome (and its cookies) but get separate tabs; that is enough for independent reading, not for separate logins.
- To isolate logins or heavy pages, give each agent its own browser: a distinct non-default `--user-data-dir` plus a distinct port, then `BU_CDP_URL`.
- Beyond ~4 local agents memory dominates; cloud browsers are one-per-task by design.

Launcher, limits and the sharing rules: `references/parallel.md`.

## Reading a page without burning context

Never print a whole DOM, `document.body.innerText`, or an unfiltered accessibility tree. The size of your `print` is the size of the prompt: the harness may prune an oversized result, but what comes back is then mangled, so slice in Python instead.

| Need | Cheapest tool | Order of magnitude |
|---|---|---|
| Where is X / does the layout look right | one `capture_screenshot(path=…, max_dim=768)` | ~800 tokens |
| A specific value, list or attribute | `js()` returning only the matches, sliced | ~50–300 tokens |
| Which elements are actionable | AX tree filtered in Python, print ≤30 rows | ~300–800 tokens |
| Raw AX tree / full innerText printed | don't | 20k–200k tokens |

A screenshot is the *cheap* option when the alternative is a big text dump: one 768-px image costs about as much as 40 lines of DOM text, while the raw tree it replaces costs hundreds of times more. It is the *expensive* option when a three-line `js()` would answer the question, and it is worthless if your harness cannot feed images back to you — check whether you can actually see the file before you take it. When in doubt, extract text.

Rules of thumb: slice in Python before printing (`items[:20]`), print counts plus a sample, never `print(nodes)`. Keep screenshot files inside the workspace.

## Click recipe

1. `cdp("Accessibility.getFullAXTree")["nodes"]` — filter by role and name in Python; each node carries `backendDOMNodeId`.
2. Centre: `q = cdp("DOM.getBoxModel", backendNodeId=n)["model"]["content"]`, then `x, y = sum(q[0::2])/4, sum(q[1::2])/4` (viewport pixels).
3. `click_at_xy(x, y)`, then verify with a targeted `js()` check or `page_info()`.
4. Negative or oversized coordinates mean the element is off-screen — `scroll()` first.

Coordinate clicks pass through iframes, shadow DOM and cross-origin frames, so prefer them. Fall back to `js()` or `fill_input(selector, text)` when the AX tree lacks the node (canvas, exotic widgets).

## Working rules

- Navigate with `new_tab(url)` on first use per task, then `wait_for_load()`.
- `list_tabs()` / `current_tab()` before opening a tab; `switch_tab()` to reuse one; `close_tab()` only for tabs you created.
- `wait_for_element(sel)` or `wait_for_network_idle()` beat a blind `wait(3)`.
- Long text: `fill_input()` / `js()` set the whole value at once; per-character `type_text()` is slow and flaky.
- A timed-out `scroll()` on a background tab means the page must be visible: `activate_tab(current_tab())`, retry once.
- Stale or internal tab: `ensure_real_tab()`.
- Login walls, MFA, payment, deletion, publishing: stop and ask the user. SSO already signed in — use it.
- Anything else: `cdp("Domain.method", **params)` reaches raw CDP.

## When something breaks

`browser-use --doctor` first: it names the failing layer (install, daemon, browser, key). `browser-use --reload` restarts the daemon. `browser-use --version` for the build.

- `references/parallel.md` — swarm setup, per-agent browsers, launch script, sharing limits.
- `references/troubleshooting.md` — env vars, macOS remote-debugging approval, tab/scroll gotchas.
- `references/cloud.md` — hosted cloud browsers, billing, parallel tasks, cookie sync.
- `references/recording.md` — action traces and video export.
