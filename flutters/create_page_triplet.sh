#!/bin/zsh

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "用法: scripts/create_page_triplet.sh <relative_dir>"
  exit 1
fi

target_dir="$1"
target_dir="${target_dir%/}"

if [[ -z "$target_dir" ]]; then
  echo "目录不能为空"
  exit 1
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

for file in "$logic_file" "$state_file" "$view_file" "$model_file" "$service_file" "$repository_file"; do
  if [[ -e "$file" ]]; then
    echo "文件已存在: $file"
    exit 1
  fi
done

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

echo "已创建: $logic_file"
echo "已创建: $state_file"
echo "已创建: $view_file"
echo "已创建: $model_file"
echo "已创建: $service_file"
echo "已创建: $repository_file"
