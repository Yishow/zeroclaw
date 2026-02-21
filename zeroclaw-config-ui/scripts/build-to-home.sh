#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_PATH="$ROOT_DIR/src-tauri/Cargo.toml"
OUTPUT_DIR="${ZEROCLAW_OUTPUT_DIR:-$HOME/.zeroclaw}"
BIN_NAME="zeroclaw-config-ui"
ICON_DIR="$ROOT_DIR/src-tauri/icons"
ICON_PATH="$ICON_DIR/icon.png"
# 1x1 RGBA PNG
FALLBACK_ICON_BASE64="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg=="

ensure_tauri_icon() {
  if [[ -f "$ICON_PATH" ]] && file "$ICON_PATH" | grep -q "RGBA"; then
    return
  fi

  mkdir -p "$ICON_DIR"
  if base64 --help 2>&1 | grep -q -- "--decode"; then
    printf "%s" "$FALLBACK_ICON_BASE64" | base64 --decode > "$ICON_PATH"
  else
    printf "%s" "$FALLBACK_ICON_BASE64" | base64 -D > "$ICON_PATH"
  fi
}

ensure_tauri_icon
cargo build --manifest-path "$MANIFEST_PATH" --release

mkdir -p "$OUTPUT_DIR"
cp "$ROOT_DIR/src-tauri/target/release/$BIN_NAME" "$OUTPUT_DIR/$BIN_NAME"
chmod 755 "$OUTPUT_DIR/$BIN_NAME"

echo "Built and installed: $OUTPUT_DIR/$BIN_NAME"
