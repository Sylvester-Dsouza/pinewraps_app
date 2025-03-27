# Pinewraps App CI/CD Setup with Codemagic Workflow UI

This document provides instructions for setting up continuous integration and deployment for the Pinewraps app using Codemagic's Workflow UI.

## Overview

The CI/CD pipeline is configured to:
- Build and deploy Android apps to Google Play Store
- Build and deploy iOS apps to App Store
- Run automated tests and code analysis
- Notify team members of build status

## Prerequisites

Before you begin, ensure you have:

### For Android:
1. A Google Play Console account with access to the Pinewraps app
2. A Google Cloud service account with Play Store publishing permissions
3. Android keystore file for signing the app

### For iOS:
1. An Apple Developer account with access to the Pinewraps app
2. App Store Connect API key
3. iOS distribution certificate and provisioning profile

## Setup Instructions

### 1. Codemagic Account Setup

1. Sign up for a Codemagic account at https://codemagic.io/signup
2. Connect your GitHub/GitLab/Bitbucket account
3. Add the Pinewraps repository to Codemagic

### 2. Creating Android Workflow

1. In the Codemagic dashboard, click on "Add application"
2. Select your repository and click "Set up build"
3. Choose "Flutter App" as the project type
4. In the Workflow Editor, configure the following settings:

#### Build Triggers:
- Enable "Trigger on push"
- Set branch pattern to include `main` and `release*`
- Enable "Trigger on tag creation"

#### Environment:
- Flutter version: stable
- Xcode version: latest
- CocoaPods version: default

#### Build for Platforms:
- Select "Android"

#### Build Arguments:
- Build variant: `release`

#### Android Signing:
- Upload your keystore file
- Enter your keystore password, key alias, and key password

#### Pre-build Scripts:
```bash
# Get Flutter packages
flutter packages pub get

# Run Flutter analyze
flutter analyze
```

#### Build Scripts:
```bash
# Build AAB
flutter build appbundle --release

# Build APK for distribution
flutter build apk --release --split-per-abi
```

#### Artifacts:
- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/flutter-apk/*-release.apk`

#### Publishing:
- **Google Play**: 
  - Upload your Google Play service account JSON
  - Select "Internal" track (can be changed to alpha, beta, or production later)
  - Enable "Submit as draft"
- **Email Notifications**:
  - Add your team's email addresses

### 3. Creating iOS Workflow

1. In the Codemagic dashboard, create a new workflow or duplicate the Android workflow
2. Update the following settings:

#### Build for Platforms:
- Select "iOS"

#### iOS Signing:
- Choose "Automatic" code signing method
- Enter your App Store Connect API credentials:
  - Issuer ID
  - Key ID
  - Upload your private key file
- Enter your bundle identifier: `com.pinewraps.app`

#### Build Scripts:
```bash
# Get Flutter packages
flutter packages pub get

# Install pods
find . -name "Podfile" -execdir pod install \;

# Flutter analyze
flutter analyze

# Build IPA
flutter build ipa --release
```

#### Artifacts:
- `build/ios/ipa/*.ipa`

#### Publishing:
- **App Store Connect**:
  - Enable "Submit to TestFlight"
  - Disable "Submit to App Store" (enable after testing)
- **Email Notifications**:
  - Add your team's email addresses

### 4. How to Generate Required Credentials

#### Android Keystore
If you don't have a keystore file yet:
```bash
keytool -genkey -v -keystore pinewraps.keystore -alias pinewraps -keyalg RSA -keysize 2048 -validity 10000
```

#### Google Play Service Account
1. Go to Google Play Console → Setup → API access
2. Create a new service account with "Release manager" role
3. Download the JSON key file

#### App Store Connect API Key
1. Go to App Store Connect → Users and Access → Keys
2. Create a new API key with App Manager role
3. Note down the issuer ID and key ID
4. Save the private key file securely

## Running the Pipeline

### Automatic Triggers
The pipeline is configured to run automatically on:
- Pushes to the `main` branch
- Pushes to branches matching the pattern `release*`
- Tag creation

### Manual Triggers
You can also manually trigger builds from the Codemagic dashboard:
1. Go to your app in Codemagic
2. Select the workflow you want to run
3. Click "Start new build"

## Deployment Strategy

### Android
- Builds are deployed to the Internal testing track in Google Play
- After testing, they can be promoted to Alpha, Beta, and Production tracks

### iOS
- Builds are deployed to TestFlight for testing
- After testing, they can be submitted to the App Store for review

## Troubleshooting

### Common Issues

1. **Build Failures**
   - Check the build logs for specific error messages
   - Ensure all environment variables are correctly set
   - Verify that the keystore and service account credentials are valid

2. **Deployment Failures**
   - Ensure the app version and build number are incremented
   - Check that the app meets the store requirements
   - Verify the service account or API key has sufficient permissions

3. **Code Signing Issues**
   - Verify the keystore or certificate is valid and not expired
   - Ensure the bundle ID matches the provisioning profile

## Additional Resources

- [Codemagic Documentation](https://docs.codemagic.io/)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [App Store Connect Help](https://developer.apple.com/support/app-store-connect/)

## Updating the Workflow

To update the CI/CD pipeline:
1. Go to your app in Codemagic
2. Click on "Workflow settings"
3. Make the necessary changes
4. Save the workflow
