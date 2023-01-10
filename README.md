# I2P JPackage Mac

JPackage scripts for packaging I2P on a Mac.

### Requirements

* Java 16 or newer.  Even though JPackage existed since 14, it was broken.
* An Apple signing certificate.  The JBigi and JRE libs and the final bundle MUST be signed or users will get a scary warning.

### Building

1. Clone `i2p.i2p` as a sibling to this module
1. Build it with `ant clean preppkg-osx-only`
1. Set the `I2P_SIGNER` environment variable to a string identifying the signer.
1. Set the `I2P_BUILD_NUMBER` environment variable to some integer >= 1
1. Run `build.sh`

### How does it work

In order to build an AppBundle that can work from anywhere, it is necessary to use a dedicated main class which determines the current working directory and sets `i2p.dir.base` to the correct location inside the AppBundle.  Therefore the `build.sh` script:

1. Compiles the custom main class and puts it in a `launcher.jar`
1. Invokes JPackage with the `--app-image` switch to create the directory structure of the bundle
1. Copies the contents of `../i2p.i2p/pkg-temp` inside the AppBundle, except for the `jars` directory
1. Signs the AppBundle
1. Invokes JPackage again to build the final .dmg

### Notarization

1. You need an "app-specific password" which you can create at https://appleid.apple.com
2. Execute 
```
xcrun notarytool store-credentials "$AC_PASSWORD"
               --apple-id "$AC_USERNAME"
               --team-id "$WWDRTeamID"
               --password "$secret_2FA_password"
```
 - In this example command:
 - `AC_PASSWORD` is the name of the credentials config.
 - `AC_USERNAME` is the username of the Apple Account.
 - `WWDRTeamID` is the developer/team ID available from the Apple Account.
 - `secret_2FA_Password` is the app-specific password you set up in the first step.
3. Periodically execute the following to check the progress of the notarisation:
```
xcrun altool --eval-info <the long UUID string> -u <your Apple id>
````
4. If that returns success, staple the notarization to the dmg:
```
xcrun stapler staple <name of the .dmg>
```

