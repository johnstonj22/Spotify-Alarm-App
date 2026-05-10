import CryptoKit
import Foundation

enum SpotifyAuthError: LocalizedError {
    case missingClientID
    case invalidAuthorizationURL
    case missingAuthorizationCode
    case stateMismatch
    case missingCodeVerifier
    case tokenRefreshUnavailable
    case spotifyError(String)
    case unexpectedStatus(Int)

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Add your Spotify Client ID in SpotifyConfig.swift first."
        case .invalidAuthorizationURL:
            return "Could not build the Spotify authorization URL."
        case .missingAuthorizationCode:
            return "Spotify did not return an authorization code."
        case .stateMismatch:
            return "Spotify login state did not match. Please try connecting again."
        case .missingCodeVerifier:
            return "The PKCE code verifier was missing. Please start Spotify login again."
        case .tokenRefreshUnavailable:
            return "Spotify did not return a refresh token. Please connect again."
        case .spotifyError(let message):
            return message
        case .unexpectedStatus(let status):
            return "Spotify authorization failed with HTTP \(status)."
        }
    }
}

@MainActor
final class SpotifyAuthManager: ObservableObject {
    @Published private(set) var isAuthenticated = false

    private let tokenStore = KeychainTokenStore()
    private let urlSession: URLSession
    private let verifierKey = "spotify.pkce.codeVerifier"
    private let stateKey = "spotify.pkce.state"

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.isAuthenticated = (try? tokenStore.loadToken()) != nil
    }

    func makeAuthorizationURL() throws -> URL {
        guard SpotifyConfig.isConfigured else {
            throw SpotifyAuthError.missingClientID
        }

        let verifier = Self.randomURLSafeString(length: 64)
        let state = Self.randomURLSafeString(length: 32)
        UserDefaults.standard.set(verifier, forKey: verifierKey)
        UserDefaults.standard.set(state, forKey: stateKey)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: SpotifyConfig.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: Self.codeChallenge(for: verifier)),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: SpotifyConfig.scopes.joined(separator: " "))
        ]

        guard let url = components?.url else {
            throw SpotifyAuthError.invalidAuthorizationURL
        }

        return url
    }

    func handleRedirectURL(_ url: URL) async throws {
        guard url.scheme == "spotify-playlist-alarm" else {
            return
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        if let spotifyError = queryItems.first(where: { $0.name == "error" })?.value {
            throw SpotifyAuthError.spotifyError("Spotify login failed: \(spotifyError)")
        }

        guard let returnedState = queryItems.first(where: { $0.name == "state" })?.value,
              returnedState == UserDefaults.standard.string(forKey: stateKey) else {
            throw SpotifyAuthError.stateMismatch
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw SpotifyAuthError.missingAuthorizationCode
        }

        guard let verifier = UserDefaults.standard.string(forKey: verifierKey) else {
            throw SpotifyAuthError.missingCodeVerifier
        }

        let response = try await requestToken(parameters: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": SpotifyConfig.redirectURI,
            "client_id": SpotifyConfig.clientID,
            "code_verifier": verifier
        ])

        guard let refreshToken = response.refreshToken else {
            throw SpotifyAuthError.tokenRefreshUnavailable
        }

        try tokenStore.saveToken(StoredSpotifyToken(
            accessToken: response.accessToken,
            refreshToken: refreshToken,
            expirationDate: Date().addingTimeInterval(response.expiresIn)
        ))

        UserDefaults.standard.removeObject(forKey: verifierKey)
        UserDefaults.standard.removeObject(forKey: stateKey)
        isAuthenticated = true
    }

    func validAccessToken() async throws -> String {
        guard let storedToken = try tokenStore.loadToken() else {
            throw SpotifyAuthError.tokenRefreshUnavailable
        }

        if !storedToken.shouldRefresh {
            return storedToken.accessToken
        }

        let response = try await requestToken(parameters: [
            "grant_type": "refresh_token",
            "refresh_token": storedToken.refreshToken,
            "client_id": SpotifyConfig.clientID
        ])

        let refreshedToken = StoredSpotifyToken(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? storedToken.refreshToken,
            expirationDate: Date().addingTimeInterval(response.expiresIn)
        )

        try tokenStore.saveToken(refreshedToken)
        isAuthenticated = true
        return refreshedToken.accessToken
    }

    func signOut() {
        try? tokenStore.clearToken()
        isAuthenticated = false
    }

    private func requestToken(parameters: [String: String]) async throws -> SpotifyTokenResponse {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            throw SpotifyAuthError.invalidAuthorizationURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncodedBody(parameters)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyAuthError.unexpectedStatus(-1)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SpotifyAuthError.unexpectedStatus(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
    }

    private static func formEncodedBody(_ parameters: [String: String]) -> Data {
        let body = parameters
            .map { key, value in
                "\(percentEncode(key))=\(percentEncode(value))"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }

    private static func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func randomURLSafeString(length: Int) -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

