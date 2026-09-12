import Foundation
import SwiftUI

struct ShoppingListView: View {
    @AppStorage("PantryBuddyShoppingListV1")
    private var savedList = Data()

    @State private var newItemName = ""
    @State private var editingItem: PBShoppingItem?
    @State private var showClearConfirmation = false
    @State private var errorMessage: String?

    @FocusState private var isEntryFocused: Bool

    private var decodedItems: [PBShoppingItem]? {
        guard !savedList.isEmpty else {
            return []
        }

        guard let items = try? JSONDecoder().decode(
            [PBShoppingItem].self,
            from: savedList
        ), Set(items.map(\.id)).count == items.count else {
            return nil
        }

        return items
    }

    private var pendingItems: [PBShoppingItem] {
        (decodedItems ?? []).filter {
            !$0.isPurchased
        }
    }

    private var purchasedItems: [PBShoppingItem] {
        (decodedItems ?? []).filter {
            $0.isPurchased
        }
    }

    private var cleanNewItemName: String {
        newItemName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    var body: some View {
        List {
            if decodedItems != nil {
                Section {
                    entryRow
                } footer: {
                    Text(
                        "Puoi scrivere anche la quantità: per esempio, Latte · 2 bottiglie."
                    )
                }

                if pendingItems.isEmpty && purchasedItems.isEmpty {
                    ContentUnavailableView(
                        "La lista è vuota",
                        systemImage: "cart",
                        description: Text(
                            "Scrivi qui sopra il primo articolo da comprare."
                        )
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section("Da comprare · \(pendingItems.count)") {
                        if pendingItems.isEmpty {
                            Label(
                                "Hai preso tutto!",
                                systemImage: "checkmark.circle.fill"
                            )
                            .foregroundStyle(PantryTheme.forest)
                        }

                        ForEach(pendingItems) { item in
                            itemRow(item)
                        }
                    }

                    if !purchasedItems.isEmpty {
                        Section("Comprati · \(purchasedItems.count)") {
                            ForEach(purchasedItems) { item in
                                itemRow(item)
                            }

                            Button(role: .destructive) {
                                showClearConfirmation = true
                            } label: {
                                Label(
                                    "Rimuovi i comprati",
                                    systemImage: "trash"
                                )
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Lista non leggibile",
                    systemImage: "exclamationmark.triangle",
                    description: Text(
                        "Non riesco a leggere la lista salvata. I dati sono stati conservati."
                    )
                )
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(PantryTheme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Lista della spesa")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(
            PantryTheme.background,
            for: .navigationBar
        )
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(PantryTheme.forest)
        .sheet(item: $editingItem) { item in
            ShoppingItemEditor(item: item) { updatedName in
                updateItems { items in
                    guard let index = items.firstIndex(
                        where: { $0.id == item.id }
                    ) else {
                        return
                    }

                    items[index].name = updatedName
                }
            }
        }
        .confirmationDialog(
            "Rimuovere gli articoli comprati?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Rimuovi i comprati", role: .destructive) {
                _ = updateItems { items in
                    items.removeAll {
                        $0.isPurchased
                    }
                }
            }

            Button("Annulla", role: .cancel) {}
        } message: {
            Text(
                "Gli articoli ancora da comprare rimarranno nella lista."
            )
        }
        .alert(
            "Lista non salvata",
            isPresented: Binding(
                get: {
                    errorMessage != nil
                },
                set: {
                    if !$0 {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var entryRow: some View {
        HStack(spacing: 12) {
            TextField(
                "Cosa devi comprare?",
                text: $newItemName
            )
            .textInputAutocapitalization(.sentences)
            .submitLabel(.done)
            .focused($isEntryFocused)
            .onSubmit(addItem)
            .accessibilityLabel("Articolo da aggiungere")

            Button(action: addItem) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .disabled(cleanNewItemName.isEmpty)
            .accessibilityLabel("Aggiungi alla lista")
        }
        .listRowBackground(PantryTheme.card)
    }

    private func itemRow(
        _ item: PBShoppingItem
    ) -> some View {
        HStack(spacing: 10) {
            Button {
                isEntryFocused = false

                _ = updateItems { items in
                    guard let index = items.firstIndex(
                        where: { $0.id == item.id }
                    ) else {
                        return
                    }

                    items[index].isPurchased.toggle()
                }
            } label: {
                Image(
                    systemName: item.isPurchased
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.title2)
                .foregroundStyle(
                    item.isPurchased
                        ? PantryTheme.forest
                        : Color.secondary
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(
                item.isPurchased
                    ? "Segna \(item.name) come da comprare"
                    : "Segna \(item.name) come comprato"
            )

            Text(item.name)
                .font(.body)
                .foregroundStyle(
                    item.isPurchased
                        ? Color.secondary
                        : PantryTheme.ink
                )
                .strikethrough(item.isPurchased)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

            Button {
                isEntryFocused = false
                editingItem = item
            } label: {
                Image(systemName: "pencil")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Modifica \(item.name)")
        }
        .padding(.vertical, 3)
        .listRowBackground(PantryTheme.card)
        .swipeActions(
            edge: .trailing,
            allowsFullSwipe: false
        ) {
            Button(role: .destructive) {
                _ = updateItems { items in
                    items.removeAll {
                        $0.id == item.id
                    }
                }
            } label: {
                Label("Elimina", systemImage: "trash")
            }
        }
    }

    private func addItem() {
        let name = cleanNewItemName

        guard !name.isEmpty else {
            return
        }

        if updateItems({ items in
            items.append(
                PBShoppingItem(
                    id: UUID(),
                    name: name,
                    isPurchased: false
                )
            )
        }) {
            newItemName = ""
            isEntryFocused = true
        }
    }

    @discardableResult
    private func updateItems(
        _ change: (inout [PBShoppingItem]) -> Void
    ) -> Bool {
        guard var items = decodedItems else {
            errorMessage =
                "La lista salvata non è leggibile. Non è stata sovrascritta."
            return false
        }

        change(&items)

        do {
            let encoded = try JSONEncoder().encode(items)
            savedList = encoded
            return true
        } catch {
            errorMessage =
                "Non sono riuscito a salvare la modifica. Riprova."
            return false
        }
    }
}

nonisolated private struct PBShoppingItem:
    Codable,
    Identifiable
{
    let id: UUID
    var name: String
    var isPurchased: Bool
}

private struct ShoppingItemEditor: View {
    @Environment(\.dismiss)
    private var dismiss

    let item: PBShoppingItem
    let onSave: (String) -> Bool

    @State private var name: String
    @FocusState private var isNameFocused: Bool

    init(
        item: PBShoppingItem,
        onSave: @escaping (String) -> Bool
    ) {
        self.item = item
        self.onSave = onSave
        _name = State(initialValue: item.name)
    }

    private var cleanName: String {
        name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Articolo e quantità") {
                    TextField(
                        "Es. Latte · 2 bottiglie",
                        text: $name,
                        axis: .vertical
                    )
                    .lineLimit(1...4)
                    .focused($isNameFocused)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PantryTheme.background)
            .navigationTitle("Modifica articolo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("Salva") {
                        if onSave(cleanName) {
                            dismiss()
                        }
                    }
                    .disabled(cleanName.isEmpty)
                }
            }
            .task {
                isNameFocused = true
            }
        }
        .tint(PantryTheme.forest)
    }
}
