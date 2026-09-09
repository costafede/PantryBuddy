import CryptoKit
import Foundation
import SwiftUI
import UserNotifications

enum ProductExpirationStatus {

    case expired(days: Int)
    case today
    case soon(days: Int)
    case future(days: Int)

    var title: String {
        switch self {
        case .expired(let days):
            return days == 1
                ? "Scaduto ieri"
                : "Scaduto da \(days) giorni"

        case .today:
            return "Scade oggi"

        case .soon(let days):
            return days == 1
                ? "Scade domani"
                : "Scade tra \(days) giorni"

        case .future:
            return "Scadenza programmata"
        }
    }

    var systemImage: String {
        switch self {
        case .expired:
            return "xmark.circle.fill"

        case .today:
            return "exclamationmark.circle.fill"

        case .soon:
            return "clock.fill"

        case .future:
            return "calendar"
        }
    }

    var color: Color {
        switch self {
        case .expired, .today:
            return .red

        case .soon:
            return PantryTheme.gold

        case .future:
            return PantryTheme.forest
        }
    }

    var isUrgent: Bool {
        switch self {
        case .expired, .today, .soon:
            return true

        case .future:
            return false
        }
    }
}

enum ProductExpirationNotificationResult {
    case scheduled
    case permissionDenied
    case noExpirationDate
    case noFutureNotifications
    case failed
}

@MainActor
enum ProductExpirationService {

    static let warningDays = 3

    private static let notificationHour = 9

    private static var notificationCenter:
        UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    static func status(
        for expirationDate: Date?,
        now: Date = Date()
    ) -> ProductExpirationStatus? {
        guard let expirationDate else {
            return nil
        }

        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: now)
        let expirationDay = calendar.startOfDay(
            for: expirationDate
        )

        let days = calendar.dateComponents(
            [.day],
            from: today,
            to: expirationDay
        ).day ?? 0

        if days < 0 {
            return .expired(days: abs(days))
        }

        if days == 0 {
            return .today
        }

        if days <= warningDays {
            return .soon(days: days)
        }

        return .future(days: days)
    }

    static func formattedDate(
        _ date: Date
    ) -> String {
        date.formatted(
            .dateTime
                .day()
                .month(.wide)
                .year()
        )
    }

    static func scheduleNotifications(
        for product: Product
    ) async -> ProductExpirationNotificationResult {
        let barcode = product.barcode
        let productName = product.name
        let quantity = product.inventoryQuantity
        let expirationDate = product.expirationDate

        cancelNotifications(
            forBarcode: barcode
        )

        guard quantity > 0,
              let expirationDate else {
            return .noExpirationDate
        }

        guard await requestAuthorizationIfNeeded() else {
            return .permissionDenied
        }

        let calendar = Calendar.autoupdatingCurrent
        let expirationDay = calendar.startOfDay(
            for: expirationDate
        )

        var scheduledCount = 0

        if let warningDay = calendar.date(
            byAdding: .day,
            value: -warningDays,
            to: expirationDay
        ),
           let warningDate = notificationDate(
               on: warningDay,
               calendar: calendar
           ),
           warningDate > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Prodotto in scadenza"
            content.body =
                "\(productName) scade il \(formattedDate(expirationDay))."
            content.sound = .default
            content.userInfo = [
                "productBarcode": barcode
            ]

            do {
                try await addNotification(
                    identifier:
                        notificationIdentifier(
                            forBarcode: barcode,
                            kind: "warning"
                        ),
                    date: warningDate,
                    content: content,
                    calendar: calendar
                )

                scheduledCount += 1
            } catch {
                print(
                    "Errore notifica preavviso scadenza:",
                    error
                )
            }
        }

        if let dueDate = notificationDate(
            on: expirationDay,
            calendar: calendar
        ),
           dueDate > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Scadenza di oggi"
            content.body =
                "Oggi scade \(productName). Controllalo prima di usarlo."
            content.sound = .default
            content.userInfo = [
                "productBarcode": barcode
            ]

            do {
                try await addNotification(
                    identifier:
                        notificationIdentifier(
                            forBarcode: barcode,
                            kind: "due"
                        ),
                    date: dueDate,
                    content: content,
                    calendar: calendar
                )

                scheduledCount += 1
            } catch {
                print(
                    "Errore notifica giorno scadenza:",
                    error
                )
            }
        }

        return scheduledCount > 0
            ? .scheduled
            : .noFutureNotifications
    }

    static func cancelNotifications(
        for product: Product
    ) {
        cancelNotifications(
            forBarcode: product.barcode
        )
    }

    static func cancelNotifications(
        forBarcode barcode: String
    ) {
        let identifiers = notificationIdentifiers(
            forBarcode: barcode
        )

        notificationCenter
            .removePendingNotificationRequests(
                withIdentifiers: identifiers
            )

        notificationCenter
            .removeDeliveredNotifications(
                withIdentifiers: identifiers
            )
    }

    static func authorizationStatus() async
        -> UNAuthorizationStatus {
        let settings = await notificationCenter
            .notificationSettings()

        return settings.authorizationStatus
    }

    private static func requestAuthorizationIfNeeded()
        async -> Bool {
        let settings = await notificationCenter
            .notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true

        case .notDetermined:
            do {
                return try await notificationCenter
                    .requestAuthorization(
                        options: [
                            .alert,
                            .sound,
                            .badge
                        ]
                    )
            } catch {
                print(
                    "Errore richiesta permesso notifiche:",
                    error
                )

                return false
            }

        case .denied:
            return false

        @unknown default:
            return false
        }
    }

    private static func addNotification(
        identifier: String,
        date: Date,
        content: UNNotificationContent,
        calendar: Calendar
    ) async throws {
        let components = calendar.dateComponents(
            [
                .year,
                .month,
                .day,
                .hour,
                .minute
            ],
            from: date
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
    }

    private static func notificationDate(
        on day: Date,
        calendar: Calendar
    ) -> Date? {
        calendar.date(
            bySettingHour: notificationHour,
            minute: 0,
            second: 0,
            of: day
        )
    }

    private static func notificationIdentifiers(
        forBarcode barcode: String
    ) -> [String] {
        [
            notificationIdentifier(
                forBarcode: barcode,
                kind: "warning"
            ),
            notificationIdentifier(
                forBarcode: barcode,
                kind: "due"
            )
        ]
    }

    private static func notificationIdentifier(
        forBarcode barcode: String,
        kind: String
    ) -> String {
        let digest = SHA256.hash(
            data: Data(barcode.utf8)
        )

        let barcodeKey = digest.map {
            String(format: "%02x", $0)
        }.joined()

        return "pantrybuddy-expiration-\(kind)-\(barcodeKey)"
    }
}
