import SwiftUI

@main
struct VoiceToTextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        _ = Self.launchLanguage
    }

    // Language applied in this process run — used to detect pending restart
    static let launchLanguage: String = {
        let saved = UserDefaults.standard.string(forKey: "uiLanguage") ?? "system"
        // Apply before any Bundle lookup so SwiftUI renders in the right language
        if saved != "system" {
            UserDefaults.standard.set([saved], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        return saved
    }()

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
