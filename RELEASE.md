# AfterClose Release Build Guide

## Prerequisites

1. Flutter SDK installed (3.x)
2. Android Studio or Xcode for platform-specific tools
3. Valid Apple Developer account (for iOS)
4. Google Play Developer account (for Android)

## Android Release Build

### 1. Create Signing Key (First Time Only)

```bash
cd android

# Generate a new keystore
keytool -genkey -v -keystore afterclose-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias afterclose

# Follow the prompts to set passwords and certificate info
```

### 2. Configure Signing

```bash
# Copy the template and fill in your values
cp key.properties.template key.properties

# Edit key.properties with your actual values:
# storePassword=your_keystore_password
# keyPassword=your_key_password
# keyAlias=afterclose
# storeFile=/absolute/path/to/afterclose-release.jks
```

### 3. Build APK

```bash
cd /path/to/afterclose

# Clean build
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Build release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### 4. Build App Bundle (Recommended for Play Store)

```bash
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

## iOS Release Build

### 1. Configure Xcode Project

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner target
3. Under "Signing & Capabilities":
   - Select your Team
   - Bundle Identifier: `com.neo.afterclose`
   - Enable "Automatically manage signing"

### 2. Build Archive

```bash
cd /path/to/afterclose

# Clean build
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Build iOS release
flutter build ios --release

# Open Xcode for archive
open ios/Runner.xcworkspace
```

In Xcode:
1. Product → Archive
2. Distribute App → App Store Connect
3. Follow the upload wizard

### 3. Alternative: Command Line Build

```bash
# Build IPA for distribution
flutter build ipa --release

# Output: build/ios/ipa/afterclose.ipa
```

## App Icon & Splash Screen

### Generate App Icons

1. Place your icon files in `assets/icons/`:
   - `app_icon.png` (1024x1024 px)
   - `app_icon_foreground.png` (1024x1024 px with padding)

2. Run the generator:
```bash
dart run flutter_launcher_icons
```

### Generate Splash Screen

1. Place your splash files in `assets/icons/`:
   - `splash_logo.png` (512x512 px)
   - `splash_branding.png` (200x50 px, optional)

2. Run the generator:
```bash
dart run flutter_native_splash:create
```

## Version Management

Update version in `pubspec.yaml`:

```yaml
version: 1.0.0+1
# format: major.minor.patch+buildNumber
```

- Increment `buildNumber` for each release
- Follow semantic versioning for version string

## Pre-Release Checklist

- [ ] Update version number in `pubspec.yaml`
- [ ] Run all tests: `flutter test`
- [ ] Check for analysis issues: `flutter analyze`
- [ ] Generate app icons (if changed)
- [ ] Generate splash screen (if changed)
- [ ] Test on physical devices (both platforms)
- [ ] Review permissions in manifests
- [ ] Check all strings are translated
- [ ] Remove debug code and print statements
- [ ] Update changelog/release notes

## Build Commands Summary

```bash
# Full release build process
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Android
flutter build apk --release          # APK
flutter build appbundle --release    # App Bundle

# iOS
flutter build ios --release          # For Xcode archive
flutter build ipa --release          # Direct IPA

# With obfuscation (recommended for production)
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
flutter build ipa --release --obfuscate --split-debug-info=build/debug-info
```

## Troubleshooting

### Android Build Issues

**Keystore not found:**
- Verify the path in `key.properties` is absolute
- Check file permissions

**Signing failed:**
- Verify passwords are correct
- Check keyAlias matches the one used during key generation

### iOS Build Issues

**Code signing error:**
- Open Xcode and re-select your team
- Revoke and regenerate certificates if needed

**Archive fails:**
- Check bundle identifier matches App Store Connect
- Verify provisioning profiles are valid

## Security Notes

- Never commit `key.properties` or keystore files
- Store signing credentials securely (e.g., 1Password, Vault)
- Use CI/CD secrets for automated builds
- Keep debug info files for crash symbolication
