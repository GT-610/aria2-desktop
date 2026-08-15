#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <target> <destination>" >&2
  exit 64
fi

target="$1"
destination="$2"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace="$(cd "$script_dir/.." && pwd)"
manifest="$script_dir/aria2_next_release.json"

sha256_file() {
  python3 - "$1" <<'PY'
import hashlib
import sys

digest = hashlib.sha256()
with open(sys.argv[1], "rb") as source:
    for chunk in iter(lambda: source.read(1024 * 1024), b""):
        digest.update(chunk)
print(digest.hexdigest())
PY
}

IFS=$'\t' read -r repository version asset_file asset_sha256 license_url license_sha256 < <(
  python3 - "$manifest" "$target" <<'PY'
import json
import sys

manifest_path, target = sys.argv[1:]
with open(manifest_path, encoding="utf-8") as source:
    manifest = json.load(source)

asset = manifest["assets"].get(target)
if asset is None:
    raise SystemExit(f"Unsupported Aria2 Next target: {target}")

print("\t".join((
    manifest["repository"],
    manifest["version"],
    asset["file"],
    asset["sha256"],
    manifest["license"]["url"],
    manifest["license"]["sha256"],
)))
PY
)

mkdir -p "$destination"
download_path="$destination/$asset_file"
executable_path="$destination/aria2c"
license_path="$destination/aria2-next.COPYING"

curl --fail --location --retry 3 \
  "https://github.com/$repository/releases/download/v$version/$asset_file" \
  --output "$download_path"

actual_hash="$(sha256_file "$download_path")"

if [[ "$actual_hash" != "$asset_sha256" ]]; then
  rm -f "$download_path"
  echo "Aria2 Next checksum mismatch. Expected $asset_sha256, got $actual_hash." >&2
  exit 1
fi

mv -f "$download_path" "$executable_path"
chmod 755 "$executable_path"

curl --fail --location --retry 3 "$license_url" --output "$license_path"
actual_license_hash="$(sha256_file "$license_path")"

if [[ "$actual_license_hash" != "$license_sha256" ]]; then
  rm -f "$license_path"
  echo "Aria2 Next license checksum mismatch. Expected $license_sha256, got $actual_license_hash." >&2
  exit 1
fi

cp "$workspace/assets/core/aria2.conf" "$destination/aria2.conf"
cp "$workspace/assets/core/ARIA2_NEXT_NOTICE.txt" "$destination/ARIA2_NEXT_NOTICE.txt"

echo "Prepared Aria2 Next $version for $target at $destination"
