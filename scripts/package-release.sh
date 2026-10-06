#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh "$@"
APP="$PWD/dist/LyricFloat.app"
ARCHS="$(lipo -archs "$APP/Contents/MacOS/LyricFloat")"
if [[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]]; then
  LABEL=universal
elif [[ "$ARCHS" == *arm64* ]]; then
  LABEL=arm64
elif [[ "$ARCHS" == *x86_64* ]]; then
  LABEL=intel
else
  print -u2 "Unsupported architecture: $ARCHS"
  exit 1
fi
mkdir -p dist/packages
APP_ZIP="$PWD/dist/packages/LyricFloat-macos-$LABEL.zip"
EXTENSION_ZIP="$PWD/dist/packages/LyricFloat-browser-extension.zip"
# ditto preserves the executable permissions and app bundle structure.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$APP_ZIP"
# Keep manifest.json at the ZIP root, also suitable for a future store upload.
python3 - "$PWD/BrowserExtension" "$EXTENSION_ZIP" <<'PY'
from pathlib import Path
import sys, zipfile
root, output = Path(sys.argv[1]), Path(sys.argv[2])
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(root.rglob('*')):
        if file.is_file() and not any(part.startswith('.') for part in file.relative_to(root).parts):
            archive.write(file, file.relative_to(root).as_posix())
PY
python3 scripts/verify-release.py "$APP_ZIP" "$EXTENSION_ZIP"
(cd dist/packages && shasum -a 256 "LyricFloat-macos-$LABEL.zip" LyricFloat-browser-extension.zip > SHA256SUMS)
print "Packages: $APP_ZIP and $EXTENSION_ZIP"
