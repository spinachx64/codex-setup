#!/usr/bin/env bash
# codex-setup.sh - 一键写入 Codex (ChatGPT app) 模型提供方配置
# 用法：
#   ./codex-setup.sh                                  交互输入
#   ./codex-setup.sh --name X --base-url URL --key K  非交互
set -euo pipefail

CONFIG_DIR="${CODEX_HOME:-$HOME/.codex}"
CONFIG="$CONFIG_DIR/config.toml"

NAME=""; BASE_URL=""; KEY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --name)     [ $# -ge 2 ] || { echo "错误: --name 缺少值" >&2; exit 2; }; NAME="$2"; shift 2 ;;
    --base-url) [ $# -ge 2 ] || { echo "错误: --base-url 缺少值" >&2; exit 2; }; BASE_URL="$2"; shift 2 ;;
    --key)      [ $# -ge 2 ] || { echo "错误: --key 缺少值" >&2; exit 2; }; KEY="$2"; shift 2 ;;
    -h|--help)  sed -n '2,5p' "$0"; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

die() { echo "错误: $*" >&2; exit 1; }

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

ask() { # ask <变量名> <提示> <是否隐藏输入>
  local __var="$1" __prompt="$2" __hide="${3:-}" __val
  while :; do
    if [ -n "$__hide" ]; then
      read -r -s -p "$__prompt" __val < /dev/tty
      echo
    else
      read -r -p "$__prompt" __val < /dev/tty
    fi
    [ -n "$__val" ] && break
    echo "不能为空，请重新输入。"
  done
  printf -v "$__var" '%s' "$__val"
}

[ -n "$NAME" ]     || ask NAME     "提供方名称 (英文/数字，最多 15 个字符): "
[ -n "$BASE_URL" ] || ask BASE_URL "base_url (如 https://api.example.com/v1): "
[ -n "$KEY" ]      || ask KEY      "API key (输入不回显): " hide

NAME="$(trim "$NAME")"
BASE_URL="$(trim "$BASE_URL")"

# --- 校验 ---
[[ "$NAME" =~ ^[A-Za-z0-9]{1,15}$ ]] \
  || die "name 只能是英文和数字，且不超过 15 个字符（当前: '$NAME'）"
case "$NAME" in
  openai|ollama|lmstudio) die "name '$NAME' 是 Codex 保留名称，请换一个名称" ;;
esac
case "$BASE_URL" in
  http://?*|https://?*) ;;
  *) die "base_url 必须是以 http:// 或 https:// 开头的网址（当前: '$BASE_URL'）" ;;
esac
[[ "$BASE_URL" != *[[:space:]]* && "$BASE_URL" != *\\* ]] \
  || die "base_url 不能包含空白字符或反斜杠"
[ -n "$KEY" ] || die "key 不能为空"

toml_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\b'/\\b}"
  value="${value//$'\t'/\\t}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\f'/\\f}"
  value="${value//$'\r'/\\r}"
  printf '%s' "$value"
}

ESCAPED_NAME="$(toml_escape "$NAME")"
ESCAPED_URL="$(toml_escape "$BASE_URL")"
ESCAPED_KEY="$(toml_escape "$KEY")"

# --- 读取并检查现有配置 ---
HAD_CONFIG=0
if [ -f "$CONFIG" ]; then
  HAD_CONFIG=1
  # 此脚本只做保守的行级更新。拒绝处理跨行结构，避免误把其中内容当成表头。
  if grep -Fq '"""' "$CONFIG" || grep -Fq "'''" "$CONFIG" ||
     grep -Eq '^[[:space:]]*[^#[:space:]][^=]*=[[:space:]]*\[[^]]*$' "$CONFIG"; then
    die "现有 config.toml 含有 TOML 多行字符串或多行数组，脚本为避免损坏文件已停止，文件没有改动"
  fi
fi

