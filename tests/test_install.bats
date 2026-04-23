#!/usr/bin/env bats
# Integration tests for install.sh using the fake Codex.

setup() {
  TESTROOT="$(mktemp -d)"
  export HOME="$TESTROOT/home"
  export CODEX_HOME="$TESTROOT/codex-config"
  mkdir -p "$HOME" "$CODEX_HOME"
  echo 'model = "test-model-9"' > "$CODEX_HOME/config.toml"

  KIT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export KIT_DIR
  export PATH="$KIT_DIR/tests/fixtures/bin:$PATH"
}

teardown() {
  rm -rf "$TESTROOT"
}

@test "--dry-run does not create any files" {
  run bash "$KIT_DIR/install.sh" --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "$HOME/.claude/scripts/ask-codex.sh" ]
  [ ! -f "$HOME/.claude/CLAUDE.md" ]
  [[ "$output" == *"dry-run"* ]]
}

@test "fresh install creates wrapper and versioned CLAUDE.md block" {
  run bash "$KIT_DIR/install.sh"
  [ "$status" -eq 0 ]
  [ -x "$HOME/.claude/scripts/ask-codex.sh" ]
  [ -f "$HOME/.claude/CLAUDE.md" ]
  grep -q "CLAUDE-CODEX-KIT:BEGIN v1.1.0" "$HOME/.claude/CLAUDE.md"
  grep -q "CLAUDE-CODEX-KIT:END" "$HOME/.claude/CLAUDE.md"
}

@test "re-install at same version is idempotent -- no duplicate block" {
  bash "$KIT_DIR/install.sh" >/dev/null
  bash "$KIT_DIR/install.sh" >/dev/null
  count=$(grep -c "CLAUDE-CODEX-KIT:BEGIN" "$HOME/.claude/CLAUDE.md")
  [ "$count" -eq 1 ]
}

@test "upgrade replaces older version block in place, preserves surrounding content" {
  mkdir -p "$HOME/.claude"
  cat > "$HOME/.claude/CLAUDE.md" <<'EOF'
## User's own preamble

Some important user rule that should NOT be modified.

<!-- CLAUDE-CODEX-KIT:BEGIN v0.0.1 -->
ancient kit contents that must be replaced
<!-- CLAUDE-CODEX-KIT:END -->

## User's own footer
EOF

  run bash "$KIT_DIR/install.sh"
  [ "$status" -eq 0 ]
  grep -q "CLAUDE-CODEX-KIT:BEGIN v1.1.0" "$HOME/.claude/CLAUDE.md"
  ! grep -q "ancient kit contents" "$HOME/.claude/CLAUDE.md"
  grep -q "Some important user rule" "$HOME/.claude/CLAUDE.md"
  grep -q "User's own footer" "$HOME/.claude/CLAUDE.md"
  # backup was created
  ls "$HOME/.claude/" | grep -q "CLAUDE.md.bak."
}

@test "--force replaces block even at the same version" {
  bash "$KIT_DIR/install.sh" >/dev/null
  run bash "$KIT_DIR/install.sh" --force
  [ "$status" -eq 0 ]
  ls "$HOME/.claude/" | grep -q "CLAUDE.md.bak."
}

@test "missing codex CLI on PATH fails with clear error" {
  # Run with a minimal PATH that excludes our fake-codex fixture and real codex
  run env -i HOME="$HOME" CODEX_HOME="$CODEX_HOME" PATH="/usr/bin:/bin" bash "$KIT_DIR/install.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Codex CLI not found"* ]]
}
