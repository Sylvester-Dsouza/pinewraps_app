# Codemagic CI/CD Setup for Pinewraps App

This guide explains how to set up and use Codemagic CI/CD for automating the deployment of the Pinewraps app to both App Store and Play Store.

## Prerequisites

1. A Codemagic account (sign up at [codemagic.io](https://codemagic.io))
2. Access to Apple Developer account (for iOS)
3. Access to Google Play Console (for Android)
4. Signing credentials for both platforms

## Setup Steps

### 1. Set up Environment Variables in Codemagic

Create the following environment variable groups in Codemagic UI:

#### keystore_credentials (for Android)
- `ANDROID_KEYSTORE`: Base64 encoded keystore file
- `ANDROID_KEYSTORE_PASSWORD`: Keystore password
- `ANDROID_KEY_ALIAS`: Key alias
- `ANDROID_KEY_PASSWORD`: Key password

To encode your keystore file to base64:
```bash
base64 -i keystore.jks -o keystore_base64.txt
```

#### google_play_credentials (for Android)
- `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS`: Google Play service account JSON key file content

#### app_store_credentials (for iOS)
- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect API key issuer ID
- `APP_STORE_CONNECT_KEY_IDENTIFIER`: App Store Connect API key identifier
- `APP_STORE_CONNECT_PRIVATE_KEY`: App Store Connect API private key
- `APPLE_TEAM_ID`: Your Apple Developer Team ID
- `PROVISIONING_PROFILE`: Name of your provisioning profile

#### firebase_credentials (optional, for Firebase)
- `FIREBASE_CLI_TOKEN`: Firebase CLI token for Firebase App Distribution

### 2. Connect Your Repository

1. Log in to Codemagic
2. Add your app by connecting to your Git provider
3. Select the Pinewraps repository
4. Choose "Use codemagic.yaml" as your build configuration

### 3. Customize the Workflows (if needed)

The `codemagic.yaml` file includes two workflows:
- `android-workflow`: Builds and publishes Android app to Play Store
- `ios-workflow`: Builds and publishes iOS app to App Store

You can customize these workflows by editing the `codemagic.yaml` file.

### 4. Start Your First Build

1. Go to your app in Codemagic
2. Select the workflow you want to run
3. Click "Start new build"

## Workflow Configuration

### Android Workflow

- Builds an Android App Bundle (AAB)
- Publishes to Google Play (internal track by default)
- You can change the track by modifying the `GOOGLE_PLAY_TRACK` variable

### iOS Workflow

- Builds an iOS IPA file
- Submits to TestFlight
- Can be configured to submit directly to App Store

## Automatic Triggers

You can set up automatic triggers based on:
- Push to specific branches
- Pull request events
- Tag creation

To configure automatic triggers, go to your app settings in Codemagic.

## Troubleshooting

If you encounter any issues:
1. Check the build logs in Codemagic
2. Verify your environment variables are set correctly
3. Ensure your signing credentials are valid
4. Check that your app meets the store requirements

## Additional Resources

- [Codemagic Documentation](https://docs.codemagic.io/)
- [Flutter Deployment Guide](https://docs.flutter.dev/deployment)
- [Google Play Publishing](https://docs.codemagic.io/publishing/publishing-to-google-play/)
- [App Store Publishing](https://docs.codemagic.io/publishing/publishing-to-app-store/)
