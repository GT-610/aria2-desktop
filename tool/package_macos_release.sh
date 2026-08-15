#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 6 ]]; then
  echo "Usage: $0 <core-target> <build-name> <build-number> <tag-name> <artifact-arch> <output-dir>" >&2
  exit 64
fi

core_target="$1"
build_name="$2"
build_number="$3"
tag_name="$4"
artifact_arch="$5"
output_dir="$6"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace="$(cd "$script_dir/.." && pwd)"
manifest="$script_dir/aria2_next_release.json"
app_path="$workspace/build/macos/Build/Products/Release/setsuna.app"
core_dir="$app_path/Contents/Resources/data/core"
ad_hoc_signing="${MACOS_AD_HOC_SIGNING:-false}"

if [[ "$ad_hoc_signing" == "true" ]]; then
  signing_identity="-"
elif [[ "$ad_hoc_signing" == "false" ]]; then
  signing_identity="${MACOS_SIGNING_IDENTITY:?MACOS_SIGNING_IDENTITY is required}"
  notary_apple_id="${MACOS_NOTARY_APPLE_ID:?MACOS_NOTARY_APPLE_ID is required}"
  notary_team_id="${MACOS_NOTARY_TEAM_ID:?MACOS_NOTARY_TEAM_ID is required}"
  notary_password="${MACOS_NOTARY_PASSWORD:?MACOS_NOTARY_PASSWORD is required}"
else
  echo "MACOS_AD_HOC_SIGNING must be true or false." >&2
  exit 64
fi

aria2_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$manifest")"
temporary_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$temporary_dir"
}
trap cleanup EXIT

cd "$workspace"
rm -rf build/macos
flutter pub get
flutter build macos \
  --release \
  --no-pub \
  --build-name="$build_name" \
  --build-number="$build_number"

if [[ ! -d "$app_path" ]]; then
  echo "macOS application bundle was not created at $app_path" >&2
  exit 1
fi

"$script_dir/prepare_aria2_next.sh" "$core_target" "$core_dir"
dart run tool/smoke_test_aria2_next.dart \
  --executable "$core_dir/aria2c" \
  --config "$core_dir/aria2.conf" \
  --expected-version "$aria2_version"

for required_file in aria2c aria2.conf aria2-next.COPYING ARIA2_NEXT_NOTICE.txt; do
  if [[ ! -f "$core_dir/$required_file" ]]; then
    echo "Release application is missing $required_file" >&2
    exit 1
  fi
done
for forbidden_file in aria2.log aria2.session; do
  if [[ -e "$core_dir/$forbidden_file" ]]; then
    echo "Release application contains forbidden runtime file: $forbidden_file" >&2
    exit 1
  fi
done

xattr -cr "$app_path"
codesign_options=(--force --options runtime --sign "$signing_identity")
if [[ "$ad_hoc_signing" == "false" ]]; then
  codesign_options+=(--timestamp)
fi
codesign "${codesign_options[@]}" "$core_dir/aria2c"
codesign "${codesign_options[@]}" --deep "$app_path"
codesign "${codesign_options[@]}" \
  --entitlements "$workspace/macos/Runner/Release.entitlements" \
  "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"

staging_dir="$temporary_dir/dmg"
mkdir -p "$staging_dir"
ditto "$app_path" "$staging_dir/Setsuna.app"
ln -s /Applications "$staging_dir/Applications"

mkdir -p "$output_dir"
artifact_path="$output_dir/Setsuna_${tag_name}_macos_${artifact_arch}.dmg"
hdiutil create \
  -volname Setsuna \
  -srcfolder "$staging_dir" \
  -ov \
  -format UDZO \
  "$artifact_path"

if [[ "$ad_hoc_signing" == "false" ]]; then
  xcrun notarytool submit "$artifact_path" \
    --apple-id "$notary_apple_id" \
    --team-id "$notary_team_id" \
    --password "$notary_password" \
    --wait
  xcrun stapler staple "$artifact_path"
  xcrun stapler validate "$artifact_path"
else
  echo "Created an ad hoc-signed validation package; do not publish it." >&2
fi

echo "Created $artifact_path"
