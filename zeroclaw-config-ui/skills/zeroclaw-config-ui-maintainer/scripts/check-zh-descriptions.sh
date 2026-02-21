#!/usr/bin/env bash
set -euo pipefail

APP_JS="zeroclaw-config-ui/web/app.js"

require_pattern() {
  local pattern="$1"
  local hint="$2"
  if ! rg -n --fixed-strings "$pattern" "$APP_JS" >/dev/null; then
    echo "[FAIL] missing pattern: $hint"
    exit 1
  fi
}

require_pattern "function buildFieldHelpLines(path, schemaNode, type, nullable)" "buildFieldHelpLines function"
require_pattern "function renderFieldHelp(parentEl, path, schemaNode, type, nullable)" "renderFieldHelp function"
require_pattern "title.textContent = \"中文說明\";" "Chinese help title"
require_pattern "用途：" "Chinese purpose hint"
require_pattern "資料型別：" "Chinese type hint"
require_pattern "可為空值：" "Chinese nullable hint"
require_pattern "安全提醒：" "Chinese sensitive-field warning"

# Ensure help renderer is actually used in field rendering paths.
require_pattern "renderFieldHelp(field, path, propertySchema, type, nullable);" "renderFieldHelp call for standard fields"
require_pattern "renderFieldHelp(field, path, { type: \"object\" }, \"object\", false);" "renderFieldHelp call for extensions object"

echo "[OK] Chinese description contract checks passed."
