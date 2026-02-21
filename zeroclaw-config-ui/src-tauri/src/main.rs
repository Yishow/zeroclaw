#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use anyhow::{anyhow, Context, Result};
use serde::Serialize;
use serde_json::Value as JsonValue;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ConfigBundle {
    config_path: String,
    raw_toml: String,
    config_json: JsonValue,
    schema_json: JsonValue,
    file_mode: Option<String>,
    warnings: Vec<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct SaveResult {
    config_path: String,
    backup_path: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct PermissionResult {
    config_path: String,
    file_mode: Option<String>,
}

fn default_config_path() -> Result<PathBuf> {
    let home = env::var("HOME").context("HOME is not set")?;
    Ok(PathBuf::from(home).join(".zeroclaw").join("config.toml"))
}

fn resolve_config_path() -> Result<PathBuf> {
    if let Ok(path) = env::var("ZEROCLAW_CONFIG_PATH") {
        let trimmed = path.trim();
        if !trimmed.is_empty() {
            return Ok(PathBuf::from(trimmed));
        }
    }
    default_config_path()
}

fn resolve_zeroclaw_bin() -> String {
    env::var("ZEROCLAW_BIN")
        .ok()
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
        .unwrap_or_else(|| "zeroclaw".to_string())
}

fn file_mode(path: &Path) -> Option<String> {
    #[cfg(unix)]
    {
        fs::metadata(path)
            .ok()
            .map(|m| format!("{:o}", m.permissions().mode() & 0o777))
    }
    #[cfg(not(unix))]
    {
        let _ = path;
        None
    }
}

fn strip_log_prefix_and_parse_schema(stdout: &str) -> Result<JsonValue> {
    let start = stdout
        .find('{')
        .ok_or_else(|| anyhow!("Schema JSON not found in zeroclaw output"))?;
    let end = stdout
        .rfind('}')
        .ok_or_else(|| anyhow!("Schema JSON closing brace not found"))?;
    if end <= start {
        return Err(anyhow!("Schema JSON boundaries are invalid"));
    }
    let body = &stdout[start..=end];
    let parsed: JsonValue = serde_json::from_str(body).context("Failed to parse schema JSON")?;
    Ok(parsed)
}

fn load_schema_json() -> Result<JsonValue> {
    let bin = resolve_zeroclaw_bin();
    let output = Command::new(&bin)
        .args(["config", "schema"])
        .output()
        .with_context(|| format!("Failed to execute '{bin} config schema'"))?;

    if !output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow!(
            "'{} config schema' failed: status={} stderr={} stdout={}",
            bin,
            output.status,
            stderr.trim(),
            stdout.trim()
        ));
    }

    let stdout = String::from_utf8(output.stdout).context("Schema output is not valid UTF-8")?;
    strip_log_prefix_and_parse_schema(&stdout)
}

fn read_config_toml(path: &Path) -> Result<String> {
    if !path.exists() {
        return Ok(String::new());
    }
    fs::read_to_string(path).with_context(|| format!("Failed to read {}", path.display()))
}

fn parse_toml_to_json(raw_toml: &str) -> Result<JsonValue> {
    if raw_toml.trim().is_empty() {
        return Ok(serde_json::json!({}));
    }
    let toml_value: toml::Value = toml::from_str(raw_toml).context("Invalid TOML")?;
    serde_json::to_value(toml_value).context("Failed to convert TOML to JSON")
}

fn json_to_pretty_toml(payload_json: &str) -> Result<String> {
    let json: JsonValue =
        serde_json::from_str(payload_json).context("Structured payload is not valid JSON")?;
    let toml_value = toml::Value::try_from(json).context("JSON payload is not TOML-compatible")?;
    toml::to_string_pretty(&toml_value).context("Failed to serialize TOML")
}

