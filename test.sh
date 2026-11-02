#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./build-debug.sh -Xswiftc -warnings-as-errors
./swift-test.sh

./.debug/looper -h > /dev/null
./.debug/looper --help > /dev/null
./.debug/looper -v | grep -q "0.0.0-SNAPSHOT SNAPSHOT"
./.debug/looper --version | grep -q "0.0.0-SNAPSHOT SNAPSHOT"

./lint.sh
./generate.sh
./script/check-uncommitted-files.sh

echo
echo "✅ All tests have passed successfully"
