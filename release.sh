#! /usr/bin/env sh

I2P_DATE=`date +%Y-%m-%d`

if [ -z ${I2P_OS} ]; then
  I2P_OS=mac
fi
if [ -z ${I2P_BRANCH} ]; then
  I2P_BRANCH=beta
fi
if [ -z ${I2P_DOWNLOAD} ]; then
  echo "\$I2P_DOWNLOAD is not set, an HTTP download will not be added to releases.json"
  sleep 5s
fi

if [ -z ${I2P_VERSION} ]; then
  echo "\$I2P_VERSION not set, aborting"
  exit 1
fi

## TODO:
#
# Once we're here, we'll need to...
# 1. take the .dmg and package it as an su3, then
# 2. generate a torrent file from that .su3, then
# 3. convert that torrent file to a magnet link,
# 4. store it in the variable MAGNET

## At which point, this will have all the information it needs to automatically
# generate the releases.json and put it into a neighboring i2p.newsxml checkout.
# The new workflow for i2p.newsxml will generate a newsfeed for each platform
# and branch using the a specific releases.json to set up the update.

echo "["									| tee ../i2p.newsxml/data/"$I2P_OS"/"$I2P_BRANCH"/releases.json
echo "  {"									| tee -a ../i2p.newsxml/data/"$I2P_OS"/"$I2P_BRANCH"/releases.json
echo "    \"date\": \"$I2P_DATE\","			| tee -a ../i2p.newsxml/data/"$I2P_OS"/"$I2P_BRANCH"/releases.json
echo "    \"version\": \"$I2P_VERSION\","	| tee -a ../i2p.newsxml/data/"$I2P_OS"/"$I2P_BRANCH"/releases.json
echo "    \"minVersion\": \"1.5.0\","		| tee -a ../i2p.newsxml/data/"$I2P_OS"/"$I2P_BRANCH"/releases.json
echo "    \"minJavaVersion\": \"1.8\","		| tee -a ../i2p.newsxml/data/"$I2P_OS"/"$I2P_BRANCH"/releases.json
echo "    \"updates\": {"					| tee -a ../i2p.newsxml/data/"$I2P_OS"/"$I2P_BRANCH"/releases.json
echo "      \"su3\": {"						| tee -a ../i2p.newsxml/data/"$I2P_OS"/"$I2P_BRANCH"/releases.json
echo "        \"torrent\": \"$MAGNET\","	| tee -a ../i2p.newsxml/data/"$I2P_OS"/"$I2P_BRANCH"/releases.json
echo "        \"url\": ["					| tee -a ../i2p.newsxml/data/"$I2P_OS"/"$I2P_BRANCH"/releases.json
echo "          \"$I2P_DOWNLOAD\""			| tee -a ../i2p.newsxml/data/"$I2P_OS"/"$I2P_BRANCH"/releases.json
echo "        ]"							| tee -a ../i2p.newsxml/data/"$I2P_OS"/"$I2P_BRANCH"/releases.json
echo "      }"								| tee -a ../i2p.newsxml/data/"$I2P_OS"/"$I2P_BRANCH"/releases.json
echo "    }"								| tee -a ../i2p.newsxml/data/"$I2P_OS"/"$I2P_BRANCH"/releases.json
echo "  }"									| tee -a ../i2p.newsxml/data/"$I2P_OS"/"$I2P_BRANCH"/releases.json
echo "]"									| tee -a ../i2p.newsxml/data/"$I2P_OS"/"$I2P_BRANCH"/releases.json
