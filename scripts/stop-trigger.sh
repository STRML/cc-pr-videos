#!/usr/bin/env bash
# Stop hook: launches PR demo recorder if Claude left a sentinel after gh pr create.
# Runs outside the sandbox — so the nested claude --print can access ~/.claude.json.

SENTINEL="/tmp/claude/pr-demo-pending"
[[ ! -f "$SENTINEL" ]] && exit 0

INPUT=$(cat)

# Don't re-trigger if we're already in a stop hook loop
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
[[ "$STOP_HOOK_ACTIVE" == "true" ]] && exit 0

PR_URL=$(cat "$SENTINEL")
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
rm -f "$SENTINEL"

[[ -z "$PR_URL" ]] && exit 0

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

nohup bash "$PLUGIN_ROOT/scripts/recorder-run.sh" "$PR_URL" "$CWD" \
  >> /tmp/claude/pr-demo-recorder.log 2>&1 &
disown

exit 0
