#!/bin/bash

# deploy_to_app_store_connect.sh
# This script validates, signs, and publishes the app to App Store Connect
# Created on May 6, 2025

# Usage: ./Deployment/deploy_to_app_store_connect.sh [options]
#
# Options:
#   --skip-validation     Skip the validation step
#   --skip-build          Skip the build and archive step
#   --api-key-id KEY_ID   App Store Connect API Key ID
#   --issuer-id ISSUER_ID App Store Connect Issuer ID
#   --api-key-path PATH   Path to the App Store Connect API Key file
#   --team-id TEAM_ID     Apple Developer Team ID
#   --bundle-id BUNDLE_ID App Bundle ID
#   --help                Show this help message
#
# Example: ./Deployment/deploy_to_app_store_connect.sh
# Example with options: ./Deployment/deploy_to_app_store_connect.sh --skip-validation

set -e

# Default values
SKIP_VALIDATION=false
SKIP_BUILD=false
PROJECT_DIR="LifeSignal"
PROJECT_FILE="$PROJECT_DIR/LifeSignal.xcodeproj"
SCHEME="LifeSignal"
CONFIGURATION="Release"
ARCHIVE_PATH="Deployment/build/LifeSignal.xcarchive"
IPA_PATH="Deployment/build/LifeSignal.ipa"
EXPORT_OPTIONS_PATH="Deployment/build/ExportOptions.plist"

# Function to show help
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --skip-validation     Skip the validation step"
    echo "  --skip-build          Skip the build and archive step"
    echo "  --api-key-id KEY_ID   App Store Connect API Key ID"
    echo "  --issuer-id ISSUER_ID App Store Connect Issuer ID"
    echo "  --api-key-path PATH   Path to the App Store Connect API Key file"
    echo "  --team-id TEAM_ID     Apple Developer Team ID"
    echo "  --bundle-id BUNDLE_ID App Bundle ID"
    echo "  --help                Show this help message"
    echo ""
    echo "Example: $0"
    echo "Example with options: $0 --skip-validation"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --api-key-id)
            API_KEY_ID="$2"
            shift 2
            ;;
        --issuer-id)
            ISSUER_ID="$2"
            shift 2
            ;;
        --api-key-path)
            API_KEY_PATH="$2"
            shift 2
            ;;
        --team-id)
            TEAM_ID="$2"
            shift 2
            ;;
        --bundle-id)
            BUNDLE_ID="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Load environment variables from config file
CONFIG_FILE="Deployment/app_store_connect.env"
if [ -f "$CONFIG_FILE" ]; then
    echo "Loading environment variables from $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo "Warning: Config file not found at $CONFIG_FILE"
    echo "Using default or provided values"
fi

# Set values from environment variables if not provided as arguments
API_KEY_ID="${API_KEY_ID:-${ASC_API_KEY_ID:-}}"
ISSUER_ID="${ISSUER_ID:-${ASC_ISSUER_ID:-}}"
API_KEY_PATH="${API_KEY_PATH:-${ASC_API_KEY_PATH:-}}"
TEAM_ID="${TEAM_ID:-${ASC_TEAM_ID:-}}"
BUNDLE_ID="${BUNDLE_ID:-${ASC_BUNDLE_ID:-}}"

# Update API_KEY_PATH to use Deployment directory if it's a relative path
if [[ "$API_KEY_PATH" != /* ]] && [[ "$API_KEY_PATH" != Deployment/* ]]; then
    API_KEY_PATH="Deployment/$API_KEY_PATH"
fi

# Check if credentials are provided
if [ -z "$API_KEY_ID" ] || [ -z "$ISSUER_ID" ] || [ -z "$API_KEY_PATH" ]; then
    echo "Error: App Store Connect credentials are missing"
    echo "Please provide them as arguments or in the $CONFIG_FILE file"
    exit 1
fi

echo "===== Publishing LifeSignal iOS Application to App Store ====="
echo "API Key ID: $API_KEY_ID"
echo "Issuer ID: $ISSUER_ID"
echo "API Key Path: $API_KEY_PATH"
echo "Team ID: $TEAM_ID"
echo "Bundle ID: $BUNDLE_ID"

# Check if the API key file exists
if [ ! -f "$API_KEY_PATH" ]; then
    echo "Error: API key file not found at $API_KEY_PATH"
    exit 1
fi

# Create build directory if it doesn't exist
mkdir -p Deployment/build

# Step 1: Build, archive and export the app (if not skipped)

# Step 2: Validate the app (if not skipped)
if [ "$SKIP_VALIDATION" = false ]; then
    echo "Step 2: Validating the app..."
    xcrun altool --validate-app -f "$IPA_PATH" --apiKey "$API_KEY_ID" --apiIssuer "$ISSUER_ID" --type ios

    if [ $? -ne 0 ]; then
        echo "Error: App validation failed!"
        exit 1
    fi

    echo "App validation successful!"
else
    echo "Step 2: Skipping validation (--skip-validation flag provided)"
fi

# Step 3: Upload the app to App Store Connect

# Use the API key file with the expected name format

# Check if upload was successful
if [ $? -ne 0 ]; then
    echo "Error: App upload failed"
    exit 1
fi

echo "App uploaded successfully to App Store Connect"
echo "Please check App Store Connect for the status of your app"
echo "===== Publishing Completed ====="