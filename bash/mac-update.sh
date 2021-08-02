#!/bin/bash
set -e

if [ -z $I2P_PID ]; then
    echo "I2P_PID not set"
    exit 1
fi

if [ -z $I2P_VERSION ]; then
    echo "I2P_VERSION not set"
    exit 1
fi

if [ -z ${BUNDLE_HOME} ]; then
    echo "BUNDLE_HOME not set"
    exit 1
fi

echo "Performing mac update, environment:"
echo "I2P_PID $I2P_PID"
echo "I2P_VERSION $I2P_VERSION"
echo "BUNDLE_HOME ${BUNDLE_HOME}"

UPDATE_DMG=I2P-${I2P_VERSION}.dmg

if [ ! -f ${UPDATE_DMG} ]; then
    echo "File ${UPDATE_DMG} does not exist"
    exit 1
fi

echo "waiting for $I2P_PID to terminate..."
while [ 0 -eq $(ps -o pid $I2P_PID > /dev/null ; echo $?) ]; do
    sleep 1
done


echo "cleaning up"
rm -rfv mount_point I2P.cdr

echo "converting to CDR format"
hdiutil convert -quiet -format UDTO -o I2P ${UPDATE_DMG}

echo "mounting"
hdiutil attach -quiet -nobrowse -noverify -noautoopen -mountpoint mount_point I2P.cdr

echo "removing old I2P.app"
rm -rf "${BUNDLE_HOME}"/I2P.app

echo "copying new I2P.app"
cp -R mount_point/I2P.app "${BUNDLE_HOME}"

echo "unmounting and cleaning up"
hdiutil detach mount_point
rm -f I2P.cdr "${UPDATE_DMG}"

echo "launching I2P"
open "${BUNDLE_HOME}"/I2P.app
