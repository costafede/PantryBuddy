import Foundation
import SwiftData

enum InventoryTrackingMode: String, CaseIterable, Identifiable {
    case packages
    case containedUnits

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .packages:
            return "Confezioni"

        case .containedUnits:
            return "Unità contenute"
        }
    }

    var explanation: String {
        switch self {
        case .packages:
            return "Conta pacchi, bottiglie o confezioni intere."

        case .containedUnits:
            return "Conta ciò che rimane dentro la confezione, per esempio piadine, uova o vasetti."
        }
    }
}

@Model
final class Product {

    @Attribute(.unique)
    var barcode: String

    var name: String
    var brand: String
    var packageQuantity: String

    // Immagine proveniente dal servizio online.
    var imageURL: String?

    /*
     Foto scattata dall’utente.

     È opzionale per mantenere compatibili i prodotti
     creati con le versioni precedenti dell’app.

     externalStorage permette a SwiftData di conservare
     immagini anche abbastanza grandi senza appesantire
     direttamente il database principale.
     */
    @Attribute(.externalStorage)
    var localImageData: Data?

    var inventoryQuantity: Int
    var storageLocation: String

    /*
     Questi campi sono opzionali per mantenere compatibili
     i prodotti creati dalle versioni precedenti dell’app.
     */
    var inventoryTrackingRawValue: String?
    var unitsPerPackage: Int?
    var inventoryUnitName: String?

    /*
     Data di scadenza più vicina del prodotto presente
     in dispensa. È opzionale per mantenere compatibili
     i prodotti creati dalle versioni precedenti.
     */
    var expirationDate: Date?

    var addedAt: Date

    init(
        barcode: String,
        name: String,
        brand: String,
        packageQuantity: String,
        imageURL: String? = nil,
        localImageData: Data? = nil,
        inventoryQuantity: Int = 1,
        storageLocation: String = "Dispensa",
        trackingMode: InventoryTrackingMode = .packages,
        unitsPerPackage: Int = 1,
        inventoryUnitName: String = "unità",
        expirationDate: Date? = nil
    ) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.packageQuantity = packageQuantity
        self.imageURL = imageURL
        self.localImageData = localImageData
        self.inventoryQuantity = max(
            0,
            inventoryQuantity
        )
        self.storageLocation = storageLocation
        self.inventoryTrackingRawValue = trackingMode.rawValue
        self.unitsPerPackage = max(
            1,
            unitsPerPackage
        )
        self.inventoryUnitName = Self.cleanedUnitName(
            inventoryUnitName
        )
        self.expirationDate = expirationDate.map {
            Calendar.current.startOfDay(
                for: $0
            )
        }
        self.addedAt = Date()
    }

    var inventoryTrackingMode: InventoryTrackingMode {
        InventoryTrackingMode(
            rawValue: inventoryTrackingRawValue ?? ""
        ) ?? .packages
    }

    var normalizedUnitsPerPackage: Int {
        max(
            1,
            unitsPerPackage ?? 1
        )
    }

    var normalizedInventoryUnitName: String {
        Self.cleanedUnitName(
            inventoryUnitName ?? ""
        )
    }

    var pluralInventoryUnitName: String {
        Self.italianPlural(
            of: normalizedInventoryUnitName
        )
    }

    var inventoryQuantityText: String {
        switch inventoryTrackingMode {
        case .packages:
            return inventoryQuantity == 1
                ? "1 confezione"
                : "\(inventoryQuantity) confezioni"

        case .containedUnits:
            let unitName = inventoryQuantity == 1
                ? normalizedInventoryUnitName
                : pluralInventoryUnitName

            return "\(inventoryQuantity) \(unitName)"
        }
    }

    var packageContentText: String? {
        guard inventoryTrackingMode == .containedUnits else {
            return nil
        }

        return "\(normalizedUnitsPerPackage) \(pluralInventoryUnitName) per confezione"
    }

    func inventoryAmount(
        forPackageCount packageCount: Int
    ) -> Int {
        let cleanPackageCount = max(
            0,
            packageCount
        )

        switch inventoryTrackingMode {
        case .packages:
            return cleanPackageCount

        case .containedUnits:
            return cleanPackageCount
                * normalizedUnitsPerPackage
        }
    }

    static func inventoryAmount(
        forPackageCount packageCount: Int,
        trackingMode: InventoryTrackingMode,
        unitsPerPackage: Int
    ) -> Int {
        let cleanPackageCount = max(
            0,
            packageCount
        )

        switch trackingMode {
        case .packages:
            return cleanPackageCount

        case .containedUnits:
            return cleanPackageCount
                * max(
                    1,
                    unitsPerPackage
                )
        }
    }

    static func cleanedUnitName(
        _ value: String
    ) -> String {
        let cleaned = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return cleaned.isEmpty
            ? "unità"
            : cleaned.lowercased()
    }

    static func italianPlural(
        of singular: String
    ) -> String {
        let value = cleanedUnitName(
            singular
        )

        let irregularPlurals = [
            "uovo": "uova",
            "uova": "uova"
        ]

        if let irregular = irregularPlurals[value] {
            return irregular
        }

        guard let lastCharacter = value.last else {
            return "unità"
        }

        let stem = value.dropLast()

        switch lastCharacter {
        case "a":
            return stem + "e"

        case "o", "e":
            return stem + "i"

        default:
            return value
        }
    }
}
