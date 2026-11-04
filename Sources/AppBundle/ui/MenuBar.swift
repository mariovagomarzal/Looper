import Common
import Foundation
import SwiftUI

@MainActor
public func menuBar(viewModel: TrayMenuModel) -> some Scene { // todo should it be converted to "SwiftUI struct"?
    MenuBarExtra {
        let shortIdentification = "\(looperAppName) v\(looperAppVersion) \(gitShortHash)"
        let identification      = "\(looperAppName) v\(looperAppVersion) \(gitHash)"
        Text(shortIdentification)
        Button("Copy to clipboard") { identification.copyToClipboard() }
            .keyboardShortcut("C", modifiers: .command)
        Divider()

        if viewModel.axPermissionStatus == .granted {
            if let token: RunSessionGuard = .isServerEnabled, viewModel.lastReloadConfigContainedWarnings {
                Button {
                    Task.startUnstructured {
                        try await runLightSession(.menuBarButton, token) {
                            let args: ReloadConfigCmdArgs = ReloadConfigCmdArgs(rawArgs: []).with(\.warningsAsErrors, true)
                            _ = await reloadConfig_nonCancellable(args: args)
                        }
                    }
                } label: {
                    Label("Config contains warnings...", systemImage: "exclamationmark.triangle.fill")
                }
                Divider()
            }
            if let token: RunSessionGuard = .isServerEnabled {
                Text("Workspaces:")
                ForEach(viewModel.workspaces, id: \.name) { workspace in
                    Button {
                        Task.startUnstructured {
                            try await runLightSession(.menuBarButton, token) { _ = Workspace.get(byName: workspace.name).focusWorkspace() }
                        }
                    } label: {
                        Toggle(isOn: .constant(workspace.isFocused)) {
                            Text(workspace.name + workspace.suffix).font(.system(.body, design: .monospaced))
                        }
                    }
                }
                Divider()
            }
            Button(viewModel.isEnabled ? "Disable" : "Enable") {
                Task.startUnstructured {
                    try await runLightSession(.menuBarButton, .forceRun) {
                        _ = await EnableCommand(args: EnableCmdArgs(rawArgs: [], targetState: .toggle))
                            .run(.defaultEnv, .emptyStdin)
                    }
                }
            }.keyboardShortcut("E", modifiers: .command)
            openConfigButton()
            reloadConfigButton(warningsAsErrors: false)
        } else if isAppTranslocated {
            Button("Move \(looperAppName) to Applications to use it...") { showTranslocationMessage() }
        } else {
            Button("\(looperAppName) requires accessibility permission to move windows") {
                viewModel.axPermissionStatus = .waitingWithPrompt
            }
        }
        quitButton()
    } label: {
        switch (viewModel.axPermissionStatus, viewModel.isEnabled) {
            case (.granted, true):
                MenuBarLabel().environmentObject(viewModel)
            case (.granted, false):
                PausedMenuBarLabel()
            case (_, _):
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
        }
    }
}

@MainActor
func quitButton() -> some View {
    Button("Quit \(looperAppName)") {
        Task.startUnstructured {
            terminationHandler?.beforeTermination()
            terminateApp()
        }
    }.keyboardShortcut("Q", modifiers: .command)
}

@MainActor
func openConfigButton() -> some View {
    let editor = getTextEditorToOpenConfig()
    return Button("Open config in '\(editor.lastPathComponent)'") {
        let fallbackConfig: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: configDotfileName)
        switch findCustomConfigUrl() {
            case .file(let url):
                url.open(with: editor)
            case .noCustomConfigExists:
                _ = try? FileManager.default.copyItem(atPath: defaultConfigUrl.path, toPath: fallbackConfig.path)
                fallbackConfig.open(with: editor)
            case .ambiguousConfigError:
                fallbackConfig.open(with: editor)
        }
    }.keyboardShortcut(",", modifiers: .command)
}

@MainActor @ViewBuilder
func reloadConfigButton(warningsAsErrors: Bool) -> some View {
    if let token: RunSessionGuard = .isServerEnabled {
        Button("Reload config") {
            Task.startUnstructured {
                try await runLightSession(.menuBarButton, token) {
                    let args: ReloadConfigCmdArgs = ReloadConfigCmdArgs(rawArgs: []).with(\.warningsAsErrors, warningsAsErrors)
                    _ = await reloadConfig_nonCancellable(args: args)
                }
            }
        }.keyboardShortcut("R", modifiers: .command)
    }
}

func getTextEditorToOpenConfig() -> URL {
    NSWorkspace.shared.urlForApplication(toOpen: findCustomConfigUrl().urlOrNil ?? defaultConfigUrl)?
        .takeIf { $0.lastPathComponent != "Xcode.app" } // Blacklist Xcode. It is too heavy to open plain text files
        ?? URL(filePath: "/System/Applications/TextEdit.app")
}

/// Looper's glyph with a pause sign, while Looper is disabled
@MainActor
private struct PausedMenuBarLabel: View {
    @Environment(\.colorScheme) var menuColorScheme: ColorScheme

    var body: some View {
        menuBarImage(label: "\(looperAppName) is disabled", colorScheme: menuColorScheme) {
            LooperGlyph(isPaused: true).frame(width: menuBarGlyphSize, height: menuBarGlyphSize)
        }
    }
}
