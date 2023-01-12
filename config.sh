#! /usr/bin/env sh

if [ -z $I2P_SIGNER ]; then
    # This is the team ID of the Apple account associated with the app. It is used to sign the DMG.
    # it is a unique ID which is a short, random-looking string.
    I2P_SIGNER=signer@mail.i2p
fi
if [ -z $I2P_CODE_SIGNER ]; then
    # This is the code signing ID of the team associated with the Apple Account. it is used to sign the libraries.
    # it is a unique ID which is a short, random-looking string.
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
# Uncomment/Edit this line to include the code signer in the config file
# I2P_CODE_SIGNER=signer@mail.i2p
# Uncomment/Edit this line to include the version number in the config file
# I2P_VERSION=2.0.0
# Uncomment/Edit this line to include the build number in the config file
# I2P_BUILD_NUMBER=1