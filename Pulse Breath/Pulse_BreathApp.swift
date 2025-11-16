
import SwiftUI

@main
struct PulseBreathApp: App {
    @StateObject var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            MainContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark) // Dark theme by default
        }
    }
}
