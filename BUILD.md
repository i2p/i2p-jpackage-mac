Building an I2P Easy-Install Bundle for Mac
===========================================

This documents building the I2P Easy-Install for Mac end-to-end, including the
set up, configuration, and maintenance of a build environment.

Setting up a Java SDK manager
-----------------------------

Unlike many popular Linux distributions, Mac OSX does not have a built-in way
of switching between Java versions. There are several third-party tools for
doing this, including `sdkman` and `asdf`. After evaluation, I found
sdkman to be the most complete and easy to use. Installation instructions are
available here:

- https://sdkman.io/install

Since it uses a curlpipe to install, please be sure to pay attention to the
content of the install script.

- https://get.sdkman.io

After you follow the install instructions, you will be able to fetch java SDKs
and automatically configure your `JAVA_HOME`.

Currently, bundles are built with OpenJDK 19.

```sh
sdk install java 19.0.1-open
sdk use java 19.0.1-open
```

Will automatically set up your OpenJDK 19.

If you do not wish to use an SDK manager, or you with to use a different SDK
manager, this [Stack Overflow link](https://stackoverflow.com/questions/52524112/how-do-i-install-java-on-mac-osx-allowing-version-switching)
shows every option in detail.

Setting up Brew and resolving build dependencies
------------------------------------------------

There are also a number of build dependencies for I2P which you will need to
keep up to date. This is aided by the use of the brew package manager. Obtain
`brew` by installing it according to the instructions here:

- https://brew.sh/

Once Brew is finished installing, install the I2P build dependencies.

```sh
brew install ant gettext gradle
```

Remember to run `brew update` and `brew upgrade ant gettext gradle` before
rebuilding I2P.

Building the I2P Router Dependencies and the Package
----------------------------------------------------

Once you have all that installed you're ready to build the core I2P router
libraries and package the application. This can all be automated with the use
of `build.sh`. In order to do this successfully, you need to be able to sign
OSX packages, using a certificate which you obtain from Apple itself. Obtaining
that certificate is outside the scope of this document primarily because I do
not have the ability to obtain such a certificate without sharing my identity
with Apple.

 - https://developer.apple.com/support/certificates/
 - https://developer.apple.com/documentation/appstoreconnectapi/certificates

In order to configure your release environment, you must set the following
environment variables:

 - `I2P_SIGNER` should be the [Apple Developer ID of the signer](https://developer.apple.com/support/developer-id/)
 - `I2P_VERSION` should be the version of the I2P router that you want to use
 - `I2P_BUILD_NUMBER` should be an integer greater than `0`.

Ensure you have a copy of `i2p.i2p` checked out adjacent to the
`i2p-jpackage-mac` directory, in the same parent. If this is your first time
building the jpackage, run the following command:

```sh
git clone https://i2pgit.org/i2p-hackers/i2p.i2p
```

Change to the `i2p.i2p` directory and check out the release branch you want to
build a package for, e.g. `i2p-1.9.0`

```sh
cd ../i2p.i2p
git pull --tags
git checkout i2p-1.9.0
```

Now that you have the right branch, clean and rebuild the core library:

```sh
ant clean preppkg-osx-only
```

Then, change back to the `i2p-jpackage-mac` directory:

```sh
cd ../i2p-jpackage-mac
```

Finally, run the `build.sh` script to generate the `.dmg` file.

```sh
./build.sh
```

Creating a new release
----------------------

