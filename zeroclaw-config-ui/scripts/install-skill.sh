#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_SCRIPT="$ROOT_DIR/skills/zeroclaw-config-ui-maintainer/scripts/install-to-workspace.sh"

bash "$SKILL_SCRIPT"
