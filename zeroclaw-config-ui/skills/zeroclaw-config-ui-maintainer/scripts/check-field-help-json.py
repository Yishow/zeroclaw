#!/usr/bin/env python3
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Set


FIELD_HELP_PATH = Path("zeroclaw-config-ui/web/field-help.zh.generated.json")
PATH_RE = re.compile(r"^(?:[A-Za-z0-9_<>-]+|\[\]|\*)(?:\.(?:[A-Za-z0-9_<>-]+|\[\]|\*))*$")
ZH_RE = re.compile(r"[\u4e00-\u9fff]")
HIGH_RISK_KEY_RE = re.compile(
    r"(api_key|token|secret|password|private_key|webhook_secret|^security\.|^gateway\.)",
    re.IGNORECASE,
)
SAFETY_HINTS = ("安全", "敏感", "權限", "加密", "風險", "保護")
MIN_COVERAGE = float(os.getenv("FIELD_HELP_MIN_COVERAGE", "0.20"))
MAX_AGE_DAYS = int(os.getenv("FIELD_HELP_MAX_AGE_DAYS", "30"))


def has_zh(text: str) -> bool:
    return bool(ZH_RE.search(text or ""))


def canonicalize_path(path: str) -> str:
    cleaned = path.strip()
    cleaned = cleaned.replace("[*]", "*")
    cleaned = re.sub(r"\[\s*\]", "[]", cleaned)
    cleaned = re.sub(r"\s+", "", cleaned)
    cleaned = cleaned.strip(".")
    cleaned = re.sub(r"\.{2,}", ".", cleaned)
    return cleaned


def extract_json_body(text: str) -> str:
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise ValueError("schema JSON boundaries not found in command output")
    return text[start : end + 1]


def load_schema_json() -> Dict[str, Any]:
    bin_name = os.getenv("ZEROCLAW_BIN", "zeroclaw").strip() or "zeroclaw"
    proc = subprocess.run(
        [bin_name, "config", "schema"],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"'{bin_name} config schema' failed: rc={proc.returncode} stderr={proc.stderr.strip()}"
        )
    return json.loads(extract_json_body(proc.stdout))


def is_null_schema(node: Dict[str, Any]) -> bool:
    t = node.get("type")
    if t == "null":
        return True
    if isinstance(t, list) and "null" in t:
        return True
    return False


def deref(root: Dict[str, Any], node: Dict[str, Any], seen: Set[str] | None = None) -> Dict[str, Any]:
    seen = seen or set()
    current = node
    while isinstance(current, dict) and "$ref" in current:
        ref_name = str(current["$ref"]).split("/")[-1]
        if ref_name in seen:
            break
        seen.add(ref_name)
        current = root.get("$defs", {}).get(ref_name, {})

    if not isinstance(current, dict):
        return {}

    if isinstance(current.get("anyOf"), list):
        candidate = next(
            (
                item
                for item in current["anyOf"]
                if isinstance(item, dict) and not is_null_schema(item)
            ),
            None,
        )
        if candidate is not None:
            return deref(root, candidate, seen)

    if isinstance(current.get("oneOf"), list):
        options = [item for item in current["oneOf"] if isinstance(item, dict)]
        const_only = bool(options) and all("const" in item for item in options)
        if const_only:
            return current
        candidate = next((item for item in options if not is_null_schema(item)), None)
        if candidate is not None:
            return deref(root, candidate, seen)

    return current


def schema_type(node: Dict[str, Any]) -> str:
    t = node.get("type")
    if isinstance(t, str):
        return t
    if isinstance(t, list):
        non_null = [x for x in t if x != "null"]
        return non_null[0] if non_null else "unknown"
    if "properties" in node or "additionalProperties" in node:
        return "object"
    if "items" in node:
        return "array"
    if isinstance(node.get("enum"), list):
        return "string"
    return "unknown"


def walk_schema_leaves(root: Dict[str, Any], node: Dict[str, Any], path: List[str]) -> Iterable[str]:
    resolved = deref(root, node)
    typ = schema_type(resolved)

    if typ == "object":
        props = resolved.get("properties") or {}
        for key, child in props.items():
            if isinstance(child, dict):
                yield from walk_schema_leaves(root, child, [*path, key])

        additional = resolved.get("additionalProperties")
        if isinstance(additional, dict):
            yield from walk_schema_leaves(root, additional, [*path, "*"])

        if not props and not isinstance(additional, dict):
            yield ".".join(path)
        return

    if typ == "array":
        items = resolved.get("items")
        if isinstance(items, dict):
            yield from walk_schema_leaves(root, items, [*path, "[]"])
        else:
            yield ".".join([*path, "[]"])
        return

    yield ".".join(path)


def schema_leaf_paths(schema: Dict[str, Any]) -> Set[str]:
    root = deref(schema, schema)
    props = root.get("properties") or {}
    out: Set[str] = set()
    for key, child in props.items():
        if isinstance(child, dict):
            out.update(walk_schema_leaves(schema, child, [key]))
    return out


