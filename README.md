# cc-pr-videos

A Claude Code plugin that automatically records browser demo videos of your pull requests.

When you run `gh pr create`, a background process analyzes your PR, opens the running dev server in a headed browser, interacts with the new feature, and saves a `.webm` recording to your Desktop.

## How it works

1. After `gh pr create` succeeds, Claude writes the PR URL to a sentinel file
2. When the session ends, a Stop hook picks up the sentinel and launches the recorder
3. The recorder spawns a nested Claude session (Sonnet) that uses [agent-browser](https://github.com/anthropics/agent-browser) to:
   - Check if the PR has user-facing changes (skips backend-only PRs)
   - Authenticate if `.claude/demo.json` has auth config
   - Navigate to the feature and interact with it
   - Record a < 60s `.webm` video to `~/Desktop/pr-demo-<N>.webm`
4. A macOS notification fires when the recording is ready

## Install

Add the marketplace, then install the plugin (project-scope recommended):

```bash
claude plugin marketplace add https://github.com/STRML/cc-pr-videos
claude plugin install cc-pr-videos --scope project
```

Then run the init command to configure your project:

```
/pr-videos:init
```

This creates `.claude/demo.json` (auth, base URL, hints) and adds the sentinel file instruction to your project's `CLAUDE.md`.

## Prerequisites

- [agent-browser](https://github.com/anthropics/agent-browser) installed and on PATH
- `gh` CLI authenticated
- A running dev server (auto-detected on ports 3000, 3001, 5173, 5174, 4173, 8080, 8000, 4200)

## Project config

`.claude/demo.json` in your project root:

```json
{
  "baseUrl": "http://localhost:3000",
  "auth": {
    "loginUrl": "/login",
    "username": "test@example.com",
    "password": "testpass"
  },
  "browserState": ".claude/demo-browser-state.json",
  "hints": "The new feature is at /settings/billing"
}
```

| Field | Description |
|-------|-------------|
| `baseUrl` | Dev server URL (overrides auto-detection) |
| `auth` | Login credentials. Omit entirely if no auth needed. |
| `auth.loginUrl` | Path to login page |
| `auth.username` | Login username/email |
| `auth.password` | Login password |
| `browserState` | Path to persist browser cookies between recordings |
| `hints` | Free-text guidance for the recorder |

## Feedback loop

Each recording appends a summary to `.claude/demo-feedback.log`. Subsequent recordings read this log to avoid repeating mistakes — the recorder gets better over time.

## Files

```
.claude-plugin/
  plugin.json          # Plugin manifest
  marketplace.json     # Marketplace metadata
hooks/
  hooks.json           # Stop hook definition
scripts/
  stop-trigger.sh      # Reads sentinel, launches recorder
  recorder-run.sh      # Gathers PR context, runs nested Claude + agent-browser
commands/
  init.md              # /pr-videos:init command
```

## License

MIT
