#!/bin/bash
set -e 

export GITHUB_TAG=$(git describe --tags --abbrev=0 | sed 's|i2p||g' | tr -d [a-z-])

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
I2P_SRC_BASE=$HERE/i2p.i2p/

rm -rf "$I2P_SRC"
if [ ! -d "$I2P_SRC_BASE" ]; then
    git clone https://i2pgit.org/i2p-hackers/i2p.i2p "$I2P_SRC_BASE"
fi
cd "$I2P_SRC_BASE" && git pull --tags && cd "$HERE"
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
if [ ! -d "$I2P_PKG" ]; then
    ant clean preppkg-osx-only
fi
cd "$HERE"

mkdir build

echo "compiling custom launcher and update processor"
cc -v -Wl,-lobjc -mmacosx-version-min=10.9 -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/darwin" -Ic -o build/libMacLauncher.jnilib -shared c/net_i2p_router_MacLauncher.c 
cp "$I2P_JARS"/*.jar build
cd java
javac -d ../build -classpath ../build/i2p.jar:../build/router.jar net/i2p/router/MacLauncher.java net/i2p/update/*.java
cd "$HERE"

echo "copying mac-update.sh"
cp bash/mac-update.sh build

echo "building launcher.jar"
cd build
jar -cf launcher.jar net mac-update.sh
cd ..

echo "preparing to invoke jpackage for I2P version $I2P_RELEASE_VERSION build $I2P_BUILD_NUMBER"

cp "$I2P_PKG/Start I2P Router.app/Contents/Resources/i2p.icns" build/I2P.icns
cp "$I2P_PKG/Start I2P Router.app/Contents/Resources/i2p.icns" build/I2P-volume.icns
cp "$I2P_PKG/LICENSE.txt" build
cat resources/License-JRE-snippet.txt >> build/LICENSE.txt
cp resources/I2P-background.tiff build

cp resources/Info.plist.template build/Info.plist
sed -i.bak "s/I2P_VERSION/$I2P_RELEASE_VERSION/g" build/Info.plist
sed -i.bak "s/I2P_BUILD_NUMBER/$I2P_BUILD_NUMBER/g" build/Info.plist

cp resources/I2P-dmg-setup.scpt.template build/I2P-dmg-setup.scpt
sed -i.bak "s@__HERE__@${HERE}@g" build/I2P-dmg-setup.scpt

rm build/*.bak

if [ -z $I2P_SIGNER_USERPHRASE ]; then
    SIGNING_ARG="--mac-signing-key-user-name $I2P_SIGNER_USERPHRASE"
fi

jpackage --name I2P  \
        --java-options "-Xmx512m" \
        --java-options "--add-opens java.base/java.lang=ALL-UNNAMED" \
        --java-options "--add-opens java.base/sun.nio.fs=ALL-UNNAMED" \
        --java-options "--add-opens java.base/java.nio=ALL-UNNAMED" \
        --type app-image \
        --verbose \
        --resource-dir build \
        $SIGNING_ARG \
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

jpackage --name I2P  \
        --java-options "-Xmx512m" \
        --java-options "--add-opens java.base/java.lang=ALL-UNNAMED" \
        --java-options "--add-opens java.base/sun.nio.fs=ALL-UNNAMED" \
        --java-options "--add-opens java.base/java.nio=ALL-UNNAMED" \
        --type dmg \
        --verbose \
        --resource-dir build \
        $SIGNING_ARG \
        --mac-entitlements resources/entitlements.xml \
        --input build --main-jar launcher.jar --main-class net.i2p.router.MacLauncher

ls -lah I2P*.dmg
ls -lahd I2P*