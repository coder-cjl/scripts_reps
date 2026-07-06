#!/bin/zsh

set -euo pipefail

EXIT_INVALID_USAGE=2
EXIT_INVALID_TARGET=3
EXIT_FILE_EXISTS=4

# AI-friendly contract:
# - Input: relative_dir (required)
# - Output files: logic.dart/state.dart/view.dart/model.dart/service.dart/repository.dart
# - Idempotency: fail when any target file exists unless --force is specified

print_usage() {
  cat <<'EOF'
用法:
  ./create_page_triplet.sh [--dry-run] [--json] [--force] <relative_dir>

参数:
  --dry-run    只打印将要创建的文件，不落盘
  --json       输出机器可读 JSON（便于 AI 工具解析）
  --force      允许覆盖已存在文件
  -h, --help   显示帮助

示例:
  ./create_page_triplet.sh lib/pages/order_detail
  ./create_page_triplet.sh --dry-run lib/pages/order_detail
  ./create_page_triplet.sh --json --force lib/pages/order_detail
EOF
}

json_escape() {
  local input="$1"
  INPUT="$input" python3 - <<'PY'
import json
import os

print(json.dumps(os.environ["INPUT"]))
PY
}

emit_error() {
  local code="$1"
  local message="$2"
  if [[ "$json_output" == "true" ]]; then
    printf '{"status":"error","code":%s,"message":%s}\n' "$code" "$(json_escape "$message")"
  else
    echo "$message"
  fi
  exit "$code"
}

emit_success() {
  local status_text="$1"
  local escaped_target
  escaped_target="$(json_escape "$target_dir")"

  if [[ "$json_output" == "true" ]]; then
    local file_list_json
    file_list_json="[$(printf '%s\n' "${files[@]}" | while IFS= read -r item; do json_escape "$item"; done | paste -sd ',' -)]"
    printf '{"status":%s,"target_dir":%s,"created_files":%s}\n' "$(json_escape "$status_text")" "$escaped_target" "$file_list_json"
  else
    for file in "${files[@]}"; do
      if [[ "$status_text" == "dry-run" ]]; then
        echo "将创建: $file"
      else
        echo "已创建: $file"
      fi
    done
  fi
}

dry_run="false"
force="false"
json_output="false"
target_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_usage
      exit 0
      ;;
    --dry-run)
      dry_run="true"
      ;;
    --force)
      force="true"
      ;;
    --json)
      json_output="true"
      ;;
    --)
      shift
      break
      ;;
    -*)
      emit_error "$EXIT_INVALID_USAGE" "未知参数: $1"
      ;;
    *)
      if [[ -n "$target_dir" ]]; then
        emit_error "$EXIT_INVALID_USAGE" "只允许一个目录参数: 已收到 $target_dir 和 $1"
      fi
      target_dir="$1"
      ;;
  esac
  shift
done

