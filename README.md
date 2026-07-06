# AI Script Usage

This document defines a stable contract for AI tools (Codex/Cursor/Claude/GitHub Copilot) to call page scaffold scripts.

## Scripts

- Dart path: `darts/create_page_triplet.sh`
- Swift path: `swifts/create_page_triplet_swift.sh`

## Options

- `--dry-run`: preview files only, no write.
- `--json`: output machine-readable JSON.
- `--force`: allow overwriting existing files.
- `-h`, `--help`: print usage.

## Output Files (Dart)

- `logic.dart`
- `state.dart`
- `view.dart`
- `model.dart`
- `service.dart`
- `repository.dart`

## Output Files (Swift)

- `logic.swift`
- `state.swift`
- `view.swift`
- `model.swift`
- `service.swift`
- `repository.swift`

## Exit Codes

- `0`: success
- `2`: invalid usage or arguments
- `3`: invalid target directory
- `4`: file exists (without `--force`)

## Command Contract (Dart)

```bash
./darts/create_page_triplet.sh [--dry-run] [--json] [--force] <relative_dir>
```

## Command Contract (Swift)

```bash
./swifts/create_page_triplet_swift.sh [--dry-run] [--json] [--force] <relative_dir>
```

## Quick Start

```bash
cd scripts_reps
./darts/create_page_triplet.sh --dry-run --json lib/pages/order_detail
./darts/create_page_triplet.sh --json lib/pages/order_detail

./swifts/create_page_triplet_swift.sh --dry-run --json ios/pages/order_detail
./swifts/create_page_triplet_swift.sh --json ios/pages/order_detail
```

## JSON Output Shape

Success:

```json
{
  "status": "success",
  "target_dir": "<relative_dir>",
  "created_files": [
    "..."
  ]
}
```

Dry-run:

```json
{
  "status": "dry-run",
  "target_dir": "<relative_dir>",
  "created_files": ["..."]
}
```

Error:

```json
{
  "status": "error",
  "code": 4,
  "message": "文件已存在: <relative_dir>/logic.*（可用 --force 覆盖）"
}
```

## AI Agent Recommendations

- Prefer `--json` to avoid parsing localized plain text.
- Use `--dry-run` first, then run without dry-run.
- If code `4` occurs, decide explicitly whether to retry with `--force`.
- Do not pass absolute paths unless repository policy allows it.
