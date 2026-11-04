import AppKit
import Common
import SwiftUI

@MainActor
public func getMessageWindow(messageModel: MessageModel) -> some Scene {
    // Using SwiftUI.Window because another class in Looper is already called Window
    SwiftUI.Window(looperAppName, id: messageWindowId) {
        MessageView(model: messageModel)
            .containerBackground(.regularMaterial, for: .window)
            .onAppear {
                // Set activation policy; otherwise, Looper windows won't be able to receive focus and accept keyboard input
                NSApp.setActivationPolicy(.accessory)
                NSApp.activate()
                NSApplication.shared.windows.forEach {
                    if $0.identifier?.rawValue == messageWindowId {
                        $0.level = .floating
                        $0.styleMask.remove(.miniaturizable) // We don't unminimize the window on config error
                        // Laid out like an alert: its own buttons close it
                        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                            $0.standardWindowButton(button)?.isHidden = true
                        }
                    }
                }
            }
    }
    .windowStyle(.hiddenTitleBar)
    .windowBackgroundDragBehavior(.enabled)
    .windowResizability(.contentSize)
}

public let messageWindowId = "\(looperAppName).messageView"

struct MessageView: View {
    @StateObject private var model: MessageModel
    @Environment(\.dismiss) private var dismiss: DismissAction

    init(model: MessageModel) {
        self._model = .init(wrappedValue: model)
    }

    var body: some View {
        Group {
            switch model.message?.content {
                case .installNotice(let title, let body, let canMove): InstallNoticeView(title: title, message: body, canMove: canMove, close: close)
                case .configDiagnostics(let diagnostics): ConfigDiagnosticsView(diagnostics: diagnostics, close: close)
                case nil: EmptyView()
            }
        }
        .controlSize(.large)
        .onExitCommand(perform: close)
        .onChange(of: model.message) { _, message in
            if message == nil {
                self.dismiss()
            }
        }
        .onDisappear {
            // If user closes the screen with the macOS native close (x) button and then the error is still the same, this window will not appear again
            model.message = nil
        }
    }

    private func close() { model.message = nil }
}

/// A short notice, laid out like a macOS alert
private struct InstallNoticeView: View {
    let title: String
    let message: String
    let canMove: Bool
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.title3.weight(.semibold))
                    Text(message)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            HStack {
                Spacer()
                Button("Close", action: close).keyboardShortcut(.cancelAction)
                if canMove {
                    quitButton()
                    Button("Move to Applications") { moveToApplicationsAndRelaunch() }.keyboardShortcut(.defaultAction)
                } else {
                    quitButton().keyboardShortcut(.defaultAction)
                }
            }
        }
        // The title bar leaves the space on top
        .padding([.horizontal, .bottom], 24)
        .frame(width: 480)
    }
}

/// The problems of a config file, one per row
private struct ConfigDiagnosticsView: View {
    let diagnostics: ConfigDiagnostics
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(diagnostics.summary).font(.title3.weight(.semibold))
                Text(diagnostics.path)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(diagnostics.items.enumerated()), id: \.offset) { index, item in
                        if index > 0 { Divider() }
                        ConfigDiagnosticRow(item: item)
                    }
                }
            }
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            HStack {
                Button("Copy") { diagnostics.plainText.copyToClipboard() }
                Spacer()
                openConfigButton()
                reloadConfigButton(warningsAsErrors: diagnostics.containsWarnings)
                Button("Close", action: close).keyboardShortcut(.defaultAction)
            }
        }
        // The title bar leaves the space on top
        .padding([.horizontal, .bottom], 24)
        .frame(minWidth: 560, idealWidth: 680, maxWidth: 1000, minHeight: 280, idealHeight: 420, maxHeight: 800)
    }
}

private struct ConfigDiagnosticRow: View {
    let item: ConfigDiagnostics.Item

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            switch item.severity {
                case .error: Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                case .warning: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            }
            VStack(alignment: .leading, spacing: 3) {
                if !item.key.isEmpty {
                    Text(item.key).font(.callout.monospaced().weight(.medium))
                }
                Text(item.text)
                    .foregroundStyle(item.key.isEmpty ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .textSelection(.enabled)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

public final class MessageModel: ObservableObject {
    @MainActor public static let shared = MessageModel()
    @Published public var message: Message? = nil

    private init() {}
}

public struct Message: Hashable {
    enum Content: Hashable {
        case installNotice(title: String, body: String, canMove: Bool)
        case configDiagnostics(ConfigDiagnostics)
    }

    let content: Content
}

struct ConfigDiagnostics: Hashable {
    struct Item: Hashable {
        let severity: ConfigParseDiagnostic.Severity
        /// Where in the config the problem is. Empty for problems of the whole file
        let key: String
        let text: String
    }

    let path: String
    let items: [Item]

    init(path: String, errors: [ConfigParseDiagnostic], warnings: [ConfigParseDiagnostic]) {
        self.path = path
        let item = { (severity: ConfigParseDiagnostic.Severity, diagnostic: ConfigParseDiagnostic) in
            Item(severity: severity, key: diagnostic.backtrace.description, text: diagnostic.message)
        }
        self.items = errors.map { item(.error, $0) } + warnings.map { item(.warning, $0) }
    }

    var containsWarnings: Bool { items.contains { $0.severity == .warning } }

    /// Like '2 errors, 1 warning'
    var summary: String {
        let count = { (severity: ConfigParseDiagnostic.Severity, name: String) -> String? in
            let number = items.count { $0.severity == severity }
            return number == 0 ? nil : "\(number) \(name)\(number == 1 ? "" : "s")"
        }
        return [count(.error, "error"), count(.warning, "warning")].compactMap(\.self).joined(separator: ", ")
    }

    var plainText: String {
        let lines = items.map { item in
            let key = item.key.isEmpty ? "" : "\(item.key): "
            return "[\(item.severity.rawValue)] \(key)\(item.text)"
        }
        return ([path] + lines).joined(separator: "\n\n")
    }
}
