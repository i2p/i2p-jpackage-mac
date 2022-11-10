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
sdk install java 1.19.0-open
sdk use java 1.19.0-open
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