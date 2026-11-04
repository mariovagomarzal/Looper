import AppBundle
import SwiftUI

@main
struct LooperApp: App {
    @StateObject var viewModel = TrayMenuModel.shared
    @StateObject var messageModel = MessageModel.shared
    @Environment(\.openWindow) var openWindow: OpenWindowAction

    init() {
        initAppBundle()
    }

    var body: some Scene {
        menuBar(viewModel: viewModel)
        getMessageWindow(messageModel: messageModel)
            // A message can already be there on launch
            .onChange(of: messageModel.message, initial: true) { _, message in
                if message != nil {
                    openWindow(id: messageWindowId)
                }
            }
    }
}
