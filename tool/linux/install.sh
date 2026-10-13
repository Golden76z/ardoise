#!/usr/bin/env bash
# Compile Ardoise en version release et l'installe pour l'utilisateur courant :
# il apparaît alors dans le lanceur d'applications (wofi, rofi, fuzzel…).
# Relancer le script met à jour l'installation.
#
#   tool/linux/install.sh             installer / mettre à jour
#   tool/linux/install.sh --remove    désinstaller (le vault n'est pas touché)
set -euo pipefail

APP_ID="dev.golden.ardoise"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
DEST="$DATA/ardoise"
BIN="$HOME/.local/bin/ardoise"
DESKTOP="$DATA/applications/$APP_ID.desktop"
ICON_SVG="$DATA/icons/hicolor/scalable/apps/$APP_ID.svg"
ICON_PNG="$DATA/icons/hicolor/512x512/apps/$APP_ID.png"

refresh() {
  command -v update-desktop-database >/dev/null &&
    update-desktop-database -q "$DATA/applications" || true
  command -v gtk-update-icon-cache >/dev/null &&
    gtk-update-icon-cache -q -t "$DATA/icons/hicolor" || true
}

if [[ "${1:-}" == "--remove" ]]; then
  rm -rf "$DEST"
  rm -f "$BIN" "$DESKTOP" "$ICON_SVG" "$ICON_PNG"
  refresh
  echo "Ardoise désinstallé."
  exit 0
fi

cd "$(dirname "$0")/../.."
flutter build linux --release

# Le binaire a besoin de ses dossiers lib/ et data/ à côté de lui : on copie
# tout le bundle, et le lien de ~/.local/bin pointe dedans.
rm -rf "$DEST"
mkdir -p "$DEST" "$(dirname "$BIN")" "$(dirname "$DESKTOP")" \
  "$(dirname "$ICON_SVG")" "$(dirname "$ICON_PNG")"
cp -r build/linux/x64/release/bundle/. "$DEST/"
ln -sf "$DEST/ardoise" "$BIN"
cp tool/linux/ardoise.svg "$ICON_SVG"
cp tool/linux/ardoise.png "$ICON_PNG"

cat > "$DESKTOP" <<DESKTOP_ENTRY
[Desktop Entry]
Type=Application
Name=Ardoise
GenericName=Suivi de demandes
Comment=Bugs, fonctionnalités et idées, dans ton vault Obsidian
Exec=$DEST/ardoise
Icon=$APP_ID
Terminal=false
Categories=Office;ProjectManagement;
Keywords=kanban;tâches;obsidian;
StartupWMClass=$APP_ID
DESKTOP_ENTRY

refresh
echo "Ardoise installé : $DEST"
echo "Lanceur : $DESKTOP"
