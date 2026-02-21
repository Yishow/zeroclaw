#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SKILL_NAME="zeroclaw-config-ui-maintainer"
SRC_DIR="$ROOT_DIR/skills/$SKILL_NAME"
DST_DIR="${ZEROCLAW_SKILLS_DIR:-$HOME/.zeroclaw/workspace/skills}/$SKILL_NAME"

mkdir -p "$(dirname "$DST_DIR")"
rm -rf "$DST_DIR"
cp -R "$SRC_DIR" "$DST_DIR"

echo "Installed skill: $DST_DIR"
echo "Run: zeroclaw skills list"
