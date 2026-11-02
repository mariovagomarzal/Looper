#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

build_version="0.0.0-SNAPSHOT"
codesign_identity="looper-codesign-certificate"
while test $# -gt 0; do
    case $1 in
        --build-version) build_version="$2"; shift 2;;
        --codesign-identity) codesign_identity="$2"; shift 2;;
        *) echo "Unknown option $1" > /dev/stderr; exit 1 ;;
    esac
done

#############
### BUILD ###
#############

./build-docs.sh
./build-shell-completion.sh

./generate.sh
./script/check-uncommitted-files.sh
./generate.sh --build-version "$build_version" --codesign-identity "$codesign_identity" --generate-git-hash

swift_build_cli=(build -c release --arch arm64 --arch x86_64 --product looper)
swift "${swift_build_cli[@]}" -Xswiftc -warnings-as-errors # CLI
cli_bin_path="$(swift "${swift_build_cli[@]}" --show-bin-path)"

rm -rf .release && mkdir .release

cd ./xcode
    xcode_configuration="Release"
    xcodebuild -version
    xcodebuild-pretty ../.release/xcodebuild.log clean build \
        -scheme Looper \
        -destination "generic/platform=macOS" \
        -configuration "$xcode_configuration" \
        -derivedDataPath .xcode-build
cd -

git checkout .

cp -r "xcode/.xcode-build/Build/Products/$xcode_configuration/Looper.app" .release
cp -r "$cli_bin_path/looper" .release

# Binary reproducibility: strip non-portable rpaths
# https://github.com/swiftlang/swift-package-manager/issues/10760
xcrun objdump --macho --rpaths --no-leading-headers --arch all .release/looper | grep -vE '^(@|/usr/lib/swift$)' | sort -u |
    while IFS= read -r rpath; do
        install_name_tool -delete_rpath "$rpath" .release/looper
    done

################
### SIGN CLI ###
################

codesign -s "$codesign_identity" .release/looper

################
### VALIDATE ###
################

./script/validate-release-binaries.sh

############
### PACK ###
############

mkdir -p ".release/Looper-v$build_version/manpage" && cp .man/*.1 ".release/Looper-v$build_version/manpage"
cp -r ./legal ".release/Looper-v$build_version/legal"
cp -r .shell-completion ".release/Looper-v$build_version/shell-completion"
cd .release
    mkdir -p "Looper-v$build_version/bin" && cp -r looper "Looper-v$build_version/bin"
    cp -r Looper.app "Looper-v$build_version"
    zip -r "Looper-v$build_version.zip" "Looper-v$build_version"
cd -
