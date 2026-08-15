#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 9 ]]; then
  echo "Usage: $0 <core-target> <flutter-target> <bundle-arch> <deb-arch> <build-name> <build-number> <tag-name> <artifact-arch> <output-dir>" >&2
  exit 64
fi

core_target="$1"
flutter_target="$2"
bundle_arch="$3"
deb_arch="$4"
build_name="$5"
build_number="$6"
tag_name="$7"
artifact_arch="$8"
output_dir="$9"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace="$(cd "$script_dir/.." && pwd)"
manifest="$script_dir/aria2_next_release.json"
aria2_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$manifest")"
bundle_dir="$workspace/build/linux/$bundle_arch/release/bundle"
core_dir="$bundle_dir/data/core"
temporary_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$temporary_dir"
}
trap cleanup EXIT

cd "$workspace"
rm -rf build/linux
flutter pub get
flutter build linux \
  --release \
  --no-pub \
  --target-platform="$flutter_target" \
  --build-name="$build_name" \
  --build-number="$build_number"

if [[ ! -x "$bundle_dir/setsuna" ]]; then
  echo "Linux application bundle was not created at $bundle_dir" >&2
  exit 1
fi

"$script_dir/prepare_aria2_next.sh" "$core_target" "$core_dir"
dart run tool/smoke_test_aria2_next.dart \
  --executable "$core_dir/aria2c" \
  --config "$core_dir/aria2.conf" \
  --expected-version "$aria2_version"

for required_file in aria2c aria2.conf aria2-next.COPYING ARIA2_NEXT_NOTICE.txt; do
  if [[ ! -f "$core_dir/$required_file" ]]; then
    echo "Release bundle is missing $required_file" >&2
    exit 1
  fi
done
for forbidden_file in aria2.log aria2.session; do
  if [[ -e "$core_dir/$forbidden_file" ]]; then
    echo "Release bundle contains forbidden runtime file: $forbidden_file" >&2
    exit 1
  fi
done

mkdir -p "$output_dir"
archive_path="$output_dir/Setsuna_${tag_name}_linux_${artifact_arch}.tar.gz"
tar -C "$bundle_dir" -czf "$archive_path" .

package_root="$temporary_dir/package"
install_root="$package_root/usr/lib/setsuna"
mkdir -p \
  "$package_root/DEBIAN" \
  "$install_root" \
  "$package_root/usr/bin" \
  "$package_root/usr/share/applications" \
  "$package_root/usr/share/icons/hicolor/256x256/apps"
cp -a "$bundle_dir/." "$install_root/"
ln -s ../lib/setsuna/setsuna "$package_root/usr/bin/setsuna"
install -m 0644 \
  "$workspace/assets/logo/app.png" \
  "$package_root/usr/share/icons/hicolor/256x256/apps/com.gt610.setsuna.png"

cat > "$package_root/usr/share/applications/com.gt610.setsuna.desktop" <<'DESKTOP'
[Desktop Entry]
Name=Setsuna
Comment=Manage local and remote Aria2 download instances
Exec=/usr/lib/setsuna/setsuna %U
Icon=com.gt610.setsuna
Terminal=false
Type=Application
Categories=Network;FileTransfer;
MimeType=application/x-bittorrent;x-scheme-handler/magnet;
StartupWMClass=com.gt610.setsuna
DESKTOP

cat > "$package_root/DEBIAN/control" <<CONTROL
Package: setsuna
Version: ${build_name}-${build_number}
Section: net
Priority: optional
Architecture: ${deb_arch}
Maintainer: GT-610
Depends: libc6, libgcc-s1, libstdc++6, libssl3, libgtk-3-0,
 libsecret-1-0, libayatana-appindicator3-1, libnotify4, xdg-utils
Description: Cross-platform Aria2 download manager
 Setsuna manages a bundled Aria2 Next process and remote aria2 instances.
CONTROL

deb_path="$output_dir/Setsuna_${tag_name}_linux_${artifact_arch}.deb"
dpkg-deb --root-owner-group --build "$package_root" "$deb_path"

echo "Created $archive_path"
echo "Created $deb_path"
