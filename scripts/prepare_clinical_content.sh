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
verified_dir = parts_dir / "verified"
manifest_path = clinical / "manifest.json"

if not manifest_path.is_file():
    raise SystemExit(f"ERROR: Missing manifest: {manifest_path}")

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
filename = manifest["file"]
expected_parts = int(manifest["parts"])
expected_size = int(manifest["size_bytes"])
expected_sha = str(manifest["sha256"]).lower()
output = clinical / filename

# SHA-256 values are for the exact approved base64 transport segments generated
# from the authoritative workbook with 12,000 base64 characters per primary part.
primary_sha256 = {
    1: "16acdbab0c125de542647f0cca6ba90c5fe643bb35ef9b3759138906e6ed9321",
    2: "5b5103b7d70d7b119cae5c12747be6a841bfadebf257c14ed4b38aeafab0ba2f",
    3: "7a04be085bb36bb51143448aee2aeb45e5c4dd8e48cdac4915ad6136eec053b9",
    4: "1389081cef45ec2b6d465048d5683902742456bbc1e376aebe802acc68d35d6d",
    5: "8f4c1362487704c9c2ebea759b8bf9481149420c227c6759878a48a2f6f3f6dd",
    6: "657793d5e289cbd93787ea3308ddf640021baee5fb548b6bfc3952204b9dd40b",
    7: "e4796ae3feef1d19f456d10fd10a20298fb81c2b3fef830992af8c9ff0f5f462",
    8: "afd87db86a1d5a987c15ad4800de0bcab248e06c4ddabc43cf2d27ed25f43420",
    10: "820f0de78ef0768572ad89f39761ad5b3bf52638f0379f0b93204e6eccb9999d",
}

part09_sha256 = [
    "3fcba155e05df8cd55fbae5ea80ac02fc676378c4f63ebfa8f59ab53b792c143",
    "56ac6e75fd1624416c99ca7d98dc9d487b76810a1bfa487f2da3cfa5214dd8eb",
    "1e914d40a69dcf162e87ed833a990d7ae068f7c1fc8979def3b4ab5c310aefdc",
    "d1b8d95b2a3ceacc5e12ef31b75c1bfea6de2bc2b616c247c746eb4bb4c92ee7",
]

expected_names = [f"clinical_workbook.part{i:02d}.b64" for i in range(1, expected_parts + 1)]
primary_parts = [parts_dir / name for name in expected_names]
missing_primary = [p.name for p in primary_parts if not p.is_file()]
if missing_primary:
    raise SystemExit(f"ERROR: Missing primary clinical workbook chunks: {missing_primary}")

encoded_parts = []
for i in range(1, expected_parts + 1):
    if i == 9:
        # Chunk 09 is transported as four smaller, independently verified files to
        # avoid text-API truncation/corruption. The legacy primary part09 is ignored.
        subparts = [verified_dir / f"clinical_workbook.part09.{j:02d}.b64" for j in range(1, 5)]
        missing = [p.name for p in subparts if not p.is_file()]
        if missing:
            raise SystemExit(f"ERROR: Missing verified chunk-09 subparts: {missing}")
        rebuilt_09 = []
        for j, (p, expected_segment_sha) in enumerate(zip(subparts, part09_sha256), start=1):
            segment = p.read_text(encoding="ascii").strip()
            actual_segment_sha = hashlib.sha256(segment.encode("ascii")).hexdigest()
            if actual_segment_sha != expected_segment_sha:
                raise SystemExit(
                    f"ERROR: Verified part09 subchunk {j} checksum mismatch.\n"
                    f"Expected: {expected_segment_sha}\nActual:   {actual_segment_sha}"
                )
            if len(segment) != 3000:
                raise SystemExit(f"ERROR: Verified part09 subchunk {j} must be 3000 characters, got {len(segment)}.")
            rebuilt_09.append(segment)
        segment = "".join(rebuilt_09)
        if len(segment) != 12000:
            raise SystemExit(f"ERROR: Rebuilt part09 must be 12000 characters, got {len(segment)}.")
        encoded_parts.append(segment)
        print("Transport part09 verified via 4 protected subchunks: PASS")
        continue

    p = parts_dir / f"clinical_workbook.part{i:02d}.b64"
    segment = p.read_text(encoding="ascii").strip()
    expected_segment_sha = primary_sha256[i]
    actual_segment_sha = hashlib.sha256(segment.encode("ascii")).hexdigest()
    if actual_segment_sha != expected_segment_sha:
        raise SystemExit(
            f"ERROR: Clinical workbook part{i:02d} transport checksum mismatch.\n"
            f"Expected: {expected_segment_sha}\nActual:   {actual_segment_sha}"
        )
    expected_len = 124 if i == 10 else 12000
    if len(segment) != expected_len:
        raise SystemExit(f"ERROR: part{i:02d} length mismatch. Expected {expected_len}, got {len(segment)}.")
    encoded_parts.append(segment)

encoded = "".join(encoded_parts)
try:
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

print("Primary transport chunks 01-08 and 10: PASS")
print("XLSX ZIP integrity: PASS")
print("Clinical workbook reconstruction: PASS")
print(f"Path:   {output}")
print(f"Size:   {actual_size} bytes")
print(f"SHA256: {actual_sha}")
print("Codex may now use this workbook as the authoritative V1 clinical seed source.")
PY
