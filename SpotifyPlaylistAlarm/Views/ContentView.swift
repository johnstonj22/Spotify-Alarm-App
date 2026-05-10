import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Spotify Playlist Alarm")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("V1 uses a local notification. Tap the notification to open the app and start a random Spotify track.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Spotify") {
                    if viewModel.authManager.isAuthenticated {
                        Button("Load Playlists") {
                            viewModel.loadPlaylistsButtonTapped()
                        }

                        Button("Sign Out", role: .destructive) {
                            viewModel.signOut()
                        }
                    } else {
                        Button("Connect Spotify") {
                            viewModel.connectSpotify()
                        }
                    }
                }

                Section("Playlist") {
                    if viewModel.playlists.isEmpty {
                        if let playlist = viewModel.activePlaylist {
                            Text("Saved playlist: \(playlist.name)")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No playlists loaded yet.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("Selected Playlist", selection: $viewModel.selectedPlaylistID) {
                            ForEach(viewModel.playlists) { playlist in
                                Text("\(playlist.name) (\(playlist.trackCount))")
                                    .tag(Optional(playlist.id))
                            }
                        }
                    }
                }

                Section("Alarm") {
                    DatePicker(
                        "Alarm Time",
                        selection: $viewModel.alarmDate,
                        displayedComponents: .hourAndMinute
                    )

                    Button("Schedule Alarm") {
                        viewModel.scheduleAlarm()
                    }
                    .disabled(viewModel.activePlaylist == nil)
                }

                Section("Test") {
                    Button("Play Random Song Now") {
                        viewModel.playRandomSongNow()
                    }
                    .disabled(viewModel.activePlaylist == nil)
                }

                Section("Status") {
                    HStack(alignment: .top, spacing: 8) {
                        if viewModel.isBusy {
                            ProgressView()
                        }

                        Text(viewModel.statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Playlist Alarm")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.authManager.isAuthenticated {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityLabel("Spotify connected")
                    } else {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Spotify not connected")
                    }
                }
            }
            .disabled(viewModel.isBusy)
        }
    }
}

#Preview {
    ContentView(viewModel: AppViewModel())
}
