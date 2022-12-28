#! /usr/bin/env sh

if [ -z $I2P_SIGNER ]; then
    I2P_SIGNER=signer@mail.i2p
fi
if [ -z $I2P_VERSION ]; then
    I2P_VERSION=2.0.0
fi
if [ -z $I2P_BUILD_NUMBER ]; then
    I2P_BUILD_NUMBER=1
fi
# Uncomment/Edit this line to include the signer in the config file
# I2P_SIGNER=signer@mail.i2p
# Uncomment/Edit this line to include the version number in the config file
# I2P_VERSION=2.0.0
# Uncomment/Edit this line to include the build number in the config file
# I2P_BUILD_NUMBER=1