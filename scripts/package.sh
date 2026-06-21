#!/bin/bash
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
LOVE_VERSION="11.5"

rm -rf "$DIST"
mkdir -p "$DIST"

echo "Building paddles.love..."
cd "$ROOT"
zip -9 -r "$DIST/paddles.love" . \
  -x ".git/*" ".gitignore" "settings.dat" "scripts/*" "dist/*" "README.md"

echo "Creating Linux launcher..."
cat > "$DIST/paddles" << 'SCRIPT'
#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
exec love "$DIR/paddles.love" "$@"
SCRIPT
chmod +x "$DIST/paddles"

cat > "$DIST/paddles.desktop" << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=Paddles
Comment=A classic Pong game with AI difficulties
Exec=paddles
Icon=paddles
Terminal=false
Categories=Game;
DESKTOP

if command -v curl &>/dev/null; then
    echo "Downloading LOVE $LOVE_VERSION for Windows..."
    curl -sL "https://github.com/love2d/love/releases/download/$LOVE_VERSION/love-$LOVE_VERSION-win64.zip" \
      -o /tmp/love-win64.zip
    unzip -qo /tmp/love-win64.zip -d /tmp/love-win64
    cat /tmp/love-win64/love-$LOVE_VERSION-win64/love.exe "$DIST/paddles.love" > "$DIST/paddles.exe"
    cp /tmp/love-win64/love-$LOVE_VERSION-win64/*.dll "$DIST/"
    rm -rf /tmp/love-win64 /tmp/love-win64.zip
    echo "Windows executable created: paddles.exe"
else
    echo "curl not found — skipping Windows exe (install curl to enable)"
fi

echo ""
echo "Done! Files in $DIST:"
ls -lh "$DIST"
