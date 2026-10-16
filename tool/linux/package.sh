#!/usr/bin/env bash
# Package the entire Flutter bundle, never only its executable.
set -euo pipefail
cd "$(dirname "$0")/../.."
case "${LINUX_ARCH:-$(uname -m)}" in
  x86_64|x64) arch=x64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo 'Unsupported Linux architecture.' >&2; exit 1 ;;
esac
bundle=${LINUX_BUNDLE:-build/linux/$arch/release/bundle}
for required in wifi_analyser data/icudtl.dat data/flutter_assets/AssetManifest.bin lib/libflutter_linux_gtk.so lib/libapp.so lib/librive_native_plugin.so; do
  [[ -f "$bundle/$required" ]] || { echo "Missing bundle file: $bundle/$required" >&2; exit 1; }
done
[[ -x "$bundle/wifi_analyser" ]] || { echo 'Bundle executable is not executable.' >&2; exit 1; }
mkdir -p dist
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
name=wave-wifi-analyser-linux-$arch
mkdir "$stage/$name"
cp -a "$bundle/." "$stage/$name/"
cp tool/linux/install-launcher.sh "$stage/$name/"
cp assets/branding/wave-icon-light.svg "$stage/$name/wave.svg"
cp docs/LINUX.md "$stage/$name/LINUX.md"
tar -czf "dist/$name.tar.gz" -C "$stage" "$name"
echo "Created dist/$name.tar.gz"