get_top_count() {
  awk -v k="$1" '
    function is_header(line) {
      return line ~ /^[[:space:]]*\[\[?.+\]\]?[[:space:]]*(#.*)?$/
    }
    function is_key(line, key) {
      return line ~ ("^[[:space:]]*" key "[[:space:]]*=") ||
             line ~ ("^[[:space:]]*[\"\047]" key "[\"\047][[:space:]]*=")
    }
    is_header($0) { exit }
    is_key($0, k) { count++ }
    END { print count + 0 }
  ' "$CONFIG"
}

get_top_line() {
  awk -v k="$1" '
    function is_header(line) {
      return line ~ /^[[:space:]]*\[\[?.+\]\]?[[:space:]]*(#.*)?$/
    }
    function is_key(line, key) {
      return line ~ ("^[[:space:]]*" key "[[:space:]]*=") ||
             line ~ ("^[[:space:]]*[\"\047]" key "[\"\047][[:space:]]*=")
    }
    is_header($0) { exit }
    is_key($0, k) { print; exit }
  ' "$CONFIG"
}

MODEL_LINE=""; EFFORT_LINE=""; HAS_MODEL=0; HAS_EFFORT=0
if [ "$HAD_CONFIG" -eq 1 ]; then
  MODEL_COUNT="$(get_top_count model)"
  EFFORT_COUNT="$(get_top_count model_reasoning_effort)"
  PROVIDER_COUNT="$(get_top_count model_provider)"
  [ "$MODEL_COUNT" -le 1 ] || die "现有 config.toml 含有重复的顶层 model，文件没有改动"
  [ "$EFFORT_COUNT" -le 1 ] || die "现有 config.toml 含有重复的顶层 model_reasoning_effort，文件没有改动"
  [ "$PROVIDER_COUNT" -le 1 ] || die "现有 config.toml 含有重复的顶层 model_provider，文件没有改动"

  MODEL_LINE="$(get_top_line model)"
  EFFORT_LINE="$(get_top_line model_reasoning_effort)"
  [ -n "$MODEL_LINE" ] && HAS_MODEL=1
  [ -n "$EFFORT_LINE" ] && HAS_EFFORT=1
fi

# 临时文件放在配置目录内，最终替换时不会跨文件系统。
mkdir -p "$CONFIG_DIR"
TMP="$(mktemp "$CONFIG_DIR/.config.toml.tmp.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

{
  echo "${MODEL_LINE:-model = \"gpt-5.6-sol\"}"
  echo "${EFFORT_LINE:-model_reasoning_effort = \"high\"}"
  echo "model_provider = \"$ESCAPED_NAME\""
  echo

  if [ "$HAD_CONFIG" -eq 1 ]; then
    awk -v name="$NAME" '
      function is_table_header(line) {
        return line ~ /^[[:space:]]*\[\[?.+\]\]?[[:space:]]*(#.*)?$/
      }
      function is_key(line, key) {
        return line ~ ("^[[:space:]]*" key "[[:space:]]*=") ||
               line ~ ("^[[:space:]]*[\"\047]" key "[\"\047][[:space:]]*=")
      }
      function header_name(line, value) {
        value = line
        sub(/^[[:space:]]*\[\[?/, "", value)
        sub(/\]\]?[[:space:]]*(#.*)?$/, "", value)
        gsub(/[[:space:]]/, "", value)
        gsub(/[\"\047]/, "", value)
        return value
      }
      BEGIN { target = "model_providers." name }
      {
        is_header = is_table_header($0)
        if (!past_top && is_header) past_top = 1
        if (!past_top && (is_key($0, "model") ||
                          is_key($0, "model_reasoning_effort") ||
                          is_key($0, "model_provider"))) next

        if (is_header) {
          header = header_name($0)
          if (header == target || index(header, target ".") == 1) {
            skip_provider = 1
            next
          }
          if (skip_provider) skip_provider = 0
        }
        if (!skip_provider) print
      }
    ' "$CONFIG"
  fi
} > "$TMP"

# 保证新 provider 表与前面的内容之间至少有一个空行。
if [ -s "$TMP" ] && [ -n "$(tail -c 1 "$TMP")" ]; then
  echo >> "$TMP"
fi
{
  echo
  echo "[model_providers.$NAME]"
  echo "name = \"$ESCAPED_NAME\""
  echo "base_url = \"$ESCAPED_URL\""
  echo 'wire_api = "responses"'
  echo "experimental_bearer_token = \"$ESCAPED_KEY\""
} >> "$TMP"

BACKUP=""
if [ "$HAD_CONFIG" -eq 1 ]; then
  BACKUP="$(mktemp "$CONFIG.bak.$(date +%Y%m%d%H%M%S).XXXXXX")"
  cp -p "$CONFIG" "$BACKUP"
fi

chmod 600 "$TMP"
mv "$TMP" "$CONFIG"
trap - EXIT

echo "完成：$CONFIG"
[ -n "$BACKUP" ] && echo "备份：$BACKUP"
[ "$HAS_MODEL" -eq 1 ]  && echo "提示：已存在 model，保留原值未修改。"
[ "$HAS_EFFORT" -eq 1 ] && echo "提示：已存在 model_reasoning_effort，保留原值未修改。"
echo "重启 ChatGPT / Codex app 生效。"
