import SwiftUI
import UIKit

struct PBProductImage: View {

    let imageURL: String?

    var localImageData: Data? = nil
    var size: CGFloat = 150

    var body: some View {
        Group {
            /*
             La foto scattata dall’utente ha la precedenza
             sull’immagine ottenuta dal servizio online.
             */
            if let localImageData,
               let localImage = UIImage(
                   data: localImageData
               ) {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFill()

            } else if let imageURL,
                      let url = URL(
                          string: imageURL
                      ) {
                PBCachedRemoteImage(
                    url: url
                ) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(14)
                } failure: {
                    placeholder
                }

            } else {
                placeholder
            }
        }
        .frame(
            width: size,
            height: size
        )
        .clipped()
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 28
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 28
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 28
            )
            .stroke(
                PantryTheme.forest.opacity(0.10),
                lineWidth: 1
            )
        }
    }

    private var placeholder: some View {
        Image(systemName: "shippingbox.fill")
            .font(.system(size: 48))
            .foregroundStyle(
                PantryTheme.forest.opacity(0.55)
            )
    }
}

struct PBQuantityControl: View {

    let title: String

    @Binding
    var quantity: Int

    var minimum = 0
    var maximum = 99

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                quantityLabel

                Spacer()

                quantityButtons
            }

            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                quantityLabel

                quantityButtons
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )
            }
        }
        .padding(16)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 20
            )
        )
    }

    private var quantityLabel: some View {
        VStack(
            alignment: .leading,
            spacing: 3
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(quantity)")
                .font(.title2.bold())
                .foregroundStyle(PantryTheme.ink)
        }
    }

    private var quantityButtons: some View {
        HStack(spacing: 14) {
            controlButton("minus") {
                if quantity > minimum {
                    quantity -= 1
                }
            }
            .disabled(quantity <= minimum)

            Text("\(quantity)")
                .font(.headline.monospacedDigit())
                .frame(minWidth: 28)

            controlButton("plus") {
                if quantity < maximum {
                    quantity += 1
                }
            }
            .disabled(quantity >= maximum)
        }
    }

    private func controlButton(
        _ icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(
                    .system(
                        size: 15,
                        weight: .bold
                    )
                )
                .foregroundStyle(PantryTheme.forest)
                .frame(
                    width: 42,
                    height: 42
                )
                .background(
                    PantryTheme.forest.opacity(0.10),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
    }
}

struct PBStoragePicker: View {

    @Binding
    var selection: String

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    private let locations = [
        "Dispensa",
        "Frigo",
        "Freezer"
    ]

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text("Dove lo conservi?")
                .font(.caption)
                .foregroundStyle(.secondary)

            if dynamicTypeSize.isAccessibilitySize {
                locationPicker
                    .pickerStyle(.menu)
            } else {
                locationPicker
                    .pickerStyle(.segmented)
            }
        }
        .padding(16)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 20
            )
        )
    }

    private var locationPicker: some View {
        Picker(
            "Posizione",
            selection: $selection
        ) {
            ForEach(
                locations,
                id: \.self
            ) { location in
                Text(location)
                    .tag(location)
            }
        }
    }
}

struct PBPrimaryButton: View {

    let title: String
    let systemImage: String

    var disabled = false

    let action: () -> Void

    @State
    private var isHandlingTap = false

    var body: some View {
        Button {
            guard !isHandlingTap else {
                return
            }

            isHandlingTap = true
            action()

            Task { @MainActor in
                try? await Task.sleep(
                    for: .milliseconds(800)
                )

                isHandlingTap = false
            }
        } label: {
            Label(
                title,
                systemImage: systemImage
            )
            .font(.headline)
            .foregroundStyle(PantryTheme.cream)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .padding(.vertical, 4)
            .background(
                PantryTheme.primaryGradient,
                in: RoundedRectangle(
                    cornerRadius: 18
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(
            disabled || isHandlingTap
        )
        .opacity(
            disabled || isHandlingTap
                ? 0.45
                : 1
        )
    }
}

struct PBTextField: View {

    let title: String
    let placeholder: String

    @Binding
    var text: String

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 7
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                placeholder,
                text: $text
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(
                PantryTheme.background,
                in: RoundedRectangle(
                    cornerRadius: 14
                )
            )
        }
    }
}
