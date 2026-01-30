#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${SCRIPT_DIR}/skyland-auto-sign"
MAIN_PY="${REPO_DIR}/src/main.py"

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

run_and_capture() {
  local output
  local exit_code=0

  set +e
  output="$("$@" 2>&1)"
  exit_code=$?
  set -e

  if [ -n "$output" ]; then
    printf '%s\n' "$output" >&2
  fi

  printf '%s' "$output"
  return $exit_code
}

normalize_output() {
  local content="$1"

  content="${content//$'\r'/$'\n'}"
  content="$(printf '%s' "$content" | awk '{
    len = length($0)
    if (len == 0) {
      print ""
      next
    }
    for (i = 1; i <= len; i += 120) {
      print substr($0, i, 120)
    }
  }')"

  echo "$content"
}

main() {
  if [ ! -f "$MAIN_PY" ]; then
    local msg="未找到 main.py: ${MAIN_PY}"
    echo "$msg" >&2
    send_notify "Skland 运行失败" "$msg"
    return 1
  fi

  if [ -z "${SKLAND_TOKEN:-}" ]; then
    local msg="未设置环境变量 SKLAND_TOKEN"
    echo "$msg" >&2
    send_notify "Skland 运行失败" "$msg"
    return 1
  fi

  local python_cmd
  if command -v python3 >/dev/null 2>&1; then
    python_cmd="python3"
  elif command -v python >/dev/null 2>&1; then
    python_cmd="python"
  else
    local msg="未找到 python3 或 python 解释器"
    echo "$msg" >&2
    send_notify "Skland 运行失败" "$msg"
    return 1
  fi

  export TOKEN="$SKLAND_TOKEN"
  if [ -n "${SKLAND_SC_KEY:-}" ]; then
    export SC3_SENDKEY="$SKLAND_SC_KEY"
  fi

  local output
  local exit_code=0
  set +e
  output="$(cd "$REPO_DIR" && run_and_capture "$python_cmd" "src/main.py")"
  exit_code=$?
  set -e

  local normalized_output
  normalized_output="$(normalize_output "$output")"

  local status
  if [ $exit_code -eq 0 ]; then
    status="成功"
  else
    status="失败"
  fi

  local title="Skland 运行${status}"
  local content="退出码: ${exit_code}\n输出:\n${normalized_output}"
  send_notify "$title" "$content"

  return $exit_code
}

main "$@"
