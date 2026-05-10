# Spotify Playlist Alarm

A small SwiftUI iOS learning project that lets a user connect Spotify, choose a playlist, schedule a local notification alarm, and play a random track after tapping the notification.

This first version is intentionally realistic: it does not claim to start Spotify automatically from the locked background. iOS delivers a local notification at the alarm time. When the user taps that notification, the app opens and attempts Spotify playback.

## What Works In The App Code

- SwiftUI app shell with a simple single-screen UI.
- Spotify OAuth Authorization Code with PKCE.
- Keychain storage for Spotify access and refresh tokens.
- Playlist loading through Spotify Web API.
- Playlist track loading and random track selection.
- Playback attempt through Spotify Web API `/me/player/play`.
- Local notification permission and one-time alarm scheduling.
- Notification-tap handling that triggers the random playback flow.

## What Requires Your Setup

Before running on the remote Mac:

1. Open `SpotifyPlaylistAlarm.xcodeproj` in Xcode.
2. Select the app target and set your Apple signing team.
3. Change the bundle identifier from `com.example.SpotifyPlaylistAlarm` if needed.
4. Create an app in the Spotify Developer Dashboard.
5. Add this redirect URI in the Spotify app settings:

   ```text
   spotify-playlist-alarm://callback
   ```

6. Open `SpotifyPlaylistAlarm/Services/SpotifyConfig.swift`.
7. Replace `YOUR_SPOTIFY_CLIENT_ID_HERE` with your Spotify Client ID.

The URL scheme is already declared in `SpotifyPlaylistAlarm/Info.plist`.

## Spotify Playback Limitations

The first version uses Spotify Web API only. The playback endpoint requires:

- A Spotify Premium account.
- The `user-modify-playback-state` scope.
- An active Spotify playback device, or a device ID supplied to the endpoint.
- Network access and a valid access token.

If playback fails, the app shows a clear status message. The local notification sound is the fallback alarm behavior in V1.

## Testing Checklist

- Build and run on MacinCloud using Xcode.
- Tap "Connect Spotify" and complete OAuth.
- Tap "Load Playlists".
- Select a playlist.
- Tap "Play Random Song Now" while Spotify is open on a device.
- Schedule an alarm a minute in the future.
- Tap the notification when it fires and confirm the app attempts playback.

## Future Experiments

- Spotify iOS SDK / App Remote for richer Spotify-app integration.
- Device picker using `/me/player/devices`.
- Repeating alarms and snooze.
- Multiple saved alarms.
- AlarmKit investigation for newer iOS versions.
- Better fallback audio inside app foreground sessions.

