#!/bin/bash

# setup_dev_environment.sh
# This script sets up the development environment for the LifeSignal iOS application
# Created by Augment AI on May 6, 2025

# Usage: ./scripts/utils/setup_dev_environment.sh
# This script should be run from the root of the repository

set -e

echo "===== Setting Up Development Environment for LifeSignal ====="
echo "Starting the setup process..."

# Step 1: Check if Xcode is installed
echo "Step 1: Checking if Xcode is installed..."
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode is not installed"
    echo "Please install Xcode from the App Store"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -n 1 | awk '{print $2}')
echo "Xcode version: $XCODE_VERSION"

# Step 2: Check if CocoaPods is installed (if used)
echo "Step 2: Checking if CocoaPods is installed..."
if ! command -v pod &> /dev/null; then
    echo "CocoaPods is not installed"
    echo "Installing CocoaPods..."
    sudo gem install cocoapods
else
    POD_VERSION=$(pod --version)
    echo "CocoaPods version: $POD_VERSION"
fi

# Step 3: Install dependencies (if using CocoaPods)
echo "Step 3: Installing dependencies..."
if [ -f "LifeSignal/Podfile" ]; then
    echo "Podfile found, installing dependencies..."
    cd LifeSignal
    pod install
    cd ..
    echo "Dependencies installed successfully"
else
    echo "No Podfile found, skipping dependency installation"
fi

# Step 4: Set up git hooks (optional)
echo "Step 4: Setting up git hooks..."
mkdir -p .git/hooks

# Create a pre-commit hook to run SwiftLint (if installed)
if command -v swiftlint &> /dev/null; then
    echo "SwiftLint found, setting up pre-commit hook..."
    cat > .git/hooks/pre-commit << 'EOL'
#!/bin/bash

# Run SwiftLint
echo "Running SwiftLint..."
swiftlint

# Check if SwiftLint found any errors
if [ $? -ne 0 ]; then
    echo "SwiftLint found issues, please fix them before committing"
    exit 1
fi

exit 0
EOL
    chmod +x .git/hooks/pre-commit
    echo "Pre-commit hook set up successfully"
else
    echo "SwiftLint not found, skipping pre-commit hook setup"
    echo "Consider installing SwiftLint for code quality checks:"
    echo "brew install swiftlint"
fi

echo "
==============================================
DEVELOPMENT ENVIRONMENT SETUP COMPLETE
==============================================

Your development environment has been set up successfully.

Next steps:

1. Open the LifeSignal project in Xcode:
   open LifeSignal/LifeSignal.xcodeproj

2. Build and run the project to ensure everything works as expected

==============================================
"
