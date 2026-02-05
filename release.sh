#!/bin/bash
# I2P macOS Release Script
# All-in-one script for building, signing, notarizing, and stapling
# Supports both I2P and I2P+ builds

set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

# Load signing credentials
if [ -f "./config.sh" ]; then
    source ./config.sh
else
    echo "Error: config.sh not found. Please create it with your signing identity."
    exit 1
fi

echo "=========================================="
echo "  I2P macOS Release Builder"
echo "=========================================="
echo ""

# Choose variant
echo "Select variant to build:"
echo "  1) I2P (standard)"
echo "  2) I2P+ (enhanced)"
echo ""
read -p "Select variant [1-2]: " VARIANT_SELECTION

if [ "$VARIANT_SELECTION" = "2" ]; then
    I2P_PLUS=1
    VARIANT_NAME="I2P+"
    REPO_URL="https://github.com/I2PPlus/i2pplus.git"
    DMG_PREFIX="I2P+"
else
    I2P_PLUS=""
    VARIANT_NAME="I2P"
    REPO_URL="https://github.com/i2p/i2p.i2p.git"
    DMG_PREFIX="I2P"
fi

echo ""
echo "Building: $VARIANT_NAME"
echo ""

# Fetch latest tags from selected repo
echo "Fetching latest tags from $VARIANT_NAME..."
# Clone/update repo to get tags with dates, then sort by date
if [ -n "$I2P_PLUS" ]; then
    REPO_DIR="$HERE/i2pplus"
else
    REPO_DIR="$HERE/i2p.i2p"
fi

if [ ! -d "$REPO_DIR" ]; then
    git clone "$REPO_URL" "$REPO_DIR"
else
    git -C "$REPO_DIR" fetch --tags 2>/dev/null || true
fi

# Get tags sorted by commit date (newest first)
TAGS=$(git -C "$REPO_DIR" tag --sort=-creatordate | \
    grep -vE '(cvs|_|post|rc)' | \
    grep -E '^(i2p-)?[0-9]+\.[0-9]+\.[0-9]+' | \
    head -10)

if [ -z "$TAGS" ]; then
    echo "Error: Could not fetch tags from repository"
    exit 1
fi

echo ""
echo "Available releases:"
echo "-------------------"
i=1
declare -a TAG_ARRAY
for tag in $TAGS; do
    TAG_ARRAY[$i]="$tag"
    echo "  $i) $tag"
    ((i++))
done
echo ""

# Prompt for selection
read -p "Select a version to build [1-10]: " SELECTION

if [[ ! "$SELECTION" =~ ^([1-9]|10)$ ]]; then
    echo "Invalid selection"
    exit 1
fi

SELECTED_TAG="${TAG_ARRAY[$SELECTION]}"
echo ""
echo "Selected: $SELECTED_TAG"

# Extract version number (remove i2p- prefix if present)
VERSION=$(echo "$SELECTED_TAG" | sed 's/^i2p-//')

echo ""
echo "Build configuration:"
echo "  Variant: $VARIANT_NAME"
echo "  I2P_VERSION: $SELECTED_TAG"
echo "  PUBLISH_VERSION: $VERSION"
echo "  Output: $DMG_PREFIX-$VERSION.dmg"
echo ""

read -p "Proceed with build? [Y/n]: " PROCEED
if [[ "$PROCEED" =~ ^[Nn]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Run the build
echo ""
echo "=========================================="
echo "  Building $VARIANT_NAME $VERSION"
echo "=========================================="
echo ""

I2P_PLUS="$I2P_PLUS" I2P_VERSION="$SELECTED_TAG" PUBLISH_VERSION="$VERSION" ./build.sh

DMG_FILE="$DMG_PREFIX-$VERSION.dmg"

if [ ! -f "$DMG_FILE" ]; then
    echo "Error: Build failed - $DMG_FILE not found"
    exit 1
fi

echo ""
echo "Build complete: $DMG_FILE"
echo ""

# Ask about notarization
read -p "Submit for notarization? [Y/n]: " NOTARIZE
if [[ "$NOTARIZE" =~ ^[Nn]$ ]]; then
    echo ""
    echo "Skipping notarization. You can manually notarize later with:"
    echo "  xcrun notarytool submit $DMG_FILE --keychain-profile \"i2p-notary\" --wait"
    echo ""
    exit 0
fi

echo ""
echo "=========================================="
echo "  Submitting for Notarization"
echo "=========================================="
echo ""

xcrun notarytool submit "$DMG_FILE" --keychain-profile "i2p-notary" --wait

# Check if notarization succeeded
NOTARY_STATUS=$(xcrun notarytool info $(xcrun notarytool history --keychain-profile "i2p-notary" 2>/dev/null | grep "$DMG_FILE" | head -1 | awk '{print $1}') --keychain-profile "i2p-notary" 2>/dev/null | grep "status:" | awk '{print $2}')

if [ "$NOTARY_STATUS" != "Accepted" ]; then
    echo ""
    echo "Notarization may have failed. Check status with:"
    echo "  xcrun notarytool history --keychain-profile \"i2p-notary\""
    echo ""
    read -p "Attempt to staple anyway? [y/N]: " STAPLE_ANYWAY
    if [[ ! "$STAPLE_ANYWAY" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Staple
echo ""
echo "=========================================="
echo "  Stapling Notarization Ticket"
echo "=========================================="
echo ""

xcrun stapler staple "$DMG_FILE"

# Generate GPG signature
echo ""
echo "=========================================="
echo "  Generating GPG Signature"
echo "=========================================="
echo ""

SIG_FILE="${DMG_FILE}.sig"
rm -f "$SIG_FILE"

if gpg --detach-sign --armor -o "$SIG_FILE" "$DMG_FILE"; then
    echo "GPG signature created: $SIG_FILE"
else
    echo "Warning: GPG signing failed. You may need to sign manually:"
    echo "  gpg --detach-sign --armor -o $SIG_FILE $DMG_FILE"
fi

echo ""
echo "=========================================="
echo "  Release Complete!"
echo "=========================================="
echo ""
echo "  DMG:       $DMG_FILE"
echo "  Signature: $SIG_FILE"
echo "  Size:      $(ls -lh "$DMG_FILE" | awk '{print $5}')"
echo ""

# Verify
echo "Verification:"
hdiutil attach "$DMG_FILE" -mountpoint /tmp/i2p_verify_release -quiet
spctl -a -v /tmp/i2p_verify_release/I2P.app 2>&1 | head -2
hdiutil detach /tmp/i2p_verify_release -quiet

if [ -f "$SIG_FILE" ]; then
    echo ""
    echo "GPG Signature fingerprint:"
    gpg --verify "$SIG_FILE" "$DMG_FILE" 2>&1 | grep -E "Good signature|key"
fi

echo ""
echo "Done! Ready to distribute."
echo ""
echo "Files to upload:"
echo "  - $DMG_FILE"
echo "  - $SIG_FILE"
