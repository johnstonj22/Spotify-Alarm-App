import Foundation

enum SpotifyAPIError: LocalizedError {
    case invalidURL
    case unexpectedStatus(Int, String?)
    case noPlayableTracks

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Could not build a Spotify API URL."
        case .unexpectedStatus(let status, let message):
            if let message, !message.isEmpty {
                return "Spotify API error \(status): \(message)"
            }
            if status == 403 {
                return "Spotify refused playback. Make sure the account has Premium and an active Spotify device."
            }
            if status == 404 {
                return "Spotify could not find an active playback device. Open Spotify on a device and try again."
            }
            return "Spotify API request failed with HTTP \(status)."
        case .noPlayableTracks:
            return "This playlist does not contain playable Spotify tracks."
        }
    }
}

final class SpotifyAPIClient {
    private let authManager: SpotifyAuthManager
    private let urlSession: URLSession
    private let decoder = JSONDecoder()

    init(authManager: SpotifyAuthManager, urlSession: URLSession = .shared) {
        self.authManager = authManager
        self.urlSession = urlSession
    }

    func fetchPlaylists() async throws -> [SpotifyPlaylist] {
        var playlists: [SpotifyPlaylist] = []
        var nextURL: URL? = URL(string: "https://api.spotify.com/v1/me/playlists?limit=50")

        while let url = nextURL {
            let response: SpotifyPagedResponse<SpotifyPlaylistResponseItem> = try await performGET(url: url)
            playlists.append(contentsOf: response.items.map(\.playlist))
            nextURL = response.next.flatMap(URL.init(string:))
        }

        return playlists
    }

    func fetchTracks(for playlist: SpotifyPlaylist) async throws -> [SpotifyTrack] {
        var tracks: [SpotifyTrack] = []
        var components = URLComponents(string: "https://api.spotify.com/v1/playlists/\(playlist.id)/tracks")
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "fields", value: "items(track(id,name,uri,type,is_local,artists(name))),next")
        ]

        guard var nextURL = components?.url else {
            throw SpotifyAPIError.invalidURL
        }

        while true {
            let response: SpotifyPagedResponse<SpotifyPlaylistTrackItem> = try await performGET(url: nextURL)
            tracks.append(contentsOf: response.items.compactMap(\.spotifyTrack))

            guard let next = response.next, let url = URL(string: next) else {
                break
            }
            nextURL = url
        }

        if tracks.isEmpty {
            throw SpotifyAPIError.noPlayableTracks
        }

        return tracks
    }

    func play(track: SpotifyTrack) async throws {
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/play") else {
            throw SpotifyAPIError.invalidURL
        }

        var request = try await authorizedRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "uris": [track.uri],
            "position_ms": 0
        ])

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)
    }

    private func performGET<Response: Decodable>(url: URL) async throws -> Response {
        let request = try await authorizedRequest(url: url)
        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(Response.self, from: data)
    }

    private func authorizedRequest(url: URL) async throws -> URLRequest {
        let token = try await authManager.validAccessToken()
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyAPIError.unexpectedStatus(-1, nil)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = try? decoder.decode(SpotifyErrorResponse.self, from: data).error?.message
            throw SpotifyAPIError.unexpectedStatus(httpResponse.statusCode, message)
        }
    }
}

