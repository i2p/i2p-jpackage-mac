# Notarization

Apple notarization is required for apps distributed outside the Mac App Store. Since macOS 10.15 Catalina, Gatekeeper requires notarization for apps from identified developers.

## Prerequisites

1. A valid **Developer ID Application** certificate installed in your Keychain
2. An **app-specific password** created at https://appleid.apple.com (under Sign-In and Security → App-Specific Passwords)
3. Your **Team ID** (visible in Apple Developer portal, e.g., `GZXYAV4ZG2`)

## Step 1: Store Credentials (One-Time Setup)

Store your notarization credentials in the Keychain for reuse:

```bash
xcrun notarytool store-credentials "notary-profile" \
    --apple-id "your-apple-id@example.com" \
    --team-id "GZXYAV4ZG2" \
    --password "xxxx-xxxx-xxxx-xxxx"
```

- `notary-profile` - A name you choose for this credential set
- `--apple-id` - Your Apple ID email
- `--team-id` - Your developer Team ID
- `--password` - The app-specific password (NOT your Apple ID password)

## Step 2: Submit for Notarization

After building and signing the DMG:

```bash
xcrun notarytool submit I2P-2.7.0.dmg \
    --keychain-profile "notary-profile" \
    --wait
```

The `--wait` flag blocks until notarization completes (typically 5-15 minutes).

## Step 3: Staple the Ticket

On success, staple the notarization ticket to the DMG:

```bash
xcrun stapler staple I2P-2.7.0.dmg
```

Stapling embeds the notarization ticket, allowing offline verification by users.

## Checking Notarization Status

If you submitted without `--wait`, check status with:

```bash
xcrun notarytool history --keychain-profile "notary-profile"
xcrun notarytool log <submission-id> --keychain-profile "notary-profile"
```

## Verifying the Final DMG

```bash
# Verify the app signature
codesign --verify --deep --strict --verbose=2 /Volumes/I2P/I2P.app

# Check Gatekeeper acceptance
spctl -a -t exec -vv /Volumes/I2P/I2P.app
# Expected output should include: "source=Notarized Developer ID"

# Verify stapling
xcrun stapler validate I2P-2.7.0.dmg
```

## Common Issues

| Issue | Solution |
|-------|----------|
| "Invalid credentials" | Regenerate app-specific password, re-run store-credentials |
| "Unsigned binaries" | Ensure all .dylib and .jar files inside the bundle are signed |
| "Hardened runtime not enabled" | Add `--options runtime` to codesign commands |
| "No timestamp" | Add `--timestamp` to codesign commands |

## References

- [Apple: Notarizing macOS Software Before Distribution](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [StackOverflow: Code signing notarization using jpackage](https://stackoverflow.com/questions/60953329/code-signing-notarization-using-jpackage-utility-isnt-working-on-macos)

## Notes on Signing Keys

- You can always refer to a certificate by its SHA-256 fingerprint
- The fingerprint works in every codesign/notarytool command
- Find your fingerprint: `security find-identity -v -p codesigning`
