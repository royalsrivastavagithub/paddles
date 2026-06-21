#!/bin/bash
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
LOVE_VERSION="11.5"

rm -rf "$DIST"
mkdir -p "$DIST/linux/icons" "$DIST/windows" "$DIST/love"
[ -f "$ROOT/assets/icons/paddles.png" ] && cp "$ROOT/assets/icons/paddles.png" "$DIST/linux/icons/paddles.png"

echo "Building paddles.love..."
cd "$ROOT"
zip -9 -r "$DIST/paddles.love" . \
  -x ".git/*" ".gitignore" "settings.dat" "scripts/*" "dist/*" "README.md"

# ---- love/ ----
cp "$DIST/paddles.love" "$DIST/love/paddles.love"

# ---- linux/ ----
cp "$DIST/paddles.love" "$DIST/linux/paddles.love"

cat > "$DIST/linux/paddles" << 'SCRIPT'
#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
exec love "$DIR/paddles.love" "$@"
SCRIPT
chmod +x "$DIST/linux/paddles"

cat > "$DIST/linux/launch.sh" << 'LAUNCH'
#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
if command -v love >/dev/null 2>&1; then
    love "$DIR/paddles.love" "$@"
elif [ -f /snap/bin/love ]; then
    /snap/bin/love "$DIR/paddles.love" "$@"
else
    echo "Error: LÖVE not found. Install it or use the Windows exe."
    exit 1
fi
LAUNCH
chmod +x "$DIST/linux/launch.sh"

cat > "$DIST/linux/install.sh" << 'INSTALL'
#!/bin/sh
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${1:-/usr/local}"
INSTALL_DIR="/opt/paddles"

echo "Installing Paddles to $INSTALL_DIR..."
sudo mkdir -p "$INSTALL_DIR"
sudo cp "$DIR/paddles.love" "$DIR/paddles" "$INSTALL_DIR/"
sudo chmod +x "$INSTALL_DIR/paddles"

sudo mkdir -p "$PREFIX/bin"
sudo ln -sf "$INSTALL_DIR/paddles" "$PREFIX/bin/paddles"

ICON="$DIR/icons/paddles.png"
if [ -f "$ICON" ]; then
    sudo mkdir -p "$PREFIX/share/icons/hicolor/256x256/apps"
    sudo cp "$ICON" "$PREFIX/share/icons/hicolor/256x256/apps/paddles.png"
fi

sudo mkdir -p "$PREFIX/share/applications"
sudo cp "$DIR/paddles.desktop" "$PREFIX/share/applications/paddles.desktop"

echo "Done! Run 'paddles' to play."
INSTALL
chmod +x "$DIST/linux/install.sh"

cat > "$DIST/linux/paddles.desktop" << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=Paddles
Comment=A classic Pong game with AI difficulties
Exec=paddles
Icon=paddles
Terminal=false
Categories=Game;
DESKTOP

# ---- windows/ ----
if command -v curl &>/dev/null; then
    echo "Downloading LOVE $LOVE_VERSION for Windows..."
    curl -sL "https://github.com/love2d/love/releases/download/$LOVE_VERSION/love-$LOVE_VERSION-win64.zip" \
      -o /tmp/love-win64.zip
    unzip -qo /tmp/love-win64.zip -d /tmp/love-win64
    cat /tmp/love-win64/love-$LOVE_VERSION-win64/love.exe "$DIST/paddles.love" > "$DIST/windows/paddles.exe"
    cp /tmp/love-win64/love-$LOVE_VERSION-win64/*.dll "$DIST/windows/"
    rm -rf /tmp/love-win64 /tmp/love-win64.zip
    echo "Windows executable created."
else
    echo "curl not found — skipping Windows exe (install curl to enable)"
fi

rm "$DIST/paddles.love"

echo ""
echo "Done! Files:"
find "$DIST" -type f | sed 's|.*dist/|  dist/|' | sort