if [[ $# -gt 0 ]]; then
  emit_error "$EXIT_INVALID_USAGE" "存在多余参数: $*"
fi

if [[ -z "$target_dir" ]]; then
  emit_error "$EXIT_INVALID_USAGE" "缺少目录参数，使用 --help 查看用法"
fi

target_dir="${target_dir%/}"

if [[ -z "$target_dir" ]]; then
  emit_error "$EXIT_INVALID_TARGET" "目录不能为空"
fi

folder_name="${target_dir:t}"

to_pascal_case() {
  local input="$1"
  INPUT="$input" python3 - <<'PY'
import os
import re

text = os.environ["INPUT"]
parts = [part for part in re.split(r"[^A-Za-z0-9]+", text) if part]

if not parts:
    print("Page")
else:
    print("".join(part[:1].upper() + part[1:] for part in parts))
PY
}

class_name="$(to_pascal_case "$folder_name")"
base_class_name="$class_name"

if [[ "$base_class_name" == *Page ]]; then
  base_class_name="${base_class_name%Page}"
fi

if [[ -z "$base_class_name" ]]; then
  base_class_name="Page"
fi

logic_file="$target_dir/logic.dart"
state_file="$target_dir/state.dart"
view_file="$target_dir/view.dart"
model_file="$target_dir/model.dart"
service_file="$target_dir/service.dart"
repository_file="$target_dir/repository.dart"
files=(
  "$logic_file"
  "$state_file"
  "$view_file"
  "$model_file"
  "$service_file"
  "$repository_file"
)

for file in "${files[@]}"; do
  if [[ -e "$file" ]]; then
    if [[ "$force" != "true" ]]; then
      emit_error "$EXIT_FILE_EXISTS" "文件已存在: $file（可用 --force 覆盖）"
    fi
  fi
done

if [[ "$dry_run" == "true" ]]; then
  emit_success "dry-run"
  exit 0
fi

mkdir -p "$target_dir"

cat > "$logic_file" <<EOF
// ignore_for_file: unused_element

import 'state.dart';
import 'repository.dart';

class ${base_class_name}Logic {
  ${base_class_name}Logic({
    void Function()? onStateChanged,
    void Function(bool isLoading)? onLoadingChanged,
    void Function(String message)? onMessage,
  })  : _onStateChanged = onStateChanged,
        _onLoadingChanged = onLoadingChanged,
        _onMessage = onMessage;

  final ${base_class_name}State state = ${base_class_name}State();
  final ${base_class_name}Repository repository = ${base_class_name}Repository();

  final void Function()? _onStateChanged;
  final void Function(bool isLoading)? _onLoadingChanged;
  final void Function(String message)? _onMessage;

  void onInit() {}

  Future<void> onReady() async {}

  void onBack() {}

  void onClose() {}

  void _emitLoading(bool isLoading) {
    state.isLoading = isLoading;
    _onLoadingChanged?.call(isLoading);
  }

  void _emitMessage(String message) {
    _onMessage?.call(message);
  }

  void _emitState() {
    _onStateChanged?.call();
  }
}
EOF

cat > "$state_file" <<EOF
class ${base_class_name}State {
  String pageTitle = '页面标题';
  String pageDesc = '页面描述';
  bool isLoading = false;
}
EOF

cat > "$service_file" <<EOF
class ${base_class_name}Service {}
EOF

cat > "$repository_file" <<EOF
// ignore_for_file: unused_import

import 'model.dart';
import 'service.dart';

class ${base_class_name}Repository {
  final ${base_class_name}Service service = ${base_class_name}Service();
}
EOF

cat > "$model_file" <<EOF
class ${base_class_name}Payload<T> {
  final T? data;
  final String message;
  final bool isSuccess;
  final int code;

  ${base_class_name}Payload.success(this.data)
      : isSuccess = true,
        message = '',
        code = 0;

  ${base_class_name}Payload.failure(this.message, {this.code = -1})
      : isSuccess = false,
        data = null;
}
EOF

cat > "$view_file" <<EOF
import 'package:flutter/material.dart';
import 'logic.dart';

class ${base_class_name}Page extends StatefulWidget {
  const ${base_class_name}Page({super.key});

  static String get routeName => '/${folder_name}/page';

  @override
  State<${base_class_name}Page> createState() => _${base_class_name}PageState();
}

class _${base_class_name}PageState extends State<${base_class_name}Page> {
  late final ${base_class_name}Logic logic;

  @override
  void initState() {
    super.initState();

    logic = ${base_class_name}Logic(
      onStateChanged: () {
        if (!mounted) {
          return;
        }
        setState(() {});
      },
      onLoadingChanged: (isLoading) {
        if (!mounted) {
          return;
        }

        if (isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('加载中...')),
          );
        } else {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      },
      onMessage: (message) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    try {
      logic.onInit();
      if (!mounted) return;
      await logic.onReady();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('初始化失败，请稍后重试')),
      );
    }
  }

  @override
  void dispose() {
    logic.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          logic.state.pageTitle,
        ),
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            logic.onBack();
            return;
          }
        },
        child: Column(
          children: [
            ],
          ),
        ),
      ),
    );
  }
}
EOF

emit_success "success"
