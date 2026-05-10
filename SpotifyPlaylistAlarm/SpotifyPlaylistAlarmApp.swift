import SwiftUI

@main
struct SpotifyPlaylistAlarmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .onAppear {
                    viewModel.consumePendingAlarmNotificationTap()
                }
                .onOpenURL { url in
                    viewModel.handleRedirectURL(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .alarmNotificationTapped)) { _ in
                    viewModel.handleAlarmNotificationTap()
                }
        }
    }
}
