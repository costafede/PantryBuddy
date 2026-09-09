import SwiftUI
import SwiftData

@main
struct PantryBuddyApp: App {

    var body: some Scene {

        WindowGroup {

            ContentView()
                .tint(
                    PantryTheme.forest
                )
        }
        .modelContainer(
            for: [
                Product.self,
                ReceiptAlias.self,
                PriceRecord.self
            ]
        )
    }
}
