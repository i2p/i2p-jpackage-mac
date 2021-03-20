# I2P JPackage Mac

JPackage scripts for packaging I2P on a Mac.

### Building

1. Clone `i2p.i2p` as a sibling to this module
1. Build it with `ant clean preppkg-osx`
1. Set the `I2P_SIGNER` environment variable to a string identifying the signer.
1. Set the `I2P_VERSION` environment variable to override the version from the jars.  Mac OS doesn't like versions that start with `0`.
1. Run `build.sh`

### How does it work

In order to build an AppBundle that can work from anywhere, it is necessary to use a dedicated main class which determines the current working directory and sets `i2p.dir.base` to the correct location inside the AppBundle.  Therefore the `build.sh` script:

1. Compiles the custom main clas and puts it in a `MacLauncher.jar`
1. Invokes JPackage with the `--app-image` switch to create the directory structure of the bundle
1. Copies the contents of `../i2p.i2p/pkg-temp` inside the AppBundle, except for the `jars` directory
1. Invokes JPackage again to build the final .dmg
