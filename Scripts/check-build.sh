#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
plutil -lint PauseMe.xcodeproj/project.pbxproj
plutil -lint PauseMe/PauseMe.entitlements PauseMonitor/PauseMonitor.entitlements PauseMonitor/Info.plist
xcodebuild -list -project PauseMe.xcodeproj
xcodebuild -project PauseMe.xcodeproj -scheme PauseMe -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO build
