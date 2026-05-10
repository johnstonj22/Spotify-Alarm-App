import Foundation

struct SpotifyPlaylist: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let trackCount: Int
    let uri: String
}

struct SpotifyTrack: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let artistNames: [String]
    let uri: String

    var subtitle: String {
        artistNames.joined(separator: ", ")
    }
}

struct SpotifyPagedResponse<Item: Decodable>: Decodable {
    let items: [Item]
    let next: String?
}

struct SpotifyPlaylistResponseItem: Decodable {
    let id: String
    let name: String
    let uri: String
    let tracks: TrackSummary

    struct TrackSummary: Decodable {
        let total: Int
    }

    var playlist: SpotifyPlaylist {
        SpotifyPlaylist(id: id, name: name, trackCount: tracks.total, uri: uri)
    }
}

struct SpotifyPlaylistTrackItem: Decodable {
    let track: Track?

    struct Track: Decodable {
        let id: String?
        let name: String
        let uri: String
        let type: String
        let isLocal: Bool?
        let artists: [Artist]

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case uri
            case type
            case isLocal = "is_local"
            case artists
        }
    }

    struct Artist: Decodable {
        let name: String
    }

    var spotifyTrack: SpotifyTrack? {
        guard let track, track.type == "track", track.isLocal != true else {
            return nil
        }

        return SpotifyTrack(
            id: track.id ?? track.uri,
            name: track.name,
            artistNames: track.artists.map(\.name),
            uri: track.uri
        )
    }
}

struct SpotifyTokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let scope: String?
    let expiresIn: TimeInterval
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

struct StoredSpotifyToken: Codable {
    let accessToken: String
    let refreshToken: String
    let expirationDate: Date

    var shouldRefresh: Bool {
        Date().addingTimeInterval(60) >= expirationDate
    }
}

struct SpotifyErrorResponse: Decodable {
    let error: ErrorDetail?

    struct ErrorDetail: Decodable {
        let status: Int?
        let message: String?
    }
}

