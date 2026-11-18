# Cloud browsers (hosted)

Cloud browsers are managed Chrome instances hosted by Browser Use: each is fresh and isolated, billed per browser-hour until stopped. Use them for headless servers, parallel work, isolation, or when a site is bot-sensitive.

Two different products — do not mix them up:

- **Cloud browser**: you drive it over CDP from here; the agent stays local.
- **Fully hosted agent** (`bu-4.0` and friends): Browser Use runs the model too. Not what this skill does.

## When it is worth it

- **Parallel tasks.** Local Chrome is one shared browser; concurrent tasks fight over tabs and focus. One cloud browser per task isolates them.
- **CAPTCHA walls, repeat automation, bot-sensitive sites.** Managed IPs plus stealth make blocks less likely, and the user's own IP and browser stay out of it.
- **No display.** Servers and CI get a browser without installing one.

Say briefly why when proposing one; it costs money.

## Authenticate

```powershell
browser-use auth status
'bu_...' | browser-use auth login --api-key-stdin
browser-use login            # interactive, creates the key
```

`BROWSER_USE_API_KEY` in the environment (or a `.env`) also works. `BU_AUTO_LOGIN=false` keeps an interactive run from opening the sign-in page; servers and CI keep the missing-key error.

## Use a named daemon

```powershell
@'
start_remote_daemon("r7k2")
'@ | browser-use

$env:BU_NAME = 'r7k2'
@'
new_tab("https://example.com")
print(page_info())
'@ | browser-use
```

The name is yours to invent (`r7k2` is a placeholder). `BU_NAME` is an environment variable, not a CLI flag. Keep the same value for every call in that task; do not start a remote daemon and then silently drive the default one.

## Stop it, and say so

Cloud browsers bill until stopped or timed out. When the task is done and one is still running, ask the user directly ("Should I close this cloud browser now?") and only then:

```powershell
@'
stop_remote_daemon("r7k2")
'@ | browser-use
```

Or `PATCH /browsers/{id} {"action":"stop"}` against the API.

## Extras

- **Live view.** Cloud browsers print an interactive live-view URL to stderr unless `BH_OPEN_LIVE_URL=0`; anyone with the link controls the browser, so do not log or forward it.
- **Profiles / cookie sync**: `Browser(cloud_profile_id='work')` in the library; details at https://github.com/browser-use/browser-harness/blob/main/interaction-skills/profile-sync.md
- **Harness-provisioned daemons**: `BH_REQUIRE_EXISTING_DAEMON=1` makes each call reuse that exact daemon or fail closed.
