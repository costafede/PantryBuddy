import SwiftUI

struct PBInventoryTrackingEditor: View {

    @Binding
    var trackingMode: InventoryTrackingMode

    @Binding
    var unitsPerPackage: Int

    @Binding
    var inventoryUnitName: String

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text("Come vuoi contarlo?")
                    .font(.headline)
                    .foregroundStyle(
                        PantryTheme.ink
                    )

                Text(trackingMode.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

            if dynamicTypeSize.isAccessibilitySize {
                trackingPicker
                    .pickerStyle(.menu)
            } else {
                trackingPicker
                    .pickerStyle(.segmented)
            }

            if trackingMode == .containedUnits {
                Divider()

                PBQuantityControl(
                    title: "Unità per confezione",
                    quantity: $unitsPerPackage,
                    minimum: 2,
                    maximum: 999
                )

                VStack(
                    alignment: .leading,
                    spacing: 7
                ) {
                    Text("Nome dell’unità")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(
                        "Es. piadina, uovo, vasetto",
                        text: $inventoryUnitName
                    )
                    .textInputAutocapitalization(
                        .never
                    )
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 48)
                    .background(
                        PantryTheme.background,
                        in: RoundedRectangle(
                            cornerRadius: 14
                        )
                    )

                    Text(
                        "Scrivilo al singolare. Per esempio: piadina, uovo o vasetto."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 20
            )
        )
        .onChange(of: trackingMode) {
            if trackingMode == .containedUnits,
               unitsPerPackage < 2 {
                unitsPerPackage = 6
            }
        }
    }

    private var trackingPicker: some View {
        Picker(
            "Modalità di conteggio",
            selection: $trackingMode
        ) {
            ForEach(
                InventoryTrackingMode.allCases
            ) { mode in
                Text(mode.title)
                    .tag(mode)
            }
        }
    }
}
