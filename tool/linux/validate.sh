#!/usr/bin/env bash
# Run on Linux with the SDK pinned in .fvmrc. No hardware claims from hosted CI.
set -euo pipefail
cd "$(dirname "$0")/../.."
[[ $(uname -s) == Linux ]] || { echo 'Linux validation requires a Linux host.' >&2; exit 1; }
flutter_bin=${FLUTTER_BIN:-flutter}
flutter_path=$(command -v "$flutter_bin")
sdk_bin=$(cd "$(dirname "$flutter_path")" && pwd -P)
export PATH="$sdk_bin:$PATH"
pin=$(python3 -c 'import json; print(json.load(open(".fvmrc"))["flutter"])')
version=$("$flutter_bin" --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')
[[ $version == "$pin" ]] || { echo "Expected Flutter $pin; found $version." >&2; exit 1; }
"$flutter_bin" config --enable-linux-desktop
"$flutter_bin" pub get --enforce-lockfile
"$sdk_bin/dart" format --output=none --set-exit-if-changed lib test integration_test test_driver tool/motion_probe.dart
"$flutter_bin" analyze
"$sdk_bin/dart" run rive_native:setup --verbose --platform linux
cmake -S linux/native_tests -B build/linux-native-tests -DCMAKE_BUILD_TYPE=Release
cmake --build build/linux-native-tests --parallel
ctest --test-dir build/linux-native-tests --output-on-failure
"$flutter_bin" build linux --release
# Rive asset tests load the actual Linux plugin, produced by the complete build.
case $(uname -m) in
  x86_64) arch=x64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo 'Unsupported Linux architecture.' >&2; exit 1 ;;
esac
export LD_LIBRARY_PATH="$PWD/build/linux/$arch/release/bundle/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$flutter_bin" test
./tool/linux/package.sh
