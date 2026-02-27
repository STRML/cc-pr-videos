#!/usr/bin/env bash
# Records a demo of the user-facing feature introduced by a PR.
# Called via: nohup bash recorder-run.sh <PR_URL> <CWD> >> log 2>&1 &

set -euo pipefail

PR_URL="${1:-}"
CWD="${2:-$HOME}"
[[ -z "$PR_URL" ]] && exit 1

PR_NUM=$(echo "$PR_URL" | grep -oE '[0-9]+$')

mkdir -p /tmp/claude

# Gather PR context (5s timeout — gh can hang)
TIMEOUT_BIN=$(command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null || echo "")
GH_CMD="${TIMEOUT_BIN:+$TIMEOUT_BIN 5} gh pr view $PR_URL --json title,body,files"
PR_INFO=$(eval "$GH_CMD" 2>/dev/null || echo '{}')
PR_TITLE=$(echo "$PR_INFO" | jq -r '.title // ""')
PR_BODY=$(echo "$PR_INFO"  | jq -r '.body // ""' | head -c 1000)
CHANGED_FILES=$(echo "$PR_INFO" | jq -r '[.files[].path] | join(", ")' 2>/dev/null || echo "")

# Probe common dev server ports
DEV_URL=""
for port in 3000 3001 5173 5174 4173 8080 8000 4200; do
  if curl -sf --max-time 0.5 "http://localhost:$port" >/dev/null 2>&1; then
    DEV_URL="http://localhost:$port"
    break
  fi
done

cd "$CWD"

# Derive repo name and topic slug for output filename
REPO_NAME=$(basename "$CWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g; s/^-//; s/-$//')
TOPIC_SLUG=$(echo "$PR_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]/ /g' | tr -s ' ' '-' | sed 's/^-//; s/-$//' | cut -c1-40 | sed 's/-$//')
OUTPUT="$CWD/.claude/videos/pr-${PR_NUM}-${REPO_NAME}-${TOPIC_SLUG}.webm"
mkdir -p "$CWD/.claude/videos"

# Read project demo config if it exists
DEMO_CONFIG=""
DEMO_AUTH=""
DEMO_HINTS=""
DEMO_STATE=""
DEMO_FEEDBACK=""
if [[ -f .claude/demo.json ]]; then
  DEMO_CONFIG=$(cat .claude/demo.json)
  DEMO_AUTH=$(echo "$DEMO_CONFIG" | jq -r 'if .auth then "Auth config:\n  Login URL: \(.auth.loginUrl // "/login")\n  Username: \(.auth.username // "")\n  Password: \(.auth.password // "")" else "" end' 2>/dev/null || echo "")
  DEMO_HINTS=$(echo "$DEMO_CONFIG" | jq -r '.hints // ""' 2>/dev/null || echo "")
  DEMO_STATE=$(echo "$DEMO_CONFIG" | jq -r '.browserState // ""' 2>/dev/null || echo "")
  DEMO_FEEDBACK=$(echo "$DEMO_CONFIG" | jq -r '.feedbackFile // ""' 2>/dev/null || echo "")
  DEMO_OUTPUT_DIR=$(echo "$DEMO_CONFIG" | jq -r '.outputDir // ""' 2>/dev/null || echo "")
  # Override output dir if config specifies one
  if [[ -n "$DEMO_OUTPUT_DIR" ]]; then
    OUTPUT="${DEMO_OUTPUT_DIR}/pr-${PR_NUM}-${REPO_NAME}-${TOPIC_SLUG}.webm"
    mkdir -p "$DEMO_OUTPUT_DIR"
  fi
  # Override dev server URL if config specifies one
  CONFIG_URL=$(echo "$DEMO_CONFIG" | jq -r '.baseUrl // ""' 2>/dev/null || echo "")
  [[ -n "$CONFIG_URL" ]] && DEV_URL="$CONFIG_URL"
fi

# Default feedback file
FEEDBACK_FILE="${DEMO_FEEDBACK:-.claude/demo-feedback.log}"

# Read past feedback if it exists
PAST_FEEDBACK=""
if [[ -f "$FEEDBACK_FILE" ]]; then
  PAST_FEEDBACK=$(tail -30 "$FEEDBACK_FILE")
fi

# Build auth instructions
AUTH_BLOCK=""
if [[ -n "$DEMO_AUTH" ]]; then
  AUTH_BLOCK="
## Authentication
${DEMO_AUTH}
Browser state file: ${DEMO_STATE:-none}

Auth procedure:
- First try: agent-browser state load ${DEMO_STATE} (if state file exists)
- Open the app and check if you're already logged in (look for a logout button or user menu)
- If not logged in: navigate to the login URL, fill credentials, submit, wait for redirect
- After successful login: agent-browser state save ${DEMO_STATE}
"
fi

HINTS_BLOCK=""
[[ -n "$DEMO_HINTS" ]] && HINTS_BLOCK="
## Project hints
${DEMO_HINTS}
"

FEEDBACK_BLOCK=""
[[ -n "$PAST_FEEDBACK" ]] && FEEDBACK_BLOCK="
## Lessons from previous recordings (avoid repeating these mistakes)
${PAST_FEEDBACK}
"

RESPONSE=$(CLAUDECODE="" CLAUDE_CODE_ENTRYPOINT="" \
  claude --print --model sonnet --effort low --no-session-persistence \
  --tools "Bash" \
  --dangerously-skip-permissions \
  --disable-slash-commands \
  --strict-mcp-config \
  --system-prompt "You record browser demo videos of pull requests using the agent-browser CLI. Be methodical — authenticate first, then demo the feature." \
  "PR URL: $PR_URL
PR Title: $PR_TITLE
PR Description: $PR_BODY
Changed files: $CHANGED_FILES
Dev server: ${DEV_URL:-none detected}
Project dir: $CWD
Output file: $OUTPUT
${AUTH_BLOCK}${HINTS_BLOCK}${FEEDBACK_BLOCK}
## Task
1. Does this PR change something a user would SEE or INTERACT with? If no — print 'no visual feature' and stop.
2. If yes — authenticate first (see auth procedure above), then find the specific route that shows the new feature.
3. Record the demo:
   - agent-browser record start $OUTPUT
   - agent-browser --headed open <url>
   - Interact with the feature (click, fill forms, show state changes)
   - agent-browser wait 1000 between steps
   - agent-browser record stop
   - agent-browser close

Keep the recording under 60 seconds. Focus on the user-facing change.

When done, output a brief summary of what you recorded and any issues you hit.")

echo "$RESPONSE"

# Save feedback for next run
if [[ -n "$RESPONSE" ]]; then
  mkdir -p "$(dirname "$FEEDBACK_FILE")"
  echo "--- $(date -u +%Y-%m-%dT%H:%M:%SZ) PR #${PR_NUM} ---" >> "$FEEDBACK_FILE"
  echo "$RESPONSE" | tail -10 >> "$FEEDBACK_FILE"
  echo "" >> "$FEEDBACK_FILE"
fi

STATUS=$?
if [[ -f "$OUTPUT" ]]; then
  osascript -e "display notification \"Saved: $(basename "$OUTPUT")\" with title \"PR Demo Ready\" subtitle \"${PR_TITLE}\""
fi
