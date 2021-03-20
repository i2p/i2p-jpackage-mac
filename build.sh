#!/bin/bash
set -e 

JAVA=$(java --version | tr -d 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ\n' | cut -d ' ' -f 2 | cut -d '.' -f 1 | tr -d '\n\t ')

if [ "$JAVA" -lt "16" ]; then
	echo "Java 16+ must be used to compile with jpackage on Mac, java is $JAVA"
	exit 1
fi

if [ -z "${I2P_SIGNER}" ]; then
    echo "I2P_SIGNER variable not set, can't sign.  Aborting..."
    exit 1
fi

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

echo "building launcher.jar"
cd build
jar -cf launcher.jar net
cd ..

if [ -z $I2P_VERSION ]; then 
    I2P_VERSION=$(java -cp build/router.jar net.i2p.router.RouterVersion | sed "s/.*: //" | head -n 1)
fi
echo "preparing to invoke jpackage for I2P version $I2P_VERSION"

cp "$I2P_PKG/Start I2P Router.app/Contents/Resources/i2p.icns" build/I2P.icns
cp "$I2P_PKG/Start I2P Router.app/Contents/Resources/i2p.icns" build/I2P-volume.icns
cp $I2P_PKG/LICENSE.txt build

jpackage --name I2P --app-version $I2P_VERSION \
        --type app-image \
        --verbose \
        --resource-dir build \
        --input build --main-jar launcher.jar --main-class net.i2p.router.MacLauncher

cp -R $I2P_PKG/* I2P.app/Contents/Resources
rm -rf I2P.app/Contents/Resources/lib

codesign --force -d --deep -f \
    -s $I2P_SIGNER \
    --verbose=4 \
    I2P.app

jpackage --name I2P --app-image I2P.app --app-version $I2P_VERSION \
        --verbose \
        --license-file build/LICENSE.txt \
        --resource-dir build

