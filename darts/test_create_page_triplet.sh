#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
SCRIPT="$SCRIPT_DIR/create_page_triplet.sh"

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
  zsh -c "cd '$tmp_dir' && '$SCRIPT' --dry-run --json lib/pages/demo > out.json && grep -q '\"status\":\"dry-run\"' out.json"

run_test "real generation should create 6 files" \
  zsh -c "cd '$tmp_dir' && '$SCRIPT' lib/pages/demo >/dev/null && [[ -f lib/pages/demo/logic.dart ]] && [[ -f lib/pages/demo/state.dart ]] && [[ -f lib/pages/demo/view.dart ]] && [[ -f lib/pages/demo/model.dart ]] && [[ -f lib/pages/demo/service.dart ]] && [[ -f lib/pages/demo/repository.dart ]]"

run_test "second generation without force should fail with code 4" \
  zsh -c "cd '$tmp_dir' && set +e; '$SCRIPT' --json lib/pages/demo > err.json; exit_code=\$?; set -e; [[ \$exit_code -eq 4 ]] && grep -q '\"status\":\"error\"' err.json"

run_test "generation with force should succeed" \
  zsh -c "cd '$tmp_dir' && '$SCRIPT' --force --json lib/pages/demo > force.json && grep -q '\"status\":\"success\"' force.json"

echo "All tests passed."
