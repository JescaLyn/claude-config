---
name: Claude Code feedback mechanism
description: How to submit feedback and bug reports about Claude Code to Anthropic
type: reference
---

## Submitting Feedback to Anthropic

Use the `/feedback` command (alias: `/bug`) to report issues, bugs, or feature requests about Claude Code directly to Anthropic's product team.

**Usage:**
```
/feedback [optional description]
/bug [optional description]
```

Examples:
```
/feedback issues with autocompletion
/bug the save command isn't working
```

**Benefits:**
- Automatically captures debugging context (version, environment, logs)
- Includes the conversation before context compaction, so issues from earlier in long sessions are easier to triage
- Can include recent sessions (last 24 hours or 7 days) for issues that span more than the current session
- Goes directly to the Claude Code team at Anthropic
- Helps engineers reproduce and prioritize issues

After completing an in-product survey, a follow-up hint appears prompting you to share more detail via `/feedback`.

**When feedback goes to Anthropic:**
- `/feedback` — Bug reports, feature requests, issues with Claude Code functionality
- GitHub Issues — Public discussion, community engagement

**When NOT to use /feedback:**
- For help with general coding problems → use `/help` or ask in chat
- For feedback on code quality → use `/custom-review` or ask Claude directly
