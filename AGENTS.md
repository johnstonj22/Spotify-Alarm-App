# Project Context

This is a personal SwiftUI iOS app called Spotify Playlist Alarm.

## Goal

The app connects to a user's Spotify account, lets them choose a playlist, schedule a local notification alarm, and attempts to play a random song from that playlist when the user taps the notification.

## Important Constraints

- Do not claim the app can automatically start Spotify playback from the locked background.
- V1 uses local notifications. The user taps the notification, then the app attempts Spotify playback.
- Spotify Web API playback requires Spotify Premium and an active Spotify device.
- Keep the app beginner-readable and avoid unnecessary third-party dependencies.
- Use Swift and SwiftUI.
- Remote Mac testing happens through MacinCloud and Xcode.

## Architecture

- `SpotifyConfig.swift`: Spotify Client ID, redirect URI, scopes.
- `SpotifyAuthManager.swift`: OAuth Authorization Code with PKCE.
- `SpotifyAPIClient.swift`: Spotify Web API calls.
- `AlarmScheduler.swift`: local notification scheduling.
- `AppViewModel.swift`: app state and user actions.
- `ContentView.swift`: main SwiftUI interface.

## Development Style

- Prefer small, understandable changes.
- Work in milestones.
- After each milestone, explain what changed and what should be tested.
- Avoid introducing third-party dependencies unless clearly justified.
- Keep comments focused on setup, limitations, and non-obvious behavior.

## Testing Notes

- Simulator can test UI, OAuth redirect, playlist loading, and local notifications.
- Real Spotify playback requires Spotify Premium and an active Spotify device.
- Real iPhone testing should use TestFlight because the iPhone is not physically connected to the remote Mac.