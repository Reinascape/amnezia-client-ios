#!/bin/bash
echo "Build script started ..."

set -o errexit -o nounset

# Hold on to current directory
PROJECT_DIR=$(pwd)

BUILD_DIR=$PROJECT_DIR/build-ios
mkdir -p $BUILD_DIR

echo "Project dir: ${PROJECT_DIR}"
echo "Build dir: ${BUILD_DIR}"

APP_NAME=AmneziaVPN
APP_FILENAME=$APP_NAME.app
APP_DOMAIN=org.amneziavpn.package


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
$QT_BIN_DIR/qt-cmake . -B $BUILD_DIR -GXcode -DQT_HOST_PATH=$QT_MACOS_ROOT_DIR -DDEPLOY=ON

# Build project
xcodebuild \
-configuration Release \
-scheme AmneziaVPN \
-destination "generic/platform=iOS,name=Any iOS'" \
-project $BUILD_DIR/AmneziaVPN.xcodeproj

# restore keychain
security default-keychain -s login.keychain
