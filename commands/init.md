---
name: init
description: Set up PR demo recording for the current project. Creates .claude/demo.json config and adds the sentinel file instruction to CLAUDE.md.
user_invocable: true
---

# PR Demo Video Setup

Set up automatic PR demo recording for this project.

## Steps

1. **Create `.claude/demo.json`** in the project root with this template (ask the user to fill in auth details if needed):

```json
{
  "baseUrl": "http://localhost:3000",
  "auth": {
    "loginUrl": "/login",
    "username": "",
    "password": ""
  },
  "browserState": ".claude/demo-browser-state.json",
  "hints": ""
}
```

- `baseUrl`: The dev server URL (probe ports 3000, 3001, 5173, 5174, 8080 to suggest one)
- `auth`: Login credentials for the app. Omit the entire `auth` key if no login is needed.
- `browserState`: Path to save/load browser cookies between recordings
- `hints`: Free-text hints for the recorder (e.g. "The new feature is at /settings/billing")

2. **Add the sentinel file instruction** to the project's `.claude/CLAUDE.md` (create if it doesn't exist). Append this section if not already present:

```markdown
## PR Demo Recording

After any `gh pr create` succeeds and you have the PR URL, write it to a sentinel file:

```bash
echo "$PR_URL" > /tmp/claude/pr-demo-pending
```

Then tell the user: "PR demo queued — will record to ~/Desktop/pr-demo-<N>.webm after this response."

A Stop hook picks up the sentinel and launches the recorder outside the sandbox.
```

3. **Add `.claude/demo-browser-state.json` and `.claude/demo-feedback.log` to `.gitignore`** (they contain credentials/session data).

4. Tell the user the setup is complete and they can test by creating a PR in this project.
