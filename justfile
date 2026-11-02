debug_app := ".build/bundle/Looper-Debug.app"

# List the available recipes.
default:
    @just --list

# Regenerate the CLI help and build metadata sources from docs/commands.
generate:
    scripts/generate.sh

# Build all targets, including tests, in debug.
build:
    swift build --build-tests

# Run the unit tests.
test:
    swift test

# Assemble the debug app bundle and CLI in .build/bundle.
app:
    scripts/bundle.sh

# Build the debug app bundle and (re)launch it.
run: app
    -osascript -e 'quit app "Looper-Debug"'
    open {{debug_app}}

# Run the CLI from the debug build.
cli *args:
    swift run --quiet looper {{args}}

# Format Swift sources.
format:
    swiftformat .

# Check formatting, lint rules and unused code.
lint:
    swiftformat --lint .
    @if grep -E '( Task\.init| Task\s*\{| Task\()' -r Sources; then \
        echo "ERROR: don't use Task.init directly. Use Task.startUnstructured instead."; exit 1; \
    fi
    swiftlint lint --quiet
    # Periphery reads the index store of the native SwiftPM build system.
    periphery scan --quiet --strict --disable-redundant-public-analysis --no-superfluous-ignore-comments -- --build-system native

# Full verification: generated sources are up to date, strict build, tests and lint.
check: generate
    git diff --exit-code -- Sources/Common/cmdHelpGenerated.swift Sources/Cli/subcommandDescriptionsGenerated.swift
    swift build --build-tests -Xswiftc -warnings-as-errors
    swift test
    just lint

# Generate zsh, fish and bash completions in .build/completion.
completion:
    mkdir -p .build/completion
    complgen scripts/completion/grammar.bnf --zsh .build/completion/_looper
    complgen scripts/completion/grammar.bnf --fish .build/completion/looper.fish
    complgen scripts/completion/grammar.bnf --bash .build/completion/looper.bash

# Build a signed release zip in .build/dist.
release version:
    scripts/release.sh --version {{version}}

# Reset the Accessibility permission of the debug app.
reset-permission:
    tccutil reset Accessibility com.mariovagomarzal.looper.debug

# Remove build products.
clean:
    rm -rf .build
