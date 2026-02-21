# AI 欄位說明產出流程

此文件給維護者在更新 `field-help.zh.generated.json` 時使用。

## 目標

根據專案文件（至少 `README.md`、`docs/config-reference.md`）為 UI 欄位建立：

- 中文用途說明
- 中文使用建議
- 對應 TOML 範例

輸出檔案：`zeroclaw-config-ui/web/field-help.zh.generated.json`

## 建議流程

1. 讀 schema（`zeroclaw config schema`）確認可配置欄位名稱。
2. 閱讀文件並萃取「欄位 -> 行為/限制/範例」對應。
3. 由 AI 生成 `fields.<path>` 條目。
4. 每個條目至少包含：
   - `purpose_zh`
   - `examples`（至少 1 個）
5. 盡量補 `usage_zh`，特別是安全性與風險欄位。
6. 執行驗證腳本：

```bash
python3 zeroclaw-config-ui/skills/zeroclaw-config-ui-maintainer/scripts/check-field-help-json.py
bash zeroclaw-config-ui/skills/zeroclaw-config-ui-maintainer/scripts/check-zh-descriptions.sh
```

## 條目格式範例

```json
{
  "fields": {
    "gateway.port": {
      "purpose_zh": "設定 gateway 監聽埠。",
      "usage_zh": "需與反向代理與 tunnel 設定一致。",
      "examples": [
        "[gateway] port = 3000"
      ],
      "sources": [
        "README.md",
        "docs/config-reference.md"
      ]
    }
  }
}
```
