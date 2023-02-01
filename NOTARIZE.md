# Notarization

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

- [This StackOverflow thread contains invaluable information about how to successfully notarize jpackage-based software](https://stackoverflow.com/questions/60953329/code-signing-notarization-using-jpackage-utility-isnt-working-on-macos)

## Things I know about Apple Signing Keys

 - It is always OK to refer to the key by it's sha256 fingerprint, that works in every command