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

require_pattern "async function loadFieldHelpDocs()" "field-help document loader"
require_pattern "fetch(\"./field-help.zh.generated.json\"" "generated field-help JSON fetch"
require_pattern "function buildFieldHelpLines(path, schemaNode, type, nullable)" "buildFieldHelpLines function"
require_pattern "function renderFieldHelp(parentEl, path, schemaNode, type, nullable)" "renderFieldHelp function"
require_pattern "const lines = buildFieldHelpLines(path, schemaNode, type, nullable);" "renderFieldHelp uses buildFieldHelpLines"
require_pattern "renderFieldHelp(field, path, propertySchema, type, nullable);" "main field rendering path uses help renderer"
require_pattern "renderFieldHelp(field, path, { type: \"object\" }, \"object\", false);" "extensions path uses help renderer"

render_property_line="$(rg -n '^function renderProperty\(' "$APP_JS" | cut -d: -f1)"
render_help_line="$(rg -n 'renderFieldHelp\(field, path, propertySchema, type, nullable\);' "$APP_JS" | cut -d: -f1)"
nullable_branch_line="$(awk -v s="$render_property_line" '
  NR > s && /if \(nullable\) \{/ { print NR; exit }
' "$APP_JS")"

if [[ -z "$render_property_line" || -z "$render_help_line" || -z "$nullable_branch_line" ]]; then
  echo "[FAIL] cannot locate renderProperty/help/nullable lines for smoke test"
  exit 1
fi

if (( render_help_line <= render_property_line )); then
  echo "[FAIL] renderFieldHelp call order is invalid in renderProperty"
  exit 1
fi

if (( render_help_line >= nullable_branch_line )); then
  echo "[FAIL] renderFieldHelp should run before nullable/type rendering branches"
  exit 1
fi

echo "[OK] UI field-help smoke checks passed."
