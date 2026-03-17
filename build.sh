#!/bin/bash
set -e
git describe --tags `git rev-list --tags --max-count=1` || exit 1
export GITHUB_TAG=$(git describe --tags `git rev-list --tags --max-count=1` | sed -E -e 's/-[0-9]+$//' | sed 's|i2p||g' | tr -d a-z-)
echo "tag is: $GITHUB_TAG"

# Environment variables take precedence over git tag
if [ -z "$PUBLISH_VERSION" ]; then
    if echo "$GITHUB_TAG" | grep -q '.\..\..'; then
        PUBLISH_VERSION="$GITHUB_TAG"
    else
        echo "github tag $GITHUB_TAG does not match version pattern"
        # no way to guess here, so default to the latest version number:
        PUBLISH_VERSION="2.10.0"
    fi
fi

if [ -z "$I2P_VERSION" ]; then
    I2P_VERSION="i2p-$GITHUB_TAG"
fi

if echo "$I2P_VERSION" | grep -q '.\..\..'; then
    if [ -z "$I2P_RELEASE_VERSION" ]; then
        I2P_RELEASE_VERSION="$I2P_VERSION"
    fi
else
    if [ -z "$I2P_RELEASE_VERSION" ]; then
        I2P_RELEASE_VERSION=$GITHUB_TAG
    fi
fi

echo "using $PUBLISH_VERSION as our release version to placate jpackage"

if [ -z "$I2P_BUILD_NUMBER" ]; then
    I2P_BUILD_NUMBER=1
fi

if [ -f config.sh ]; then
    . "config.sh"
fi

