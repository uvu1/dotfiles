---
name: agent-browser
description: Drive a real Chrome with the agent-browser CLI to check the user's own local dev server (localhost / 127.0.0.1) - open pages, click, fill forms, read console errors, and take screenshots or accessibility snapshots.
---

# agent-browser

Fast browser automation CLI for AI agents. Chrome/Chromium via CDP with accessibility-tree snapshots and compact `@eN` element refs.

Install: managed by mise as `"aqua:vercel-labs/agent-browser"` in `mise/dotfiles/mise/config.unix.toml`. Do not use `npm i -g` or `brew`. If the CLI is missing, run `mise install` from `$HOME`; if Chrome is missing, run `agent-browser install`.

## Start here

This file is a discovery stub, not the usage guide. Before running any `agent-browser` command, load the actual workflow content from the CLI:

```bash
agent-browser skills get core             # start here — workflows, common patterns, troubleshooting
agent-browser skills get core --full      # include full command reference and templates
```

The CLI serves skill content that always matches the installed version, so instructions never go stale. The content in this stub cannot change between releases, which is why it just points at `skills get core`.

## Local-only default on this machine

Default target is the user's own dev server. Launch contained so a local page cannot fetch or beacon to third-party hosts:

```bash
agent-browser open --allowed-domains localhost,127.0.0.1 http://localhost:<port>
```

`--allowed-domains` blocks non-allowlisted HTTP, WebSocket, EventSource and `sendBeacon` traffic and disables WebRTC, so it must be passed on the launching command (the one that starts the session), not added later.

`~/.claude/settings.json` auto-approves only this localhost-scoped shape plus local inspection commands (`screenshot`, `snapshot`, `get`, `click`, `console`, ...). `chat`, `eval`, `cookies`, `storage`, `auth` and `state` are denied outright. Any other host, and commands that fetch a URL (`read`, `a11y <url>`, `vitals <url>`) or replay traffic (`network`), need explicit per-use approval — ask the user instead of working around it. These rules are string-prefix matches, so treat them as a guardrail, not a sandbox.

## Specialized skills

For tasks outside local web pages (Electron apps, exploratory QA, and others), run `agent-browser skills list` and load the matching one with `agent-browser skills get <name>`.
