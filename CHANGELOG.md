# Changelog

All notable changes to this bundle are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-11-18

First release.

### Added

- Bundle manifest (`dsh.bundle.patch`) that mounts a single bundled skill on the
  local filesystem skill provider with `includeDefaultRoots: false`.
- `browser-use` skill: invocation for PowerShell and bash, per-call cost model,
  browser selection (dedicated profile vs the user's own Chrome), page-reading
  cost table, click recipe, working rules, and failure triage.
- `references/parallel.md`: `BU_NAME` daemon model, one browser per agent,
  measured serial-versus-parallel numbers, safe shutdown.
- `references/troubleshooting.md`: Chrome 136+ default-profile restriction, the
  missing `chrome://inspect` toggle on newer builds, stale-daemon false alarm,
  environment variables, macOS approval.
- `references/cloud.md`, `references/recording.md`: hosted browsers and traces,
  read on demand.
- `scripts/ensure-browser.ps1`: idempotent launcher for debug-port Chrome
  instances, one profile per port.
- Plugin-manager display metadata and icon.

### Notes

- Adapted from the browser-use / browser-harness agent skill (MIT); see `NOTICE`.
- Tracks browser-use `1.0.6` behaviour.
