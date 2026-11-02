#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

./script/check-uncommitted-files.sh

rm -rf ~/Library/Developer/Xcode/DerivedData/Looper-*
rm -rf ./xcode/.xcode-build

rm -rf ./xcode/Looper.xcodeproj
./generate.sh
