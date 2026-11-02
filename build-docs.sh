#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./script/install-dep.sh --bundler

rm -rf .man && mkdir .man

cp-docs() {
    cp -r ./docs/*.adoc "$1"
    cp -r ./docs/util "$1"
}

build-man() {
    cp-docs .man
    cd .man
        bundler exec asciidoctor -b manpage looper*.adoc

        # Comment by AI:
        #   gman (the g Dai client) renders bare .~ and /~ as ligatures (~ becomes ˜).
        #   We use groff's \[ti] escape (which produces a literal tilde) instead.
        #   Note: escaping .~ in asciidoc via pass:[] doesn't work because asciidoctor
        #   converts \\ to \(rs) before groff sees the input.
        sed -E -i '' 's|\.~|\.\\[ti]|g; s|/~|/\\[ti]|g' looper-test.1

        rm -rf -- *.adoc
    cd - > /dev/null
}

build-man
