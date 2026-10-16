#!/usr/bin/env bash
# Run from the extracted bundle. Installs user launcher only; never runs as root.
set -euo pipefail
[[ $(id -u) != 0 ]] || { echo 'Run as your desktop user, without sudo.' >&2; exit 1; }
bundle=$(cd "$(dirname "$0")" && pwd -P)
[[ -x "$bundle/wifi_analyser" && -f "$bundle/wave.svg" ]] || { echo 'Run this script from a complete extracted Wave bundle.' >&2; exit 1; }
# Desktop entry fields cannot safely represent newline paths.
[[ $bundle != *$'\n'* && $bundle != *$'\r'* && $bundle != *=* ]] || { echo 'Move bundle to a path without newlines or equals signs.' >&2; exit 1; }
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
mkdir -p "$data_home/applications" "$data_home/icons/hicolor/scalable/apps"
cp "$bundle/wave.svg" "$data_home/icons/hicolor/scalable/apps/com.samirpandey.wifi_analyser.svg"
# Desktop Exec quoting is not shell quoting. Escape reserved characters and % codes.
escaped=${bundle//\\/\\\\}
escaped=${escaped//\"/\\\"}
escaped=${escaped//\$/\\\$}
escaped=${escaped//\`/\\\`}
escaped=${escaped//%/%%}
# Desktop string unescaping happens before Exec argument unquoting.
escaped=${escaped//\\/\\\\}
cat > "$data_home/applications/com.samirpandey.wifi_analyser.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Wave - WiFi Analyser
Comment=Explore nearby WiFi networks
Exec="$escaped/wifi_analyser"
Icon=com.samirpandey.wifi_analyser
Terminal=false
Categories=Network;Utility;
StartupWMClass=com.samirpandey.wifi_analyser
DESKTOP
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$data_home/applications"
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1 && [[ -f "$data_home/icons/hicolor/index.theme" ]]; then
  gtk-update-icon-cache -f -t "$data_home/icons/hicolor"
fi
echo 'Installed Wave launcher for current user. Keep bundle at its current path.'
