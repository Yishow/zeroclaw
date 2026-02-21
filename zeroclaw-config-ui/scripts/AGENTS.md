# AGENTS.md — zeroclaw-config-ui/scripts

## Project Purpose

`zeroclaw-config-ui` 的目的是提供一個可視化 UI，讓使用者用圖形介面設定 ZeroClaw 的 config，而不是直接手改設定檔。

`scripts/` 目錄的目的：
- 提供啟動與建置輔助腳本，降低本機啟動門檻。
- 將環境檢查與啟動前保護邏輯放在腳本層，避免污染原始上游程式碼。
- 支援你把這個目錄獨立維護（可獨立 Git 管理）。

## Scope Rules

- 優先只改 `scripts/`，把本機相依、啟動保護、工作流程封裝在這層。
- 非必要不修改 `src-tauri/` 原始實作。
- 腳本變更要可回滾、可理解、可重現。
