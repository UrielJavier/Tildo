import SwiftUI

@main
struct VoiceToTextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(appDelegate: appDelegate)
        } label: {
            let state = appDelegate.appState
            if state.isDownloading {
                Image(systemName: "arrow.down.circle")
                Text("\(Int(state.downloadProgress * 100))%")
            } else {
                MenuBarEqualizer(status: state.status, level: state.audioLevel)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
