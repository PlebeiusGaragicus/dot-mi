#!/bin/bash
# Serial evaluation runner for workspace agent teams.
# Reads one prompt per line from a prompts file, runs each through
# pi-<team> -p "..." (non-interactive mode), and logs results to a
# JSONL manifest for later trajectory analysis.
#
# Usage:
#   ./evals/run-eval.sh <team> [prompts-file]
#
# Examples:
#   ./evals/run-eval.sh deepresearch
#   ./evals/run-eval.sh deepresearch evals/custom-prompts.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOT_MI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$DOT_MI_DIR/bash_aliases"

TEAM="${1:?Usage: $0 <team> [prompts-file]}"
PROMPTS_FILE="${2:-$SCRIPT_DIR/$TEAM.txt}"

if [ ! -f "$PROMPTS_FILE" ]; then
  echo "Error: prompts file not found: $PROMPTS_FILE" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not found in PATH" >&2
  exit 1
fi

EVAL_ID="$(date +%Y-%m-%d-%H%M%S)"
RESULTS_DIR="$SCRIPT_DIR/results/$TEAM/$EVAL_ID"
WS_ROOT="$DOT_MI_DIR/workspaces/$TEAM"
mkdir -p "$RESULTS_DIR"

echo "=== Eval Run: $EVAL_ID ==="
echo "Team:    $TEAM"
echo "Prompts: $PROMPTS_FILE"
echo "Results: $RESULTS_DIR"
echo ""

prompt_num=0
passed=0
failed=0

while IFS= read -r prompt || [ -n "$prompt" ]; do
  [[ -z "$prompt" || "$prompt" == \#* ]] && continue
  prompt_num=$((prompt_num + 1))

  echo "--- Prompt $prompt_num ---"
  echo "$prompt"
  echo ""

  before=$(ls "$WS_ROOT" 2>/dev/null || true)

  start=$(date +%s)
  exit_code=0
  "pi-$TEAM" -p "$prompt" \
    > "$RESULTS_DIR/prompt-${prompt_num}-output.txt" 2>&1 \
    || exit_code=$?
  duration=$(( $(date +%s) - start ))

  after=$(ls "$WS_ROOT" 2>/dev/null || true)
  new_ws=$(comm -13 <(echo "$before") <(echo "$after") | tail -1)
  ws_path="${new_ws:+$WS_ROOT/$new_ws}"

  jq -cn \
    --argjson num "$prompt_num" \
    --arg prompt "$prompt" \
    --arg workspace "${ws_path:-unknown}" \
    --argjson exit_code "$exit_code" \
    --argjson dur "$duration" \
    '{prompt_num:$num, prompt:$prompt, workspace:$workspace,
      exit_code:$exit_code, duration_seconds:$dur}' \
    >> "$RESULTS_DIR/manifest.jsonl"

  if [ "$exit_code" -eq 0 ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi

  echo "[$prompt_num] exit=$exit_code  ${duration}s  ${ws_path:-unknown}"
  echo ""
done < "$PROMPTS_FILE"

echo "=== Eval complete ==="
echo "Prompts: $prompt_num  Passed: $passed  Failed: $failed"
echo "Manifest: $RESULTS_DIR/manifest.jsonl"
