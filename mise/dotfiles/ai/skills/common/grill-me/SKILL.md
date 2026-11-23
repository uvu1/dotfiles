---
name: grill-me
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

<!-- Adapted from mattpocock/skills skills/productivity/grilling (MIT) at 4ae2317. -->

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round, giving your recommended answer for each question. Then wait for the user's answers before the next round.

Ask with the host's structured question tool when one is available: `AskUserQuestion` in Claude Code, `request_user_input` in Codex.

- Give each question 2-3 mutually exclusive options. Put your recommended answer first and append "(Recommended)" to its label. Leave out an "Other" option; the tool adds one for free-form answers.
- When the frontier exceeds one call's question limit (4 in Claude Code, 3 in Codex), split it across consecutive calls within the same round.
- Put the context needed to decide into the question itself; earlier output may be hidden while the dialog is open.

When no such tool is available, or the call fails (for example, Codex reports `request_user_input is unavailable in <mode> mode`), ask in text instead. Number each question and format the round like so:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

In text, word each question so "yes" accepts your recommended answer.

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent with a fresh context window to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.
