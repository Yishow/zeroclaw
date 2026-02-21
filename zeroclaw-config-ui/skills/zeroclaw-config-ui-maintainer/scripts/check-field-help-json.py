#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path


def has_zh(text: str) -> bool:
    return bool(re.search(r"[\u4e00-\u9fff]", text or ""))


def main() -> int:
    path = Path("zeroclaw-config-ui/web/field-help.zh.generated.json")
    if not path.exists():
        print(f"[FAIL] missing file: {path}")
        return 1

    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        print("[FAIL] root must be JSON object")
        return 1

    fields = data.get("fields")
    if not isinstance(fields, dict) or not fields:
        print("[FAIL] fields must be non-empty object")
        return 1

    bad = []
    with_examples = 0
    for key, entry in fields.items():
        if not isinstance(entry, dict):
            bad.append(f"{key}: entry is not object")
            continue

        purpose = entry.get("purpose_zh", "")
        usage = entry.get("usage_zh", "")
        examples = entry.get("examples", [])

        if not isinstance(purpose, str) or not purpose.strip():
            bad.append(f"{key}: missing purpose_zh")
        elif not has_zh(purpose):
            bad.append(f"{key}: purpose_zh has no Chinese text")

        if usage and (not isinstance(usage, str) or not has_zh(usage)):
            bad.append(f"{key}: usage_zh must contain Chinese text")

        if not isinstance(examples, list):
            bad.append(f"{key}: examples must be list")
        elif examples:
            with_examples += 1
            for i, ex in enumerate(examples, 1):
                if not isinstance(ex, str) or not ex.strip():
                    bad.append(f"{key}: examples[{i}] invalid")

    if with_examples == 0:
        bad.append("no field contains examples")

    if bad:
        print("[FAIL] field-help validation failed:")
        for item in bad[:30]:
            print(f" - {item}")
        if len(bad) > 30:
            print(f" - ... and {len(bad) - 30} more")
        return 1

    print(f"[OK] field-help JSON valid. entries={len(fields)}, with_examples={with_examples}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
