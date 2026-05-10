import Foundation
import UIKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published var playlists: [SpotifyPlaylist] = []
    @Published var selectedPlaylistID: SpotifyPlaylist.ID? {
        didSet {
            saveSelectedPlaylistIfPossible()
        }
    }
    @Published private(set) var persistedPlaylist: SpotifyPlaylist?
    @Published var alarmDate = Date().addingTimeInterval(300)
    @Published var statusMessage = "Add your Spotify Client ID, then connect your account."
    @Published var isBusy = false

    let authManager: SpotifyAuthManager
    private let apiClient: SpotifyAPIClient
    private let alarmScheduler = AlarmScheduler()
    private let selectedPlaylistStorageKey = "selectedSpotifyPlaylist"

    var selectedPlaylist: SpotifyPlaylist? {
        playlists.first { $0.id == selectedPlaylistID }
    }

    var activePlaylist: SpotifyPlaylist? {
        selectedPlaylist ?? persistedPlaylist
    }

    var canUseSpotify: Bool {
        SpotifyConfig.isConfigured && authManager.isAuthenticated
    }

    init(authManager: SpotifyAuthManager = SpotifyAuthManager()) {
        self.authManager = authManager
        self.apiClient = SpotifyAPIClient(authManager: authManager)
        self.persistedPlaylist = Self.loadPersistedPlaylist(key: selectedPlaylistStorageKey)
        self.selectedPlaylistID = persistedPlaylist?.id

        if SpotifyConfig.isConfigured {
            statusMessage = authManager.isAuthenticated
                ? "Connected. Load your playlists to begin."
                : "Connect Spotify to begin."
        }
    }

    func connectSpotify() {
        runTask {
            let url = try authManager.makeAuthorizationURL()
            UIApplication.shared.open(url)
            statusMessage = "Finish Spotify login in the browser, then return to the app."
        }
    }

    func handleRedirectURL(_ url: URL) {
        runTask {
            try await authManager.handleRedirectURL(url)
            statusMessage = "Spotify connected. Loading playlists..."
            try await loadPlaylists()
        }
    }

    func signOut() {
        authManager.signOut()
        playlists = []
        selectedPlaylistID = nil
        persistedPlaylist = nil
        UserDefaults.standard.removeObject(forKey: selectedPlaylistStorageKey)
        statusMessage = "Signed out of Spotify."
    }

    func loadPlaylists() async throws {
        guard SpotifyConfig.isConfigured else {
            throw SpotifyAuthError.missingClientID
        }

        playlists = try await apiClient.fetchPlaylists()
        selectedPlaylistID = selectedPlaylistID ?? persistedPlaylist?.id ?? playlists.first?.id
        saveSelectedPlaylistIfPossible()

        if playlists.isEmpty {
            statusMessage = "No Spotify playlists were found for this account."
        } else {
            statusMessage = "Loaded \(playlists.count) playlists."
        }
    }

    func loadPlaylistsButtonTapped() {
        runTask {
            statusMessage = "Loading playlists..."
            try await loadPlaylists()
        }
    }

    func playRandomSongNow() {
        runTask {
            try await playRandomSongFromSelectedPlaylist()
        }
    }

    func scheduleAlarm() {
        runTask {
            guard let playlist = activePlaylist else {
                statusMessage = "Choose a playlist before scheduling an alarm."
                return
            }

            let fireDate = nextFireDate(from: alarmDate)
            try await alarmScheduler.scheduleAlarm(at: fireDate, playlistName: playlist.name)
            statusMessage = "Alarm scheduled for \(fireDate.formatted(date: .omitted, time: .shortened)). Tap the notification to start Spotify playback."
        }
    }

    func handleAlarmNotificationTap() {
        UserDefaults.standard.set(false, forKey: AppNotificationKeys.pendingAlarmNotificationTap)
        runTask {
            statusMessage = "Alarm opened. Trying Spotify playback..."
            try await playRandomSongFromSelectedPlaylist()
        }
    }

    func consumePendingAlarmNotificationTap() {
        guard UserDefaults.standard.bool(forKey: AppNotificationKeys.pendingAlarmNotificationTap) else {
            return
        }

        handleAlarmNotificationTap()
    }

    private func playRandomSongFromSelectedPlaylist() async throws {
        guard let playlist = activePlaylist else {
            statusMessage = "Choose a playlist first."
            return
        }

        statusMessage = "Picking a random track from \(playlist.name)..."
        let tracks = try await apiClient.fetchTracks(for: playlist)

        guard let randomTrack = tracks.randomElement() else {
            throw SpotifyAPIError.noPlayableTracks
        }

        statusMessage = "Trying to play \(randomTrack.name)..."
        try await apiClient.play(track: randomTrack)
        statusMessage = "Playing \(randomTrack.name) by \(randomTrack.subtitle)."
    }

    private func nextFireDate(from selectedDate: Date) -> Date {
        var components = Calendar.current.dateComponents([.hour, .minute], from: selectedDate)
        components.second = 0

        let now = Date()
        let today = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.year = today.year
        components.month = today.month
        components.day = today.day

        let candidate = Calendar.current.date(from: components) ?? selectedDate
        if candidate > now {
            return candidate
        }

        return Calendar.current.date(byAdding: .day, value: 1, to: candidate) ?? candidate
    }

    private func runTask(_ operation: @escaping () async throws -> Void) {
        isBusy = true

        Task {
            do {
                try await operation()
            } catch {
                statusMessage = error.localizedDescription
            }

            isBusy = false
        }
    }

    private func saveSelectedPlaylistIfPossible() {
        guard let selectedPlaylist else {
            return
        }

        persistedPlaylist = selectedPlaylist

        if let data = try? JSONEncoder().encode(selectedPlaylist) {
            UserDefaults.standard.set(data, forKey: selectedPlaylistStorageKey)
        }
    }

    private static func loadPersistedPlaylist(key: String) -> SpotifyPlaylist? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(SpotifyPlaylist.self, from: data)
    }
}
