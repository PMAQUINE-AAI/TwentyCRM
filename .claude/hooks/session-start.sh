#!/bin/bash
# SessionStart hook: install gstack + ruflo Claude skill collections.
#
# Why: the web execution environment is ephemeral and `.claude/` is gitignored,
# so these third-party skill collections do not persist across containers. This
# hook reinstalls whatever is missing at the start of each session. It is
# idempotent (fast no-op once installed; the heavy bits are cached in the
# container image after the first cold run) and never fails the session.
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
GSTACK_DIR="$HOME/.claude/skills/gstack"

log() { echo "[session-start] $*"; }

# 1. gstack — global install under ~/.claude/skills/gstack
if [ -d "$GSTACK_DIR/bin" ]; then
  log "gstack already installed — skipping."
else
  log "Installing gstack..."
  rm -rf "$GSTACK_DIR" 2>/dev/null || true
  mkdir -p "$HOME/.claude/skills"
  if git clone --single-branch --depth 1 \
      https://github.com/garrytan/gstack.git "$GSTACK_DIR"; then
    # --team enables auto-update; non-interactive avoids prompts.
    ( cd "$GSTACK_DIR" && ./setup --team </dev/null ) \
      || log "gstack setup reported a non-zero exit (continuing)."
  else
    log "gstack clone failed (continuing without it)."
  fi
fi

# 2. ruflo — project install (skills/agents/commands under .claude/)
if [ -f "$PROJECT_DIR/.claude-flow/config.yaml" ]; then
  log "ruflo already initialized — skipping."
else
  log "Initializing ruflo..."
  ( cd "$PROJECT_DIR" && npx -y ruflo@latest init </dev/null ) \
    || log "ruflo init reported a non-zero exit (continuing)."
fi

log "Done."
exit 0
