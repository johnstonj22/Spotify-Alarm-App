import Foundation

enum SpotifyConfig {
    // Replace this value with the Client ID from your Spotify Developer Dashboard.
    // Do not put a Client Secret in this iOS app. This project uses PKCE instead.
    static let clientID = "YOUR_SPOTIFY_CLIENT_ID_HERE"

    // This must exactly match the redirect URI in your Spotify Developer Dashboard.
    // The URL scheme is also declared in Info.plist.
    static let redirectURI = "spotify-playlist-alarm://callback"

    static let scopes = [
        "playlist-read-private",
        "playlist-read-collaborative",
        "user-modify-playback-state"
    ]

    static var isConfigured: Bool {
        !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        clientID != "YOUR_SPOTIFY_CLIENT_ID_HERE"
    }
}

