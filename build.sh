#!/bin/bash
set -e 

if [ -z "$I2P_VERSION" ]; then
    I2P_VERSION="2.1.0"
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

if [ -z "$I2P_SIGNER" ]; then
    I2P_SIGNER=$(security find-identity -v -p codesigning | cut -d ' ' -f 4)
    echo "Warning: using automatically configured signer ID, make sure this is the one you want: $I2P_SIGNER"
    echo "continuing in 10 seconds"
    sleep 10s
fi
if [ -z "$I2P_CODE_SIGNER" ]; then
    I2P_CODE_SIGNER=$(security find-identity -v -p codesigning | cut -d ' ' -f 4)
    echo "Warning: using automatically configured signer ID, make sure this is the one you want: $I2P_CODE_SIGNER"
    echo "continuing in 10 seconds"
    sleep 10s
fi
if [ -z "$I2P_SIGNER_USERPHRASE" ]; then
    I2P_SIGNER_USERPHRASE=$(security find-identity -v -p codesigning | cut -d ' ' -f 4)
    echo "Warning: using automatically configured signer ID, make sure this is the one you want: $I2P_SIGNER_USERPHRASE"
    echo "continuing in 10 seconds"
    sleep 10s
fi



echo "JAVA_HOME is $JAVA_HOME"

echo "cleaning"
./clean.sh

ARCH=$(uname -m)
HERE=$PWD
I2P_SRC=$HERE/../i2p.i2p-jpackage-mac/

if [ ! -d "$I2P_SRC" ]; then
    git clone https://i2pgit.org/i2p-hackers/i2p.i2p "$I2P_SRC"
fi

I2P_JARS=$HERE/../i2p.i2p-jpackage-mac/pkg-temp/lib
I2P_PKG=$HERE/../i2p.i2p-jpackage-mac/pkg-temp


cd "$I2P_SRC"
git switch - || :
git pull --tags
git checkout "i2p-$I2P_VERSION"
OLDEXTRA=$(find ../i2p.i2p-jpackage-mac -name RouterVersion.java -exec grep 'String EXTRA' {} \;)
if [ -z "$EXTRA" ]; then
    export EXTRACODE="mac"
    export EXTRA="    public final static String EXTRA = \"-$EXTRACODE\";"
fi
sed -i.bak "s|$OLDEXTRA|$EXTRA|g" "$I2P_SRC/router/java/src/net/i2p/router/RouterVersion.java"
git checkout -b "i2p-$I2P_VERSION-$EXTRACODE" && git commit -am "i2p-$I2P_VERSION-$EXTRACODE"
git archive --format=tar.gz --output="$HERE/i2p.i2p.jpackage-mac.tar.gz" "i2p-$I2P_VERSION-$EXTRACODE"
if [ ! -d "$I2P_PKG" ]; then
    ant clean preppkg-osx-only
fi
cd "$HERE"

mkdir build

echo "compiling custom launcher and update processor"
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

echo "compiling native lib"
cc -v -Wl,-lobjc -mmacosx-version-min=10.9 -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/darwin" -Ic -o build/libMacLauncher.jnilib -shared c/net_i2p_router_MacLauncher.c 

if [ -z "$I2P_SIGNER" ]; then
    echo "I2P_SIGNER is unset, not proceeding to sign jbigi libs"
    cp "$I2P_JARS"/jbigi.jar build
else
    echo "signing jbigi libs"
    mkdir jbigi
    cp "$I2P_JARS"/jbigi.jar jbigi
    cd jbigi
    unzip jbigi.jar
    for lib in *.jnilib; do
        codesign --force -s "$I2P_SIGNER" -v "$lib"
        jar uf jbigi.jar "$lib"
    done
    cp jbigi.jar ../build
    cd ..
fi

echo "preparing to invoke jpackage for I2P version $I2P_VERSION build $I2P_BUILD_NUMBER"

cp "$I2P_PKG/Start I2P Router.app/Contents/Resources/i2p.icns" build/I2P.icns
cp "$I2P_PKG/Start I2P Router.app/Contents/Resources/i2p.icns" build/I2P-volume.icns
cp "$I2P_PKG/LICENSE.txt" build
cat resources/License-JRE-snippet.txt >> build/LICENSE.txt
cp resources/I2P-background.tiff build

cp resources/Info.plist.template build/Info.plist
sed -i.bak "s/I2P_VERSION/$I2P_VERSION/g" build/Info.plist
sed -i.bak "s/I2P_BUILD_NUMBER/$I2P_BUILD_NUMBER/g" build/Info.plist

cp resources/I2P-dmg-setup.scpt.template build/I2P-dmg-setup.scpt
sed -i.bak "s@__HERE__@${HERE}@g" build/I2P-dmg-setup.scpt

rm build/*.bak

jpackage --name I2P  \
        --java-options "-Xmx512m" \
        --java-options "--add-opens java.base/java.lang=ALL-UNNAMED" \
        --java-options "--add-opens java.base/sun.nio.fs=ALL-UNNAMED" \
        --java-options "--add-opens java.base/java.nio=ALL-UNNAMED" \
        --type app-image \
        --verbose \
        --resource-dir build \
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
cp "$HERE"/resources/*.crt I2P.app/Contents/Resources/certificates/router

if [ -z "$I2P_SIGNER" ]; then
    echo "I2P_SIGNER is unset, not proceeding to signing phase"
    exit 0 
fi

if [ -z "$I2P_CODE_SIGNER" ]; then
    echo "I2P_CODE_SIGNER is unset, not proceeding to signing phase"
    exit 0 
fi

echo "NOT signing the runtime libraries"

#find I2P.app -name "*.dylib" -exec codesign --force -s "$I2P_SIGNER" -v '{}' \;
#find I2P.app -name "*.jnilib" -exec codesign --force -s "$I2P_CODE_SIGNER" -v '{}' \;

echo "signing the bundle"
#codesign --force -f \
#    --options=runtime \
#    --entitlements resources/entitlements.xml \
#    -s "$I2P_SIGNER" \
#    --verbose=4 \
#    I2P.app

jpackage --name I2P --app-image I2P.app --app-version "$I2P_VERSION" \
        --verbose --temp tmp \
        --license-file build/LICENSE.txt \
        --mac-sign \
        --mac-signing-key-user-name "$I2P_SIGNER_USERPHRASE" \
        --mac-entitlements resources/entitlements.xml \
        --resource-dir build
