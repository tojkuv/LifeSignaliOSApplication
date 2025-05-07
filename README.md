# LifeSignal iOS Application

This is the iOS application for the LifeSignal project, which allows users to stay connected with their loved ones and emergency contacts.

## Repository Structure

The repository is organized as follows:

- `LifeSignal/`: Main application code (Xcode project)
  - `LifeSignal/`: Application source code
  - `LifeSignalTests/`: Unit tests
  - `LifeSignalUITests/`: UI tests
  - `Assets.xcassets/`: Application assets
  - `LifeSignal.xcodeproj/`: Xcode project file
- `Deployment/`: Deployment scripts and configuration files
  - `deploy_to_app_store_connect.sh`: Script for deploying to App Store Connect
  - `app_store_connect.env`: Environment variables for App Store Connect API
  - `AppSubmissionKey.p8`: App Store Connect API key file

## Development

### Prerequisites

- Xcode 15.0 or later
- iOS 17.0 SDK or later
- Swift 5.9 or later

### Getting Started

1. Clone the repository
2. Open `LifeSignal.xcodeproj` in Xcode
3. Build and run the project

### Project Setup

To set up the development environment, run the following script:

```bash
./scripts/utils/setup_dev_environment.sh
```

If you need to update the project structure, use:

```bash
./scripts/utils/update_project_structure.sh
```

#### App Store Connect Credentials

To use the App Store Connect API, you need to set up your credentials:

1. Copy the template file:
   ```bash
   cp Deployment/app_store_connect.env.template Deployment/app_store_connect.env
   ```

2. Edit the file and fill in your credentials:
   ```bash
   # App Store Connect API Key ID
   ASC_API_KEY_ID="YOUR_API_KEY_ID"

   # App Store Connect Issuer ID
   ASC_ISSUER_ID="YOUR_ISSUER_ID"

   # Path to the App Store Connect API Key file
   ASC_API_KEY_PATH="AppSubmissionKey.p8"
   ```

3. Make sure your API key file is in the Deployment directory

## Deployment

### Publishing to App Store Connect

To publish the app to App Store Connect, use the `deploy_to_app_store_connect.sh` script:

```bash
./Deployment/deploy_to_app_store_connect.sh
```

This script will:
1. Build and archive the app
2. Export the archive as an IPA file
3. Validate the IPA file with App Store Connect
4. Upload the IPA file to App Store Connect

The script will use the credentials from the `Deployment/app_store_connect.env` file. You can also override these credentials by providing them as command-line options:

```bash
./Deployment/deploy_to_app_store_connect.sh --api-key-id X2QSX76QDW --issuer-id 4423b788-e70b-4afb-b811-ab91f51f3ef6 --api-key-path Deployment/AppSubmissionKey.p8
```

#### Command-line Options

The script supports the following command-line options:

- `--skip-validation`: Skip the validation step
- `--skip-build`: Skip the build and archive step (useful if you already have an IPA file)
- `--api-key-id KEY_ID`: App Store Connect API Key ID
- `--issuer-id ISSUER_ID`: App Store Connect Issuer ID
- `--api-key-path PATH`: Path to the App Store Connect API Key file
- `--team-id TEAM_ID`: Apple Developer Team ID
- `--bundle-id BUNDLE_ID`: App Bundle ID
- `--help`: Show help message

For example, to skip the validation step:

```bash
./Deployment/deploy_to_app_store_connect.sh --skip-validation
```

Or to skip the build step and use an existing IPA file:

```bash
./Deployment/deploy_to_app_store_connect.sh --skip-build
```

## License

This project is proprietary and confidential. Unauthorized copying, distribution, or use is strictly prohibited.
