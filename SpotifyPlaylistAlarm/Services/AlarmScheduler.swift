import Foundation
import UserNotifications

enum AlarmSchedulerError: LocalizedError {
    case notificationsDenied

    var errorDescription: String? {
        switch self {
        case .notificationsDenied:
            return "Notification permission was denied. Enable notifications in Settings to use alarms."
        }
    }
}

final class AlarmScheduler {
    static let alarmIdentifier = "spotify-playlist-alarm.next"

    func scheduleAlarm(at date: Date, playlistName: String) async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])

        guard granted else {
            throw AlarmSchedulerError.notificationsDenied
        }

        center.removePendingNotificationRequests(withIdentifiers: [Self.alarmIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Spotify Playlist Alarm"
        content.body = "Tap to play a random song from \(playlistName)."
        content.sound = .default
        content.userInfo = ["alarmAction": "playRandomSong"]

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: Self.alarmIdentifier, content: content, trigger: trigger)

        try await center.add(request)
    }
}

