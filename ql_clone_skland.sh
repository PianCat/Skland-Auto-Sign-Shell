#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://gitee.com/FancyCabbage/skyland-auto-sign.git"
REPO_DIR="${SCRIPT_DIR}/skyland-auto-sign"

limit_content() {
  local content="$1"
  local max_len=2000
  if [ ${#content} -gt $max_len ]; then
    content="${content:0:$max_len}..."
  fi
  echo "$content"
}

send_notify() {
  local title="$1"
  local content="$2"
  local content_trimmed
  content_trimmed="$(limit_content "$content")"

  local notify_js_paths=(
    "${SCRIPT_DIR}/sendNotify.js"
    "${SCRIPT_DIR}/../sendNotify.js"
    "/ql/scripts/sendNotify.js"
  )
  local notify_py_paths=(
    "${SCRIPT_DIR}/notify.py"
    "${SCRIPT_DIR}/../notify.py"
    "/ql/scripts/notify.py"
  )
  local notify_sh_paths=(
    "${SCRIPT_DIR}/sendNotify.sh"
    "${SCRIPT_DIR}/../sendNotify.sh"
    "/ql/scripts/sendNotify.sh"
    "/ql/scripts/notify.sh"
  )

  local path
  for path in "${notify_js_paths[@]}"; do
    if [ -f "$path" ] && command -v node >/dev/null 2>&1; then
      node "$path" "$title" "$content_trimmed"
      return 0
    fi
  done

  for path in "${notify_py_paths[@]}"; do
    if [ -f "$path" ]; then
      if command -v python3 >/dev/null 2>&1; then
        python3 "$path" "$title" "$content_trimmed"
        return 0
      fi
      if command -v python >/dev/null 2>&1; then
        python "$path" "$title" "$content_trimmed"
        return 0
      fi
    fi
  done

  for path in "${notify_sh_paths[@]}"; do
    if [ -f "$path" ]; then
      # shellcheck source=/dev/null
      . "$path"
      if declare -F send_notify >/dev/null 2>&1; then
        send_notify "$title" "$content_trimmed"
        return 0
      fi
      if declare -F notify >/dev/null 2>&1; then
        notify "$title" "$content_trimmed"
        return 0
      fi
    fi
  done

  echo "$title"
  echo "$content_trimmed"
}

main() {
  local action
  local output
  local exit_code=0

  if [ -d "${REPO_DIR}/.git" ]; then
    action="拉取更新"
    set +e
    output="$(git -C "$REPO_DIR" pull --rebase 2>&1)"
    exit_code=$?
    set -e
  else
    action="克隆仓库"
    set +e
    output="$(git clone "$REPO_URL" "$REPO_DIR" 2>&1)"
    exit_code=$?
    set -e
  fi

  local status
  if [ $exit_code -eq 0 ]; then
    status="成功"
  else
    status="失败"
  fi

  local title="Skland 仓库${action}${status}"
  local content="动作: ${action}\n路径: ${REPO_DIR}\n退出码: ${exit_code}\n输出:\n${output}"
  send_notify "$title" "$content"

  return $exit_code
}

main "$@"
