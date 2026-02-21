#!/usr/bin/env bash
set -euo pipefail

SCHEMA_JSON="$(zeroclaw config schema 2>/dev/null | awk 'found{print} /^\{/{found=1; print}')"

echo "$SCHEMA_JSON" | jq -r '.properties | keys[]' | sort > /tmp/zeroclaw-config-ui-top-level.txt
TOTAL_TOP_LEVEL="$(wc -l < /tmp/zeroclaw-config-ui-top-level.txt | tr -d ' ')"

echo "Top-level sections: $TOTAL_TOP_LEVEL"
cat /tmp/zeroclaw-config-ui-top-level.txt

echo "---"
echo "$SCHEMA_JSON" | jq -r '
  . as $root |
  def normtype($t): if $t == null then "unknown" elif ($t|type)=="array" then ($t|join("|")) else ($t|tostring) end;
  def deref($n):
    if ($n["$ref"]? != null) then ($n["$ref"] | split("/")[-1]) as $d | deref($root["$defs"][$d])
    elif ($n.anyOf? != null) then ($n.anyOf | map(select(.type? != "null"))[0]) as $x | if $x == null then $n else deref($x) end
    elif ($n.oneOf? != null) then ($n.oneOf[0]) as $x | deref($x)
    else $n end;
  def walk($path; $node):
    (deref($node)) as $n
    | if (($n.type? == "object") or ($n.properties? != null) or ($n.additionalProperties? != null)) then
        (($n.properties // {}) | to_entries[] | walk($path + [.key]; .value)),
        (if ($n.additionalProperties? != null) then walk($path + ["*"]; $n.additionalProperties) else empty end)
      elif (($n.type? == "array") and ($n.items? != null)) then
        walk($path + ["[]"]; $n.items)
      else
        [($path|join(".")), normtype($n.type)] | @tsv
      end;
  .properties | to_entries[] | walk([.key]; .value)
' | tee /tmp/zeroclaw-config-ui-paths.tsv >/dev/null

LEAF_COUNT="$(wc -l < /tmp/zeroclaw-config-ui-paths.tsv | tr -d ' ')"
LEAF_SIG="$(
  cut -f1 /tmp/zeroclaw-config-ui-paths.tsv | sort -u | python3 -c '
import hashlib, sys
paths = [line.strip() for line in sys.stdin if line.strip()]
body = "\n".join(paths)
print(hashlib.sha256(body.encode("utf-8")).hexdigest())
'
)"

echo "Leaf paths: $LEAF_COUNT"
echo "Schema leaf count (meta): $LEAF_COUNT"
echo "Schema signature (meta): $LEAF_SIG"
