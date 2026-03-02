#!/bin/bash
set -e

HAR_PATH="library/build/default/outputs/default/library.har"

VERSION=$(grep -o '"version": *"[^"]*"' library/oh-package.json5 | head -1 | grep -o '"[^"]*"$' | tr -d '"')

echo "=== Webnat OHPM Publisher ==="
echo "Version: $VERSION"
echo ""

echo "[1/3] Building HAR..."
hvigorw --mode module -p module=library@default -p product=default assembleHar --no-daemon
echo ""

if [ ! -f "$HAR_PATH" ]; then
    echo "Error: HAR file not found at $HAR_PATH"
    exit 1
fi

echo "[2/3] Build complete: $HAR_PATH"
echo ""
read -p "[3/3] Publish webnat@${VERSION} to OHPM? (y/N) " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

ohpm publish "$HAR_PATH"

echo ""
echo "Done! webnat@${VERSION} has been submitted to OHPM."
