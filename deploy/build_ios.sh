#!/bin/bash
echo "Build script started..."

set -o errexit -o nounset

# Hold on to current directory
PROJECT_DIR=$(pwd)

BUILD_DIR=$PROJECT_DIR/build-ios
mkdir -p $BUILD_DIR

echo "Project dir: ${PROJECT_DIR}"
echo "Build dir: ${BUILD_DIR}"

APP_NAME=AmneziaVPN
APP_FILENAME=$APP_NAME.app

# Search Qt
if [ -z "${QT_VERSION+x}" ]; then
  QT_VERSION=6.6.2;
  QT_BIN_DIR=$HOME/Qt/$QT_VERSION/ios/bin
fi

echo "Using Qt in $QT_BIN_DIR"

# Checking env
$QT_BIN_DIR/qt-cmake --version
cmake --version
clang -v

# Generate XCodeProj
echo "Generating Xcode project..."
$QT_BIN_DIR/qt-cmake . -B $BUILD_DIR -GXcode \
  -DQT_HOST_PATH=$QT_MACOS_ROOT_DIR \
  -DDEPLOY=ON

echo "Building unsigned IPA..."

xcodebuild \
  -project $BUILD_DIR/AmneziaVPN.xcodeproj \
  -scheme AmneziaVPN \
  -configuration Release \
  -destination "generic/platform=iOS" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  OTHER_CODE_SIGN_FLAGS="" \
  build

echo "Archive created successfully (unsigned)"

# Optional: create unsigned .ipa
echo "Exporting unsigned IPA..."

xcodebuild \
  -exportArchive \
  -archivePath $BUILD_DIR/Release-iphoneos/AmneziaVPN.xcarchive \
  -exportPath $PROJECT_DIR \
  -exportOptionsPlist <(cat <<EOF
{
  "method": "ad-hoc",
  "signingStyle": "manual",
  "signingCertificate": "",
  "teamID": "",
  "provisioningProfiles": {},
  "iCloudContainerEnvironment": "Production"
}
EOF
) \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY=""

echo "Unsigned IPA build successfully: $PROJECT_DIR/AmneziaVPN-iOS.ipa"
