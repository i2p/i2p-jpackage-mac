# I2P JPackage Mac

JPackage scripts for packaging I2P on a Mac.

### Requirements

* Java 16 or newer.  Even though JPackage existed since 14, it was broken.
* An Apple signing certificate.  The JBigi and JRE libs and the final bundle MUST be signed or users will get a scary warning.

### Building

1. See [BUILD.md](BUILD.md)

### How does it work

In order to build an AppBundle that can work from anywhere, it is necessary to use a dedicated main class which determines the current working directory and sets `i2p.dir.base` to the correct location inside the AppBundle.  Therefore the `build.sh` script:

1. Compiles the custom main class and puts it in a `launcher.jar`
1. Invokes JPackage with the `--app-image` switch to create the directory structure of the bundle
1. Copies the contents of `../i2p.i2p/pkg-temp` inside the AppBundle, except for the `jars` directory
1. Signs the AppBundle
1. Invokes JPackage again to build the final .dmg
