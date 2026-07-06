#!/bin/zsh

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "用法: ./create_page_triplet_swift.sh <relative_dir>"
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

logic_file="$target_dir/logic.swift"
state_file="$target_dir/state.swift"
view_file="$target_dir/view.swift"
model_file="$target_dir/model.swift"
service_file="$target_dir/service.swift"
repository_file="$target_dir/repository.swift"

for file in "$logic_file" "$state_file" "$view_file" "$model_file" "$service_file" "$repository_file"; do
  if [[ -e "$file" ]]; then
    echo "文件已存在: $file"
    exit 1
  fi
done

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
            do {
                self.logic.onInit()
                await self.logic.onReady()
                self.render()
            } catch {
                self.showToast("初始化失败，请稍后重试")
            }
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

echo "已创建: $logic_file"
echo "已创建: $state_file"
echo "已创建: $view_file"
echo "已创建: $model_file"
echo "已创建: $service_file"
echo "已创建: $repository_file"