# old javas output version to stderr and don't support --version
JAVA=$(java --version 2>&1 | tr -d 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ\n' | cut -d ' ' -f 2 | cut -d '.' -f 1 | tr -d '\n\t ')

if [ -z "$JAVA" ]; then
	echo "Failed to parse Java version, java is:"
	java -version
	exit 1
fi

if [ "$JAVA" -lt "16" ]; then
	echo "Java 16+ must be used to compile with jpackage on Mac, java is $JAVA"
	exit 1
fi

if [ -z "${JAVA_HOME}" ]; then
    JAVA_HOME=$(/usr/libexec/java_home)
fi

if [ -z "$I2P_SIGNER_USERPHRASE" ]; then
    I2P_SIGNER_USERPHRASE=$(security find-identity -v -p codesigning | head -n 1 | cut -d '"' -f 2)
    echo "Warning: using automatically configured signer ID, make sure this is the one you want: $I2P_SIGNER_USERPHRASE"
    echo "continuing in 10 seconds"
    sleep 10
fi

echo "JAVA_HOME is $JAVA_HOME"

echo "cleaning"
./clean.sh

ARCH=$(uname -m)
HERE=$PWD
I2P_SRC=$HERE/i2p.i2p-jpackage-mac/

# Support I2P+ builds via I2P_PLUS=1 environment variable
if [ -n "$I2P_PLUS" ]; then
    I2P_SRC_BASE=$HERE/i2pplus/
    I2P_REPO="https://github.com/I2PPlus/i2pplus"
    APP_NAME="I2P+"
    echo "Building I2P+ variant"
else
    I2P_SRC_BASE=$HERE/i2p.i2p/
    I2P_REPO="https://github.com/i2p/i2p.i2p"
    APP_NAME="I2P"
fi

rm -rf "$I2P_SRC"
if [ ! -d "$I2P_SRC_BASE" ]; then
    git clone "$I2P_REPO" "$I2P_SRC_BASE"
fi
cd "$I2P_SRC_BASE" && git fetch --tags && git pull && cd "$HERE"
git clone -b "$I2P_VERSION" "$I2P_SRC_BASE" "$I2P_SRC"

I2P_JARS=$HERE/i2p.i2p-jpackage-mac/pkg-temp/lib
I2P_PKG=$HERE/i2p.i2p-jpackage-mac/pkg-temp


cd "$I2P_SRC"
OLDEXTRA=$(grep 'String EXTRA' "$I2P_SRC/router/java/src/net/i2p/router/RouterVersion.java")
if [ -z "$EXTRA" ]; then
    export EXTRACODE="mac"
    export EXTRA="    public final static String EXTRA = \"-$EXTRACODE\";"
fi
sed -i.bak "s|$OLDEXTRA|$EXTRA|g" "$I2P_SRC/router/java/src/net/i2p/router/RouterVersion.java"
git commit -am "$I2P_RELEASE_VERSION-$EXTRACODE"
git checkout -b "$I2P_RELEASE_VERSION-$EXTRACODE" || git checkout "$I2P_RELEASE_VERSION-$EXTRACODE"
git archive --format=tar.gz --output="$HERE/i2p.i2p.jpackage-mac.tar.gz" "$I2P_RELEASE_VERSION-$EXTRACODE"
# Always run ant build - check for jars, not just directory existence
if [ ! -f "$I2P_PKG/lib/i2p.jar" ]; then
    ant clean preppkg-osx-only
fi
cd "$HERE"

# Replace menu bar icon in desktopgui.jar if we have a custom one
if [ -f "$HERE/resources/StatusIcon24.png" ]; then
    echo "replacing menu bar icon in desktopgui.jar"
    DESKTOPGUI_JAR="$I2P_PKG/lib/desktopgui.jar"
    if [ -f "$DESKTOPGUI_JAR" ]; then
        mkdir -p /tmp/desktopgui_patch/desktopgui/resources/images
        cp "$HERE/resources/StatusIcon24.png" /tmp/desktopgui_patch/desktopgui/resources/images/itoopie_black_24.png
        cd /tmp/desktopgui_patch
        jar uf "$DESKTOPGUI_JAR" desktopgui/resources/images/itoopie_black_24.png
        cd "$HERE"
        rm -rf /tmp/desktopgui_patch
    fi
fi

mkdir build

echo "compiling custom launcher and update processor"
cc -v -Wl,-lobjc -mmacosx-version-min=10.9 -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/darwin" -Ic -o build/libMacLauncher.jnilib -shared c/net_i2p_router_MacLauncher.c 
cp "$I2P_JARS"/*.jar build
cd java
javac -d ../build -classpath ../build/i2p.jar:../build/router.jar net/i2p/router/MacLauncher.java net/i2p/router/MacAutoStart.java net/i2p/update/*.java
cd "$HERE"

echo "copying mac-update.sh"
cp bash/mac-update.sh build

echo "building launcher.jar"
cd build
jar -cf launcher.jar net mac-update.sh
cd ..

echo "preparing to invoke jpackage for I2P version $I2P_RELEASE_VERSION build $I2P_BUILD_NUMBER"

# Use custom icon if available, otherwise fall back to the one from I2P repo
if [ -f "$HERE/resources/I2P.icns" ]; then
    cp "$HERE/resources/I2P.icns" build/I2P.icns
    cp "$HERE/resources/I2P.icns" build/I2P-volume.icns
else
    cp "$I2P_PKG/Start I2P Router.app/Contents/Resources/i2p.icns" build/I2P.icns
    cp "$I2P_PKG/Start I2P Router.app/Contents/Resources/i2p.icns" build/I2P-volume.icns
fi
cp "$I2P_PKG/LICENSE.txt" build
cat resources/License-JRE-snippet.txt >> build/LICENSE.txt
cp resources/I2P-background.tiff build

cp resources/Info.plist.template build/Info.plist
sed -i.bak "s/I2P_VERSION/$I2P_RELEASE_VERSION/g" build/Info.plist
sed -i.bak "s/I2P_BUILD_NUMBER/$I2P_BUILD_NUMBER/g" build/Info.plist

rm build/*.bak

SIGNING_ARGS=()
if [ -n "$I2P_SIGNER_USERPHRASE" ]; then
    SIGNING_ARGS=(--mac-signing-key-user-name "$I2P_SIGNER_USERPHRASE")
fi

jpackage --name I2P  \
        --java-options "-Xmx512m" \
        --java-options "--add-opens java.base/java.lang=ALL-UNNAMED" \
        --java-options "--add-opens java.base/sun.nio.fs=ALL-UNNAMED" \
        --java-options "--add-opens java.base/java.nio=ALL-UNNAMED" \
        --type app-image \
        --verbose \
        --resource-dir build \
        "${SIGNING_ARGS[@]}" \
        --mac-entitlements resources/entitlements.xml \
        --input build --main-jar launcher.jar --main-class net.i2p.router.MacLauncher

echo "adding pkg-temp to resources"
cp -R "$I2P_PKG"/* I2P.app/Contents/Resources
for i in i2prouter lib locale man wrapper.config eepget runplain.sh postinstall.sh osid; do
    rm -rf I2P.app/Contents/Resources/$i
done
cp "$HERE"/resources/GPLv2+CE.txt I2P.app/Contents/Resources/licenses/LICENSE-JRE.txt
cp "$I2P_PKG"/licenses/* I2P.app/Contents/Resources/licenses/
cp "$HERE"/build/libMacLauncher.jnilib I2P.app/Contents/Resources
if [ "$ARCH" == "arm64" ]; then
    cp "$HERE/resources/router.config.arm64" I2P.app/Contents/Resources/router.config
else
    cp "$HERE/resources/router.config" I2P.app/Contents/Resources
fi
# consider there might be some reason to re-enable this if an external maintainer arrives
#cp "$HERE"/resources/*.crt I2P.app/Contents/Resources/certificates/router

# Bundle LaunchAgent plist for auto-start at login
echo "bundling LaunchAgent for auto-start support"
mkdir -p I2P.app/Contents/Resources/LaunchAgents
cp "$HERE"/resources/net.i2p.router.plist I2P.app/Contents/Resources/LaunchAgents/

# Copy menu bar status icons if available
if [ -f "$HERE/resources/StatusIcon.png" ]; then
    echo "bundling menu bar status icons"
    cp "$HERE"/resources/StatusIcon.png I2P.app/Contents/Resources/
    cp "$HERE"/resources/StatusIcon@2x.png I2P.app/Contents/Resources/
fi

# Re-sign the app after adding all resources (jpackage's initial signature is invalidated)
if [ -n "$I2P_SIGNER_USERPHRASE" ]; then
    echo "code signing all binaries with Developer ID"

    # Sign all native libraries inside jars (extract, sign, repack)
    echo "signing native libraries inside jbigi.jar..."
    JBIGI_JAR="I2P.app/Contents/app/jbigi.jar"
    if [ -f "$JBIGI_JAR" ]; then
        mkdir -p /tmp/jbigi_sign
        cd /tmp/jbigi_sign
        jar xf "$HERE/$JBIGI_JAR"
        find . -name "*.jnilib" -o -name "*.dylib" | while read lib; do
            codesign --force --options runtime --timestamp \
                --sign "Developer ID Application: $I2P_SIGNER_USERPHRASE" "$lib" 2>/dev/null || true
        done
        jar cf "$HERE/$JBIGI_JAR" *
        cd "$HERE"
        rm -rf /tmp/jbigi_sign
    fi

    # Sign all dylibs and executables in the runtime
    echo "signing JRE runtime binaries..."
    find I2P.app/Contents/runtime -type f \( -name "*.dylib" -o -name "jspawnhelper" -o -perm +111 \) | while read bin; do
        file "$bin" | grep -q "Mach-O" && codesign --force --options runtime --timestamp \
            --sign "Developer ID Application: $I2P_SIGNER_USERPHRASE" "$bin" 2>/dev/null || true
    done

    # Sign all jnilib files in the app
    echo "signing jnilib files..."
    find I2P.app -name "*.jnilib" | while read lib; do
        codesign --force --options runtime --timestamp \
            --sign "Developer ID Application: $I2P_SIGNER_USERPHRASE" "$lib" 2>/dev/null || true
    done

    # Sign the main app bundle
    echo "signing I2P.app bundle..."
    codesign --force --options runtime --timestamp \
        --entitlements resources/entitlements.xml \
        --sign "Developer ID Application: $I2P_SIGNER_USERPHRASE" \
        I2P.app

    echo "verifying signature"
    codesign -dv --verbose=2 I2P.app
fi

# Create DMG with create-dmg for proper drag-to-Applications layout
echo "creating DMG with drag-to-Applications layout"

# Set DMG filename based on variant
if [ -n "$I2P_PLUS" ]; then
    DMG_NAME="I2P+-$PUBLISH_VERSION.dmg"
else
    DMG_NAME="I2P-$PUBLISH_VERSION.dmg"
fi

rm -f "$DMG_NAME"

if [ "$CI" = "true" ]; then
    # CI mode: skip --background and --volicon (require Finder/GUI AppleScript)
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 620 400 \
        --icon-size 100 \
        --icon "I2P.app" 150 185 \
        --app-drop-link 450 185 \
        "$DMG_NAME" \
        "I2P.app"
else
    create-dmg \
        --volname "$APP_NAME" \
        --volicon "build/I2P-volume.icns" \
        --background "resources/I2P-background.tiff" \
        --window-pos 200 120 \
        --window-size 620 400 \
        --icon-size 100 \
        --icon "I2P.app" 150 185 \
        --hide-extension "I2P.app" \
        --app-drop-link 450 185 \
        "$DMG_NAME" \
        "I2P.app"
fi

echo ""
echo "=== Build complete ==="
ls -lah "$DMG_NAME"

# Cleanup build artifacts
echo ""
echo "Cleaning up build artifacts..."
rm -rf build/
rm -rf I2P.app/
rm -rf i2p.i2p-jpackage-mac/
rm -f i2p.i2p.jpackage-mac.tar.gz

echo ""
echo "Done! DMG ready: $DMG_NAME"