fn write_atomically(path: &Path, raw_toml: &str) -> Result<Option<PathBuf>> {
    let parent = path
        .parent()
        .ok_or_else(|| anyhow!("Config path has no parent directory"))?;
    fs::create_dir_all(parent).with_context(|| format!("Failed to create {}", parent.display()))?;

    let parsed: toml::Value = toml::from_str(raw_toml).context("TOML validation failed")?;
    let normalized = toml::to_string_pretty(&parsed).context("Failed to normalize TOML")?;

    let ts = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis();
    let file_name = path
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("config.toml");
    let temp_path = parent.join(format!(".{file_name}.tmp-{ts}"));

    fs::write(&temp_path, normalized.as_bytes())
        .with_context(|| format!("Failed to write temp file {}", temp_path.display()))?;

    #[cfg(unix)]
    {
        fs::set_permissions(&temp_path, fs::Permissions::from_mode(0o600))
            .with_context(|| format!("Failed to chmod 600 {}", temp_path.display()))?;
    }

    let backup_path = if path.exists() {
        let backup = parent.join(format!("{file_name}.bak"));
        fs::copy(path, &backup).with_context(|| {
            format!(
                "Failed to create backup {} from {}",
                backup.display(),
                path.display()
            )
        })?;
        Some(backup)
    } else {
        None
    };

    fs::rename(&temp_path, path).with_context(|| {
        format!(
            "Failed to replace config {} with {}",
            path.display(),
            temp_path.display()
        )
    })?;

    #[cfg(unix)]
    {
        fs::set_permissions(path, fs::Permissions::from_mode(0o600))
            .with_context(|| format!("Failed to chmod 600 {}", path.display()))?;
    }

    Ok(backup_path)
}

fn chmod_config_600(path: &Path) -> Result<()> {
    #[cfg(unix)]
    {
        fs::set_permissions(path, fs::Permissions::from_mode(0o600))
            .with_context(|| format!("Failed to chmod 600 {}", path.display()))?;
        Ok(())
    }
    #[cfg(not(unix))]
    {
        let _ = path;
        Err(anyhow!("Setting file mode 600 is only supported on Unix-like systems"))
    }
}

#[tauri::command]
fn load_bundle() -> std::result::Result<ConfigBundle, String> {
    (|| -> Result<ConfigBundle> {
        let config_path = resolve_config_path()?;
        let raw_toml = read_config_toml(&config_path)?;
        let config_json = parse_toml_to_json(&raw_toml)?;
        let schema_json = load_schema_json()?;

        let mut warnings = Vec::new();
        if raw_toml.trim().is_empty() {
            warnings.push("Config file is empty; editing starts from an empty object.".to_string());
        }
        if !config_path.exists() {
            warnings.push(format!(
                "Config file does not exist yet: {}",
                config_path.display()
            ));
        }
        if let Some(mode) = file_mode(&config_path) {
            if mode != "600" {
                warnings.push(format!(
                    "Config file permissions are {} (recommended: 600).",
                    mode
                ));
            }
        }

        Ok(ConfigBundle {
            config_path: config_path.display().to_string(),
            raw_toml,
            config_json,
            schema_json,
            file_mode: file_mode(&config_path),
            warnings,
        })
    })()
    .map_err(|e| e.to_string())
}

#[tauri::command]
fn render_toml_from_json(payload_json: String) -> std::result::Result<String, String> {
    json_to_pretty_toml(&payload_json).map_err(|e| e.to_string())
}

#[tauri::command]
fn save_config_json(payload_json: String) -> std::result::Result<SaveResult, String> {
    (|| -> Result<SaveResult> {
        let config_path = resolve_config_path()?;
        let raw_toml = json_to_pretty_toml(&payload_json)?;
        let backup_path = write_atomically(&config_path, &raw_toml)?;
        Ok(SaveResult {
            config_path: config_path.display().to_string(),
            backup_path: backup_path.map(|p| p.display().to_string()),
        })
    })()
    .map_err(|e| e.to_string())
}

#[tauri::command]
fn save_config_toml(raw_toml: String) -> std::result::Result<SaveResult, String> {
    (|| -> Result<SaveResult> {
        let config_path = resolve_config_path()?;
        let backup_path = write_atomically(&config_path, &raw_toml)?;
        Ok(SaveResult {
            config_path: config_path.display().to_string(),
            backup_path: backup_path.map(|p| p.display().to_string()),
        })
    })()
    .map_err(|e| e.to_string())
}

#[tauri::command]
fn set_config_mode_600() -> std::result::Result<PermissionResult, String> {
    (|| -> Result<PermissionResult> {
        let config_path = resolve_config_path()?;
        if !config_path.exists() {
            return Err(anyhow!(
                "Config file does not exist yet: {}",
                config_path.display()
            ));
        }
        chmod_config_600(&config_path)?;
        Ok(PermissionResult {
            config_path: config_path.display().to_string(),
            file_mode: file_mode(&config_path),
        })
    })()
    .map_err(|e| e.to_string())
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            load_bundle,
            render_toml_from_json,
            save_config_json,
            save_config_toml,
            set_config_mode_600
        ])
        .run(tauri::generate_context!())
        .expect("failed to run app");
}
