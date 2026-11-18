# dsh-browser-use-skill

> The browser-use agent skill, packaged for DeepSeek Harness.

This package forks the browser-use agent skill, the document that ships with [browser-use/browser-use](https://github.com/browser-use/browser-use). It is rebuilt for DSH around one persistent Python REPL, the browser-harness helpers and raw CDP, and extended with what a general-purpose skill cannot know: PowerShell invocation, a token budget, and how to run several agents at once without them fighting over a tab. The browser-use Python project itself is untouched. Attribution and the upstream license are in `NOTICE`.

```
  ● skill loads                browser-use — 1.6k tokens, on demand
  │
  ● model writes a cell        new_tab(url); wait_for_load(); js(...)
  │
  ● REPL runs it on Chrome     raw CDP, persistent daemon
  │
  ✓ one call, ten steps        ~200 characters back into context
```

The bundle adds guidance. It does not add a model-facing tool, and it never calls a cloud API.

## Which piece do you need?

| You want | Reach for |
| --- | --- |
| An agent that drives a real browser from your own code | this package, plus the `browser-use` CLI |
| A hosted browser and model behind one API key | [Browser Use Cloud](https://docs.browser-use.com/cloud/agent/quickstart) |
| A model-facing tool that wraps the cloud API | a different package; this one teaches the CLI instead |

## Install

```sh
dsh plugin add dsh-browser-use-skill
```

From a checkout, add the directory through **Plugins → Add plugin**, or install the package directory with the plugin manager. The bundle mounts its own `skills/` tree with `includeDefaultRoots: false`, so it contributes exactly one skill and never scans or shadows your other skill roots.

## Prerequisite: the CLI

```sh
uv tool install 'browser-use==1.0.6'   # Python 3.11+
browser-use --doctor                   # install · browser · daemon · key, one line each
```

Pin the exact version (`==`, never `>=`). Upstream releases often and breaks APIs between them.

## What the skill adds over upstream

Upstream ships one 2.5k-token document written for bash on a generic machine. This package splits it, drops what a DSH agent will not hit, and adds what it will.

| Area | Upstream | Here |
| --- | --- | --- |
| Invocation | bash heredocs only | PowerShell `@'…'@ \| browser-use` first, bash second |
| Standing cost | every section, always | 1.6k tokens on trigger; detail read on demand |
| Cost model | none | measured per-call overhead, and when to batch |
| Browser choice | one paragraph | dedicated profile vs the user's own Chrome, and why one of them prompts |
| Reading a page | "prefer the accessibility tree" | a cost table: screenshot vs `js()` vs filtered AX vs dumping everything |
| Parallel agents | "use cloud browsers" | `BU_NAME` daemons, dedicated tabs, one browser per agent, a launcher script |
| Troubleshooting | generic | the Chrome 136+ default-profile block, the missing `chrome://inspect` toggle, the stale daemon |

Progressive disclosure, the way DSH prefers it: `SKILL.md` is the whole contract, `references/` holds the long tail.

## What a call actually costs

| Material | Tokens |
| --- | ---: |
| A printed title | ~15 |
| Filtered accessibility tree, 5 rows | ~300–800 |
| Screenshot at `max_dim=768` | ~800 |
| Screenshot at full size (1137×1153) | ~1,500 |
| A raw accessibility tree, printed | 20k–200k |

The skill's rule is the boring one that works: slice in Python, print counts and a sample, never `print(nodes)`.

## Parallel agents

One agent per browser session, by default.

```powershell
$env:BU_NAME = 'agent3'                     # own daemon, own background tab
$env:BU_CDP_URL = 'http://127.0.0.1:9223'   # optional: own browser instance
```

Same `BU_NAME` from two agents means they clobber each other's tab. Different names share one Chrome and its cookies but get separate tabs. Isolate logins by giving each agent its own browser. Past roughly four local browsers, memory decides.

`skills/browser-use/scripts/ensure-browser.ps1` starts the instances a swarm needs, and leaves running ones alone.

## FAQ

<details>
<summary><b>Do I need an API key?</b></summary>

Not for a local browser. The skill drives Chrome over CDP with no account. A key is only for Browser Use Cloud browsers and the `bu-*` models.
</details>

<details>
<summary><b>Why not just call the CLI directly?</b></summary>

You can. The skill is the judgment part: batch your steps, pick the cheapest way to read a page, do not share a daemon across agents, and reach for `--doctor` before guessing. Without it, a competent model still burns context and still races itself.
</details>

<details>
<summary><b>Does it work on Windows?</b></summary>

Yes — that is the main reason this fork exists. Upstream examples are bash heredocs; DSH on Windows runs PowerShell, where `<<'PY'` does not exist. The skill gives the working form first.
</details>

<details>
<summary><b>Is it a sandbox?</b></summary>

No. Model-written Python can read files and reach the network, and page content can try to instruct the model. Run untrusted tasks in a container. The skill says so; it cannot enforce it.
</details>

<details>
<summary><b>Can it drive the Chrome I am already using?</b></summary>

Yes, with your logins — enable remote debugging at `chrome://inspect/#remote-debugging`. Chrome then asks for approval on every new connection; that consent cannot be persisted. A dedicated profile avoids the prompt but starts without your logins. The skill spells out both.
</details>

## Layout

```
cordis.patch.yml                 bundle patch — one inserted row
index.js                         mounts skills/ on the filesystem skill provider
locale/en.json                   plugin-manager title and description
icon.svg                         bundle icon
skills/browser-use/SKILL.md      the skill
skills/browser-use/references/   parallel agents · troubleshooting · cloud · recording
skills/browser-use/scripts/      ensure-browser.ps1
```

## Verified

- `node --check index.js`, valid JSON manifests, icon within limits.
- Installed into a live DSH profile: bundle `applied`, skill loads from this package.
- Skill text scanned for host-specific identifiers before publishing: none.

## Honest limits

- **The skill gives guidance and enforces nothing.** A model can still print a 50k-token tree.
- **Consent is per connection.** Chrome does not remember remote-debugging approval.
- **Upstream moves.** The skill tracks browser-use 1.0.6 behaviour; a later release may change helpers.
- **Unofficial.** Not affiliated with Browser Use or DeepSeek. Browser Use Cloud, Browser Use, DeepSeek Harness and their logos belong to their owners.

## License

MIT. Includes adapted text from browser-use / browser-harness (MIT); see `NOTICE`.
