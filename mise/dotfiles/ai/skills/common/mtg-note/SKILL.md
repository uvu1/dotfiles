---
name: mtg-note
description: Capture meeting questions, uncertainties, and observations as timestamped lines in an Obsidian Markdown note. Use only when the user explicitly invokes mtg-note.
---

## Select the meeting note

An explicit invocation can specify an existing `.md` path, supply text to capture, or do both. For example, use `$mtg-note "~/Vault/Meetings/Weekly.md"` in Codex or `/mtg-note "~/Vault/Meetings/Weekly.md"` in Claude Code. Text after the quoted path is captured in the same invocation. A later invocation such as `$mtg-note なぜキャッシュの有効期限を5分にしたのか？` uses the selected note.

Verify that an explicitly supplied path points to an existing Markdown file before selecting it. Reuse the resolved path from the current conversation until the user explicitly selects another file. If there is no selected note, or a supplied or previously selected path cannot be found, ask for the path before editing. When the invocation supplies only a valid path, confirm the selection briefly and leave the file untouched.

## Record the entries

1. Turn the supplied text into one concise line per distinct question, uncertainty, or observation, in the user's language and original order. Preserve relevant details and uncertainty. Capture questions without answering or researching them.
2. Read the target note. Locate the Markdown heading `## 気になったこと`, ignoring lookalikes inside YAML frontmatter, code blocks, or comments. If it occurs more than once, ask which section to use before editing.
3. Read the system's local time once with `date +%H:%M`. Format each entry as `- HH:mm 本文` using that same time.
4. Insert the entries after the existing direct content of the heading and before the first subsequent Markdown heading of any level. Preserve the existing content and its order, with existing separator blank lines after the new entries. If the heading is absent, add it and the entries at the end of the file. If the end is still inside an unclosed code block or comment, ask the user to resolve it before editing.
5. Verify that the entries were written to the intended section. Return only the lines added. If the write failed, state the blocker briefly.
