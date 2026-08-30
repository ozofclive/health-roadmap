#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required to reconstruct and validate the clinical workbook." >&2
  exit 1
fi

python3 - "$REPO_ROOT" <<'PY'
import base64
import hashlib
import json
import pathlib
import sys
import zipfile

repo = pathlib.Path(sys.argv[1])
clinical = repo / "clinical-content"
parts_dir = clinical / "base64"
manifest_path = clinical / "manifest.json"

if not manifest_path.is_file():
    raise SystemExit(f"ERROR: Missing manifest: {manifest_path}")

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
filename = manifest["file"]
expected_parts = int(manifest["parts"])
expected_size = int(manifest["size_bytes"])
expected_sha = str(manifest["sha256"]).lower()
output = clinical / filename

parts = sorted(parts_dir.glob("clinical_workbook.part*.b64"))
if len(parts) != expected_parts:
    raise SystemExit(
        f"ERROR: Expected {expected_parts} clinical workbook chunks, found {len(parts)}."
    )

expected_names = [f"clinical_workbook.part{i:02d}.b64" for i in range(1, expected_parts + 1)]
actual_names = [p.name for p in parts]
if actual_names != expected_names:
    raise SystemExit(
        "ERROR: Clinical workbook chunk names are incomplete or out of sequence.\n"
        f"Expected: {expected_names}\nActual:   {actual_names}"
    )

try:
    encoded = "".join(p.read_text(encoding="ascii").strip() for p in parts)
    decoded = base64.b64decode(encoded, validate=True)
except Exception as exc:
    raise SystemExit(f"ERROR: Could not decode clinical workbook payload: {exc}") from exc

actual_size = len(decoded)
actual_sha = hashlib.sha256(decoded).hexdigest()

if actual_size != expected_size:
    raise SystemExit(
        f"ERROR: Clinical workbook size mismatch. Expected {expected_size} bytes, got {actual_size}."
    )

if actual_sha != expected_sha:
    raise SystemExit(
        "ERROR: Clinical workbook SHA-256 mismatch.\n"
        f"Expected: {expected_sha}\nActual:   {actual_sha}"
    )

output.write_bytes(decoded)

if not zipfile.is_zipfile(output):
    output.unlink(missing_ok=True)
    raise SystemExit("ERROR: Reconstructed file is not a valid XLSX/ZIP container.")

with zipfile.ZipFile(output) as zf:
    bad = zf.testzip()
    if bad is not None:
        output.unlink(missing_ok=True)
        raise SystemExit(f"ERROR: XLSX ZIP integrity test failed at member: {bad}")
    required = {"xl/workbook.xml", "[Content_Types].xml"}
    missing = required.difference(zf.namelist())
    if missing:
        output.unlink(missing_ok=True)
        raise SystemExit(f"ERROR: XLSX is missing required members: {sorted(missing)}")

print("XLSX ZIP integrity: PASS")
print("Clinical workbook reconstruction: PASS")
print(f"Path:   {output}")
print(f"Size:   {actual_size} bytes")
print(f"SHA256: {actual_sha}")
print("Codex may now use this workbook as the authoritative V1 clinical seed source.")
PY
