# ZeroClaw Config UI Maintainer

Maintain and extend the standalone Tauri app in `zeroclaw-config-ui` for editing `~/.zeroclaw/config.toml`.

Use this skill for all work under `zeroclaw-config-ui/`.

## Scope

- Tauri backend: `src-tauri/src/main.rs`
- Schema-driven frontend: `web/app.js`, `web/index.html`, `web/styles.css`
- Build/install scripts: `scripts/`

## Required Workflow

1. Load schema dynamically from `zeroclaw config schema` (no hardcoded config tables).
2. Keep renderer generic for object/array/map/nullable/enum fields.
3. Preserve unknown extension keys by editing them in the `extensions` section (`extensions.*`).
4. Every newly surfaced field must include Chinese explanation text in the UI.
5. Do not bypass `buildFieldHelpLines`/`renderFieldHelp` for newly rendered field branches.
6. Use AI analysis (not regex parsing scripts) to read `README.md` and config docs, then update `web/field-help.zh.generated.json`.
7. For each newly documented field, include both `purpose_zh` and at least one usage example.
8. `usage_zh` is required for each documented field (not optional).
9. Save config atomically and keep backup behavior.
10. Keep output binary install path under `~/.zeroclaw/`.

## Extension Auto-Add Contract

When ZeroClaw introduces new config keys:

- New schema keys must appear automatically in section selector and form.
- Unknown top-level keys not yet in schema must stay editable in `extensions.*`.
- New schema keys must inherit Chinese help output via the shared help renderer.
- No manual UI field wiring per new config key unless custom UX is explicitly required.

## Chinese Description Contract

- The field help block title must remain `中文說明`.
- Field help must include:
  - purpose summary in Chinese
  - type/nullable hints in Chinese
  - enum/default/constraint hints when available
- Sensitive fields must show a Chinese security reminder.
- If schema adds constraints (min/max/length/pattern), reflect them in Chinese hints automatically.

## AI Documentation Output Contract

- Output file: `zeroclaw-config-ui/web/field-help.zh.generated.json`
- Source of truth for narrative/help examples: `README.md`, `docs/config-reference.md` (and related docs when needed)
- Generation method: AI summarization and mapping by field path
- Authoring reference: `skills/zeroclaw-config-ui-maintainer/references/ai-field-doc-authoring.zh.md`
- Required fields per entry:
  - `purpose_zh`: Chinese purpose description
  - `usage_zh`: Chinese usage notes (required)
  - `examples`: TOML examples mapped to the same field path
- Path convention:
  - use canonical schema-style paths such as `gateway.port`, `model_routes.[].hint`, `extensions.*`
  - avoid ad-hoc path aliases
- Metadata contract:
  - keep `_meta.generated_at` fresh
  - keep `_meta.schema_leaf_count` and `_meta.schema_signature` aligned with current `zeroclaw config schema`
- High-risk fields (tokens/secrets/security/gateway) must include Chinese safety wording in purpose/usage.
- Prioritize exact field path mapping (for example `gateway.port`, `autonomy.level`, `model_routes.[].hint`)

## Validation

Run these checks after changes:

```bash
node --check zeroclaw-config-ui/web/app.js
bash -n zeroclaw-config-ui/scripts/build-to-home.sh zeroclaw-config-ui/scripts/run.sh
bash zeroclaw-config-ui/skills/zeroclaw-config-ui-maintainer/scripts/schema-inventory.sh
python3 zeroclaw-config-ui/skills/zeroclaw-config-ui-maintainer/scripts/check-field-help-json.py
bash zeroclaw-config-ui/skills/zeroclaw-config-ui-maintainer/scripts/check-zh-descriptions.sh
bash zeroclaw-config-ui/skills/zeroclaw-config-ui-maintainer/scripts/check-ui-help-smoke.sh
```

If network is available, also run:

```bash
cargo check --manifest-path zeroclaw-config-ui/src-tauri/Cargo.toml
```

## Build + Install

```bash
./zeroclaw-config-ui/scripts/build-to-home.sh
```

Expected binary:

```bash
~/.zeroclaw/zeroclaw-config-ui
```
