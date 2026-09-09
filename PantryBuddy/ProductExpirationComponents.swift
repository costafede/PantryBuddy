import SwiftUI

struct PBExpirationPicker: View {

    @Binding
    var hasExpirationDate: Bool

    @Binding
    var expirationDate: Date

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            HStack(spacing: 12) {
                Image(
                    systemName: "calendar.badge.clock"
                )
                .font(
                    .system(
                        size: 20,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    PantryTheme.forest
                )
                .frame(
                    width: 42,
                    height: 42
                )
                .background(
                    PantryTheme.forest.opacity(0.10),
                    in: RoundedRectangle(
                        cornerRadius: 13,
                        style: .continuous
                    )
                )

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text("Data di scadenza")
                        .font(.subheadline.bold())
                        .foregroundStyle(
                            PantryTheme.ink
                        )

                    Text(
                        hasExpirationDate
                            ? "Avvisi attivi per questo prodotto"
                            : "Nessuna scadenza impostata"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                }

                Spacer(minLength: 8)

                Toggle(
                    "Imposta scadenza",
                    isOn: $hasExpirationDate
                )
                .labelsHidden()
                .tint(PantryTheme.forest)
            }

            if hasExpirationDate {
                Divider()

                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text("Scade il")
                            .font(.subheadline)
                            .foregroundStyle(
                                PantryTheme.ink
                            )

                        Spacer()

                        expirationDatePicker
                    }

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {
                        Text("Scade il")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        expirationDatePicker
                    }
                }

                Label(
                    "Avviso tre giorni prima e il giorno della scadenza",
                    systemImage: "bell.fill"
                )
                .font(.caption2)
                .foregroundStyle(
                    PantryTheme.forest
                )
            }
        }
        .padding(16)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                hasExpirationDate
                    ? PantryTheme.forest.opacity(0.18)
                    : PantryTheme.forest.opacity(0.08),
                lineWidth: 1
            )
        }
        .animation(
            .easeInOut(duration: 0.18),
            value: hasExpirationDate
        )
    }

    private var expirationDatePicker: some View {
        DatePicker(
            "Data di scadenza",
            selection: $expirationDate,
            displayedComponents: .date
        )
        .labelsHidden()
        .datePickerStyle(.compact)
        .tint(PantryTheme.forest)
    }
}

struct PBExpirationBadge: View {

    let expirationDate: Date

    private var status: ProductExpirationStatus {
        ProductExpirationService.status(
            for: expirationDate
        ) ?? .future(days: 0)
    }

    private var title: String {
        switch status {
        case .future:
            return "Scade il \(shortDate)"

        default:
            return status.title
        }
    }

    private var shortDate: String {
        expirationDate.formatted(
            .dateTime
                .day()
                .month(.abbreviated)
        )
    }

    var body: some View {
        Label(
            title,
            systemImage: status.systemImage
        )
        .font(.caption2.bold())
        .foregroundStyle(status.color)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .padding(.horizontal, 9)
        .frame(minHeight: 28)
        .background(
            status.color.opacity(0.11),
            in: Capsule()
        )
        .accessibilityLabel(
            "\(status.title). Data: \(ProductExpirationService.formattedDate(expirationDate))"
        )
    }
}
