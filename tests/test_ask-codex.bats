#!/usr/bin/env bats
# Unit tests for bin/ask-codex.sh using the fake Codex in tests/fixtures/bin/.

setup() {
  TESTROOT="$(mktemp -d)"
  export HOME="$TESTROOT/home"
  export CODEX_HOME="$TESTROOT/codex-config"
  mkdir -p "$HOME" "$CODEX_HOME"
  echo 'model = "test-model-9"' > "$CODEX_HOME/config.toml"

  KIT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export KIT_DIR
  export PATH="$KIT_DIR/tests/fixtures/bin:$PATH"

  WORKREPO="$TESTROOT/repo"
  mkdir -p "$WORKREPO"
  cd "$WORKREPO"
  git init -q
  echo "seed" > README.md
  git -c user.email=t@example.com -c user.name=tester add README.md
  git -c user.email=t@example.com -c user.name=tester commit -q -m "seed"
}

teardown() {
  rm -rf "$TESTROOT"
}

@test "--version prints kit version 1.0.0" {
  run bash "$KIT_DIR/bin/ask-codex.sh" --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.0.0"* ]]
}

@test "--check-model prints effective model and reasoning" {
  run bash "$KIT_DIR/bin/ask-codex.sh" --check-model
  [ "$status" -eq 0 ]
  [[ "$output" == *"test-model-9"* ]]
  [[ "$output" == *"xhigh"* ]]
}

@test "missing slug exits 2" {
  run bash "$KIT_DIR/bin/ask-codex.sh"
  [ "$status" -eq 2 ]
}

@test "invalid slug (uppercase) exits 2" {
  run bash "$KIT_DIR/bin/ask-codex.sh" "UpperCaseNope" "prompt"
  [ "$status" -eq 2 ]
}

@test "invalid slug (special chars) exits 2" {
  run bash "$KIT_DIR/bin/ask-codex.sh" "slug!with!bang" "prompt"
  [ "$status" -eq 2 ]
}

@test "unknown mode exits 2" {
  run bash "$KIT_DIR/bin/ask-codex.sh" --mode=invalid my-slug "prompt"
  [ "$status" -eq 2 ]
}

@test "search mode produces a report with expected content" {
  run bash "$KIT_DIR/bin/ask-codex.sh" --mode=search my-search-slug "find things"
  [ "$status" -eq 0 ]
  [[ "$output" == *".codex-reports/"* ]]
  [ -f "$output" ]
  report_content=$(cat "$output")
  [[ "$report_content" == *"Mock Codex response"* ]]
  [[ "$report_content" == *"my-search-slug"* ]]
  [[ "$report_content" == *"\`search\`"* ]]
}

@test "analyze mode produces a report" {
  run bash "$KIT_DIR/bin/ask-codex.sh" --mode=analyze my-analyze-slug "analyze thing"
  [ "$status" -eq 0 ]
  [ -f "$output" ]
  grep -q "\`analyze\`" "$output"
}

@test "second-opinion mode produces a report" {
  run bash "$KIT_DIR/bin/ask-codex.sh" --mode=second-opinion my-review-slug "review this"
  [ "$status" -eq 0 ]
  [ -f "$output" ]
  grep -q "\`second-opinion\`" "$output"
}

@test "consult mode produces a report" {
  run bash "$KIT_DIR/bin/ask-codex.sh" --mode=consult my-design-slug "design thing"
  [ "$status" -eq 0 ]
  [ -f "$output" ]
  grep -q "\`consult\`" "$output"
}

@test "report filename includes mode and 6-hex random suffix" {
  run bash "$KIT_DIR/bin/ask-codex.sh" --mode=search parallel-slug "prompt"
  [ "$status" -eq 0 ]
  base=$(basename "$output")
  [[ "$base" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}-parallel-slug-search-[0-9a-f]{6}\.md$ ]]
}

@test "parallel invocations with the same slug produce different filenames" {
  f1=$(bash "$KIT_DIR/bin/ask-codex.sh" --mode=search same-slug "p1")
  f2=$(bash "$KIT_DIR/bin/ask-codex.sh" --mode=search same-slug "p2")
  [ "$f1" != "$f2" ]
  [ -f "$f1" ]
  [ -f "$f2" ]
}

@test "--timeout without timeout binary fails loudly" {
  if command -v gtimeout >/dev/null 2>&1 || command -v timeout >/dev/null 2>&1; then
    skip "a timeout binary is present on this system; cannot test missing-binary case"
  fi
  run bash "$KIT_DIR/bin/ask-codex.sh" --timeout=30 --mode=search my-slug "prompt"
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires"* ]]
}

@test "prompt from stdin is accepted when positional omitted" {
  run bash -c "echo 'stdin prompt' | '$KIT_DIR/bin/ask-codex.sh' --mode=search stdin-slug"
  [ "$status" -eq 0 ]
  [ -f "$output" ]
  grep -q "stdin prompt" "$output"
}
