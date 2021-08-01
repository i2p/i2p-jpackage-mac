#!/bin/bash
set -e 

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

if [ -z "${I2P_SIGNER}" ]; then
    echo "I2P_SIGNER variable not set, can't sign.  Aborting..."
    exit 1
fi

if [ -z ${I2P_VERSION} ]; then
    echo "I2P_VERSION not set, aborting"
    exit 1
fi

if [ -z ${I2P_BUILD_NUMBER} ]; then
    echo "please set the I2P_BUILD_NUMBER variable to some integer >= 1"
    exit 1
fi

JAVA_HOME="$(/usr/libexec/java_home)"
echo "JAVA_HOME is $JAVA_HOME"

echo "cleaning"
./clean.sh

HERE=$PWD
I2P_JARS=$HERE/../i2p.i2p/pkg-temp/lib
I2P_PKG=$HERE/../i2p.i2p/pkg-temp

mkdir build

echo "compiling custom launcher"
cp $I2P_JARS/*.jar build
cd java
javac -d ../build -classpath ../build/i2p.jar:../build/router.jar net/i2p/router/MacLauncher.java
cd ..

echo "copying mac-update.sh"
cp bash/mac-update.sh build

echo "building launcher.jar"
cd build
jar -cf launcher.jar net mac-update.sh
cd ..

echo "compiling native lib"
cc -v -Wl,-lobjc -mmacosx-version-min=10.9 -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/darwin" -Ic -o build/libMacLauncher.jnilib -shared c/net_i2p_router_MacLauncher.c 

echo "signing jbigi libs"
mkdir jbigi
cp $I2P_JARS/jbigi.jar jbigi
cd jbigi
unzip jbigi.jar
for lib in *.jnilib; do
    codesign --force -s $I2P_SIGNER -v $lib
    jar uf jbigi.jar $lib
done
cp jbigi.jar ../build
cd ..

I2P_VERSION=$(java -cp build/router.jar net.i2p.router.RouterVersion | sed "s/.*: //" | head -n 1)
echo "preparing to invoke jpackage for I2P version $I2P_VERSION build $I2P_BUILD_NUMBER"

cp "$I2P_PKG/Start I2P Router.app/Contents/Resources/i2p.icns" build/I2P.icns
cp "$I2P_PKG/Start I2P Router.app/Contents/Resources/i2p.icns" build/I2P-volume.icns
cp $I2P_PKG/LICENSE.txt build
cp resources/I2P-background.tiff build

cp resources/Info.plist.template build/Info.plist
sed -i.bak "s/I2P_VERSION/$I2P_VERSION/g" build/Info.plist
sed -i.bak "s/I2P_BUILD_NUMBER/$I2P_BUILD_NUMBER/g" build/Info.plist

cp resources/I2P-dmg-setup.scpt.template build/I2P-dmg-setup.scpt
sed -i.bak "s@__HERE__@${HERE}@g" build/I2P-dmg-setup.scpt

rm build/*.bak

jpackage --name I2P  \
        --java-options "-Xmx512m" \
        --java-options "--illegal-access=permit" \
        --type app-image \
        --verbose \
        --resource-dir build \
        --input build --main-jar launcher.jar --main-class net.i2p.router.MacLauncher

echo "adding pkg-temp to resources"
cp -R $I2P_PKG/* I2P.app/Contents/Resources
for i in i2prouter lib locale man wrapper.config eepget runplain.sh postinstall.sh osid; do
    rm -rf I2P.app/Contents/Resources/$i
done
cp $HERE/resources/GPLv2+CE.txt I2P.app/Contents/Resources/licenses/LICENSE-JRE.txt
cp $HERE/build/libMacLauncher.jnilib I2P.app/Contents/Resources

echo "signing the runtime libraries"
find I2P.app -name *.dylib -exec codesign --force -s $I2P_SIGNER -v '{}' \;
find I2P.app -name *.jnilib -exec codesign --force -s $I2P_SIGNER -v '{}' \;

echo "signing the bundle"
codesign --force -d --deep -f \
    --options=runtime \
    --entitlements resources/entitlements.xml \
    -s $I2P_SIGNER \
    --verbose=4 \
    I2P.app

jpackage --name I2P --app-image I2P.app --app-version $I2P_VERSION \
        --verbose --temp tmp \
        --license-file build/LICENSE.txt \
        --resource-dir build

