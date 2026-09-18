#!/bin/bash
set -euo pipefail
repo_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_directory"
swift test "$@"
plutil -lint Cuentiva.xcodeproj/project.pbxproj
plutil -lint "Cuentiva/3 - App Resources/PrivacyInfo.xcprivacy"
git diff --check
