#!/bin/zsh

set -euo pipefail

EXIT_INVALID_USAGE=2
EXIT_INVALID_TARGET=3
EXIT_FILE_EXISTS=4

# AI-friendly contract:
# - Input: relative_dir (required)
# - Output files: logic.swift/state.swift/view.swift/model.swift/service.swift/repository.swift
# - Idempotency: fail when any target file exists unless --force is specified

print_usage() {
  cat <<'EOF'
用法:
  ./create_page_triplet_swift.sh [--dry-run] [--json] [--force] <relative_dir>

参数:
  --dry-run    只打印将要创建的文件，不落盘
  --json       输出机器可读 JSON（便于 AI 工具解析）
  --force      允许覆盖已存在文件
  -h, --help   显示帮助

示例:
  ./create_page_triplet_swift.sh ios/pages/order_detail
  ./create_page_triplet_swift.sh --dry-run ios/pages/order_detail
  ./create_page_triplet_swift.sh --json --force ios/pages/order_detail
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

logic_file="$target_dir/logic.swift"
state_file="$target_dir/state.swift"
view_file="$target_dir/view.swift"
model_file="$target_dir/model.swift"
service_file="$target_dir/service.swift"
repository_file="$target_dir/repository.swift"

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
import Foundation

final class ${base_class_name}Logic {
    private(set) var state = ${base_class_name}State()
    private let repository = ${base_class_name}Repository()

    private var onStateChanged: (() -> Void)?
    private var onLoadingChanged: ((Bool) -> Void)?
    private var onMessage: ((String) -> Void)?

    func bind(
        onStateChanged: (() -> Void)? = nil,
        onLoadingChanged: ((Bool) -> Void)? = nil,
        onMessage: ((String) -> Void)? = nil
    ) {
        self.onStateChanged = onStateChanged
        self.onLoadingChanged = onLoadingChanged
        self.onMessage = onMessage
    }

    func onInit() {}

    func onReady() async {}

    func onBack() {}

    func onClose() {}

    private func emitLoading(_ isLoading: Bool) {
        state.isLoading = isLoading
        onLoadingChanged?(isLoading)
    }

    private func emitMessage(_ message: String) {
        onMessage?(message)
    }

    private func emitState() {
        onStateChanged?()
    }
}
EOF

cat > "$state_file" <<EOF
import Foundation

struct ${base_class_name}State {
    var pageTitle = "页面标题"
    var pageDesc = "页面描述"
    var isLoading = false
}
EOF

cat > "$service_file" <<EOF
import Foundation

final class ${base_class_name}Service {}
EOF

cat > "$repository_file" <<EOF
import Foundation

final class ${base_class_name}Repository {
    let service = ${base_class_name}Service()
}
EOF

cat > "$model_file" <<EOF
import Foundation

struct ${base_class_name}Payload<T> {
    let data: T?
    let message: String
    let isSuccess: Bool
    let code: Int

    static func success(_ data: T?) -> ${base_class_name}Payload<T> {
        ${base_class_name}Payload<T>(data: data, message: "", isSuccess: true, code: 0)
    }

    static func failure(_ message: String, code: Int = -1) -> ${base_class_name}Payload<T> {
        ${base_class_name}Payload<T>(data: nil, message: message, isSuccess: false, code: code)
    }
}
EOF

cat > "$view_file" <<EOF
import UIKit

final class ${base_class_name}PageViewController: UIViewController {
    static let routeName = "/${folder_name}/page"

    private let logic = ${base_class_name}Logic()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private let descLabel: UILabel = {
        let label = UILabel()
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 15)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let confirmButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "确定"
        let button = UIButton(configuration: configuration, primaryAction: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindLogic()
        bootstrap()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            logic.onBack()
            logic.onClose()
        }
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(descLabel)
        view.addSubview(confirmButton)
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            descLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            descLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            descLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            confirmButton.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 24),
            confirmButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: confirmButton.bottomAnchor, constant: 20)
        ])

        confirmButton.addTarget(self, action: #selector(onConfirmTapped), for: .touchUpInside)
    }

    private func bindLogic() {
        logic.bind(
            onStateChanged: { [weak self] in
                self?.render()
            },
            onLoadingChanged: { [weak self] isLoading in
                guard let self else { return }
                isLoading ? self.loadingIndicator.startAnimating() : self.loadingIndicator.stopAnimating()
            },
            onMessage: { [weak self] message in
                self?.showToast(message)
            }
        )
    }

    private func bootstrap() {
        Task { [weak self] in
            guard let self else { return }
            self.logic.onInit()
            await self.logic.onReady()
            self.render()
        }
    }

    private func render() {
        title = logic.state.pageTitle
        descLabel.text = logic.state.pageDesc
    }

    private func showToast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak alert] in
            alert?.dismiss(animated: true)
        }
    }

    @objc
    private func onConfirmTapped() {}
}
EOF

emit_success "success"
