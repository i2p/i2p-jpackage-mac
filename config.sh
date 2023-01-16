#! /usr/bin/env sh

# Uncomment/Edit this line to include the signer in the config file
# I2P_SIGNER=JIHGFEDCBA
# Uncomment/Edit this line to include the code signer in the config file
# I2P_CODE_SIGNER=ABCDEFGHIJ
# Uncomment/Edit this line to include the phrase identifying the signer to jpackage in the config file
# I2P_CODE_SIGNER=3rd Party Mac Developer Application: John Smith (ABCDEFGHIJ)


# Uncomment/Edit this line to include the version number in the config file
# I2P_VERSION=2.1.0
# Uncomment/Edit this line to include the build number in the config file
# I2P_BUILD_NUMBER=1

if [ -z $I2P_VERSION ]; then
    I2P_VERSION=2.1.0
fi
if [ -z $I2P_BUILD_NUMBER ]; then
    I2P_BUILD_NUMBER=1
fi

if [ -z $I2P_SIGNER ]; then
    # This is the team ID of the Apple account associated with the app. It is used to sign the DMG.
    # it is a unique ID which is a short, random-looking string.
    echo "I2P_SIGNER not set, signing will not work"
fi
if [ -z $I2P_CODE_SIGNER ]; then
    # This is the code signing ID of the team associated with the Apple Account. it is used to sign the libraries.
    # it is a unique ID which is a short, random-looking string.
    echo "I2P_CODE_SIGNER not set, signing will not work"
fi
if [ -z $I2P_SIGNER_USERPHRASE ]; then
    # This is an the phrase identifying the third party developer(I2P) in the following form:
    # 3rd Party Mac Developer Application: John Smith (ABCDEFGHIJ)
    echo "I2P_SIGNER_USERPHRASE not set, signing will not work"
fi

