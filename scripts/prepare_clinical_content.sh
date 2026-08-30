#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARTS_DIR="$REPO_ROOT/clinical-content/base64"
OUTPUT_DIR="$REPO_ROOT/clinical-content"
OUTPUT_FILE="$OUTPUT_DIR/UK_Preventive_Health_Evidence_Database_v6_Personalisation_Engine.xlsx"
TMP_B64="$OUTPUT_DIR/.clinical_workbook.combined.b64"
EXPECTED_SHA256="89821567c8a49dd65f356141120138034b3be4b18783634d16c5c88d029f4048"
EXPECTED_SIZE="81092"
EXPECTED_PARTS="10"

mkdir -p "$OUTPUT_DIR"

mapfile -t PARTS < <(find "$PARTS_DIR" -maxdepth 1 -type f -name 'clinical_workbook.part*.b64' | sort)

if [[ "${#PARTS[@]}" -ne "$EXPECTED_PARTS" ]]; then
  echo "ERROR: Expected $EXPECTED_PARTS clinical workbook chunks, found ${#PARTS[@]}." >&2
  exit 1
fi

: > "$TMP_B64"
for part in "${PARTS[@]}"; do
  cat "$part" >> "$TMP_B64"
done

rm -f "$OUTPUT_FILE"
if base64 --help >/dev/null 2>&1 && base64 --decode "$TMP_B64" > "$OUTPUT_FILE" 2>/dev/null; then
  :
elif base64 -D -i "$TMP_B64" -o "$OUTPUT_FILE" 2>/dev/null; then
  :
else
  python3 - "$TMP_B64" "$OUTPUT_FILE" <<'PY'
import base64
import pathlib
import sys
src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
dst.write_bytes(base64.b64decode(src.read_text(), validate=True))
PY
fi

rm -f "$TMP_B64"

if stat -f%z "$OUTPUT_FILE" >/dev/null 2>&1; then
  ACTUAL_SIZE="$(stat -f%z "$OUTPUT_FILE")"
else
  ACTUAL_SIZE="$(stat -c%s "$OUTPUT_FILE")"
fi

if [[ "$ACTUAL_SIZE" != "$EXPECTED_SIZE" ]]; then
  echo "ERROR: Clinical workbook size mismatch. Expected $EXPECTED_SIZE bytes, got $ACTUAL_SIZE." >&2
  rm -f "$OUTPUT_FILE"
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL_SHA256="$(sha256sum "$OUTPUT_FILE" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL_SHA256="$(shasum -a 256 "$OUTPUT_FILE" | awk '{print $1}')"
else
  ACTUAL_SHA256="$(python3 - "$OUTPUT_FILE" <<'PY'
import hashlib
import pathlib
import sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
fi

if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
  echo "ERROR: Clinical workbook SHA-256 mismatch." >&2
  echo "Expected: $EXPECTED_SHA256" >&2
  echo "Actual:   $ACTUAL_SHA256" >&2
  rm -f "$OUTPUT_FILE"
  exit 1
fi

python3 - "$OUTPUT_FILE" <<'PY'
import pathlib
import sys
import zipfile
path = pathlib.Path(sys.argv[1])
if not zipfile.is_zipfile(path):
    raise SystemExit("ERROR: Reconstructed file is not a valid XLSX/ZIP container.")
with zipfile.ZipFile(path) as zf:
    bad = zf.testzip()
    if bad is not None:
        raise SystemExit(f"ERROR: XLSX ZIP integrity test failed at member: {bad}")
    required = {"xl/workbook.xml", "[Content_Types].xml"}
    missing = required.difference(zf.namelist())
    if missing:
        raise SystemExit(f"ERROR: XLSX is missing required members: {sorted(missing)}")
print("XLSX ZIP integrity: PASS")
PY

echo "Clinical workbook reconstruction: PASS"
echo "Path:   $OUTPUT_FILE"
echo "Size:   $ACTUAL_SIZE bytes"
echo "SHA256: $ACTUAL_SHA256"
echo "Codex may now use this workbook as the authoritative V1 clinical seed source."
