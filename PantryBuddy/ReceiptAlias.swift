import Foundation
import SwiftData

@Model
final class ReceiptAlias {

    var storeName: String
    var receiptText: String
    var productBarcode: String

    var createdAt: Date
    var lastSeenAt: Date

    init(
        storeName: String,
        receiptText: String,
        productBarcode: String
    ) {
        self.storeName = storeName
        self.receiptText = receiptText
        self.productBarcode = productBarcode
        self.createdAt = Date()
        self.lastSeenAt = Date()
    }
}