def schema_signature(paths: Set[str]) -> str:
    body = "\n".join(sorted(paths)).encode("utf-8")
    return hashlib.sha256(body).hexdigest()


def parse_generated_at(value: str) -> datetime:
    normalized = value.strip().replace("Z", "+00:00")
    dt = datetime.fromisoformat(normalized)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def main() -> int:
    if not FIELD_HELP_PATH.exists():
        print(f"[FAIL] missing file: {FIELD_HELP_PATH}")
        return 1

    data = json.loads(FIELD_HELP_PATH.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        print("[FAIL] root must be JSON object")
        return 1

    meta = data.get("_meta")
    if not isinstance(meta, dict):
        print("[FAIL] _meta must be object")
        return 1

    fields = data.get("fields")
    if not isinstance(fields, dict) or not fields:
        print("[FAIL] fields must be non-empty object")
        return 1

    bad: List[str] = []
    with_examples = 0
    doc_paths: Set[str] = set()

    for raw_key, entry in fields.items():
        key = canonicalize_path(str(raw_key))
        if raw_key != key:
            bad.append(f"{raw_key}: non-canonical path, expected '{key}'")

        if not PATH_RE.match(key):
            bad.append(f"{raw_key}: invalid path format")

        if not isinstance(entry, dict):
            bad.append(f"{raw_key}: entry is not object")
            continue

        purpose = entry.get("purpose_zh", "")
        usage = entry.get("usage_zh", "")
        examples = entry.get("examples", [])

        if not isinstance(purpose, str) or not purpose.strip():
            bad.append(f"{raw_key}: missing purpose_zh")
        elif not has_zh(purpose):
            bad.append(f"{raw_key}: purpose_zh has no Chinese text")

        if not isinstance(usage, str) or not usage.strip():
            bad.append(f"{raw_key}: missing usage_zh")
        elif not has_zh(usage):
            bad.append(f"{raw_key}: usage_zh has no Chinese text")

        if not isinstance(examples, list):
            bad.append(f"{raw_key}: examples must be list")
        elif not examples:
            bad.append(f"{raw_key}: examples must be non-empty")
        else:
            with_examples += 1
            for i, ex in enumerate(examples, 1):
                if not isinstance(ex, str) or not ex.strip():
                    bad.append(f"{raw_key}: examples[{i}] invalid")

        if HIGH_RISK_KEY_RE.search(key):
            risk_text = f"{purpose}\n{usage}"
            if not any(hint in risk_text for hint in SAFETY_HINTS):
                bad.append(f"{raw_key}: high-risk field requires Chinese safety reminder in purpose_zh/usage_zh")

        doc_paths.add(key)

    generated_at_raw = meta.get("generated_at")
    if not isinstance(generated_at_raw, str) or not generated_at_raw.strip():
        bad.append("_meta.generated_at missing")
    else:
        try:
            generated_at = parse_generated_at(generated_at_raw)
            age_days = (datetime.now(timezone.utc) - generated_at).days
            if age_days > MAX_AGE_DAYS:
                bad.append(
                    f"_meta.generated_at is too old: {age_days} days (max {MAX_AGE_DAYS})"
                )
        except Exception as exc:  # pragma: no cover - defensive parse path
            bad.append(f"_meta.generated_at invalid: {exc}")

    try:
        schema = load_schema_json()
        leaf_paths = schema_leaf_paths(schema)
        if not leaf_paths:
            bad.append("schema leaf paths are empty")
            leaf_count = 0
            cov = 0.0
            signature = ""
        else:
            leaf_count = len(leaf_paths)
            signature = schema_signature(leaf_paths)
            covered = len(doc_paths & leaf_paths)
            cov = covered / leaf_count
            if cov < MIN_COVERAGE:
                bad.append(
                    f"coverage too low: {covered}/{leaf_count} ({cov:.2%}) < {MIN_COVERAGE:.0%}"
                )

            meta_leaf_count = meta.get("schema_leaf_count")
            meta_signature = meta.get("schema_signature")
            if meta_leaf_count != leaf_count:
                bad.append(
                    f"_meta.schema_leaf_count mismatch: file={meta_leaf_count} actual={leaf_count}"
                )
            if meta_signature != signature:
                bad.append(
                    f"_meta.schema_signature mismatch: file={meta_signature} actual={signature}"
                )
    except Exception as exc:
        bad.append(f"failed to load schema for coverage/signature checks: {exc}")
        leaf_count = 0
        cov = 0.0

    if bad:
        print("[FAIL] field-help validation failed:")
        for item in bad[:40]:
            print(f" - {item}")
        if len(bad) > 40:
            print(f" - ... and {len(bad) - 40} more")
        return 1

    print(
        "[OK] field-help JSON valid. "
        f"entries={len(fields)}, with_examples={with_examples}, "
        f"coverage={cov:.2%}, schema_leafs={leaf_count}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
