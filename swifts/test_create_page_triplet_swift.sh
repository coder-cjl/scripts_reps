#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
SCRIPT="$SCRIPT_DIR/create_page_triplet_swift.sh"

if [[ ! -x "$SCRIPT" ]]; then
  chmod +x "$SCRIPT"
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

run_test() {
  local name="$1"
  shift
  echo "[TEST] $name"
  "$@"
}

run_test "dry-run json should succeed" \
  zsh -c "cd '$tmp_dir' && '$SCRIPT' --dry-run --json ios/pages/demo > out.json && grep -q '\"status\":\"dry-run\"' out.json"

run_test "real generation should create 6 files" \
  zsh -c "cd '$tmp_dir' && '$SCRIPT' ios/pages/demo >/dev/null && [[ -f ios/pages/demo/logic.swift ]] && [[ -f ios/pages/demo/state.swift ]] && [[ -f ios/pages/demo/view.swift ]] && [[ -f ios/pages/demo/model.swift ]] && [[ -f ios/pages/demo/service.swift ]] && [[ -f ios/pages/demo/repository.swift ]]"

run_test "second generation without force should fail with code 4" \
  zsh -c "cd '$tmp_dir' && set +e; '$SCRIPT' --json ios/pages/demo > err.json; exit_code=\$?; set -e; [[ \$exit_code -eq 4 ]] && grep -q '\"status\":\"error\"' err.json"

run_test "generation with force should succeed" \
  zsh -c "cd '$tmp_dir' && '$SCRIPT' --force --json ios/pages/demo > force.json && grep -q '\"status\":\"success\"' force.json"

echo "All tests passed."
