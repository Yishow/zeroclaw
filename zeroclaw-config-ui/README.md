# ZeroClaw Config UI (Tauri)

Independent Tauri desktop app for editing `~/.zeroclaw/config.toml` with:
- schema-driven structured editor (`zeroclaw config schema`)
- extension-safe editor (`extensions.*` keeps unknown top-level keys editable)
- AI-curated Chinese field help + examples (`web/field-help.zh.generated.json`)
- raw TOML editor
- atomic save + backup (`config.toml.bak`)
- default permission hardening to `600` on save (Unix)

## Project Layout

- `src-tauri/`: Tauri Rust backend
- `web/`: static frontend (no extra framework)
- `scripts/build-to-home.sh`: build release and install binary to `~/.zeroclaw/`
- `scripts/run.sh`: run in debug mode
- `scripts/install-skill.sh`: install this project skill into ZeroClaw workspace
- `skills/zeroclaw-config-ui-maintainer/`: reusable skill (with workflow + checks)
- `web/field-help.zh.generated.json`: 欄位中文說明與 TOML 範例資料

## Prerequisites

- Rust toolchain
- `zeroclaw` CLI in `PATH` (or set `ZEROCLAW_BIN`)

## Run

```bash
./zeroclaw-config-ui/scripts/run.sh
```

## Build and Install to `~/.zeroclaw/`

```bash
./zeroclaw-config-ui/scripts/build-to-home.sh
```

Result binary path:

```bash
~/.zeroclaw/zeroclaw-config-ui
```

## Install as ZeroClaw Skill

```bash
./zeroclaw-config-ui/scripts/install-skill.sh
zeroclaw skills list
```

Installed skill name:

```text
zeroclaw-config-ui-maintainer
```

## 更新欄位說明（AI 產出）

1. 依技能流程，用 AI 分析 `README.md` 與 `docs/config-reference.md`。
2. 更新 `zeroclaw-config-ui/web/field-help.zh.generated.json`（欄位用途 + 使用建議 + 範例）。
3. 執行驗證：

```bash
python3 zeroclaw-config-ui/skills/zeroclaw-config-ui-maintainer/scripts/check-field-help-json.py
bash zeroclaw-config-ui/skills/zeroclaw-config-ui-maintainer/scripts/check-zh-descriptions.sh
```

## Optional Environment Variables

- `ZEROCLAW_BIN`: override `zeroclaw` executable name/path
- `ZEROCLAW_CONFIG_PATH`: override config file path (default: `~/.zeroclaw/config.toml`)
- `ZEROCLAW_OUTPUT_DIR`: override install output dir for build script
- `ZEROCLAW_SKILLS_DIR`: override destination of skill installation
