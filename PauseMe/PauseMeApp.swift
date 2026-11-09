import SwiftUI

@main
struct PauseMeApp: App {
    @StateObject private var session = PauseSession()

    var body: some Scene {
        WindowGroup {
            ContentView(session: session)
        }
    }
}
