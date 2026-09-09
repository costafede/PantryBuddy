import Foundation
import SwiftData

@Model
final class PriceRecord {

    var productBarcode: String
    var storeName: String
    var receiptDescription: String
    var price: Double
    var purchaseDate: Date

    init(
        productBarcode: String,
        storeName: String,
        receiptDescription: String,
        price: Double,
        purchaseDate: Date = Date()
    ) {
        self.productBarcode =
            productBarcode

        self.storeName =
            StoreNameNormalizer
                .canonicalName(
                    storeName
                )

        self.receiptDescription =
            receiptDescription

        self.price = price
        self.purchaseDate =
            purchaseDate
    }
}
