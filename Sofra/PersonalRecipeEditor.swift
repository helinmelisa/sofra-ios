import SwiftUI

struct PersonalRecipeEditor: View {
    @EnvironmentObject private var store: FoodStore
    @Environment(\.dismiss) private var dismiss
    var initial: Recipe? = nil
    var initialServings = 1
    var initialName = ""
    var onSave: (Recipe, Int) -> Void
    @State private var name = ""
    @State private var minutes = 20
    @State private var portions = 1
    @State private var ingredients = [PersonalIngredient()]
    @State private var instructions = ""
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Yemeğin") {
                    TextField("Yemek adı", text: $name)
                    Stepper("\(portions) porsiyon", value: $portions, in: 1...8)
                    Stepper("\(minutes) dakika", value: $minutes, in: 5...180, step: 5)
                }
                Section {
                    ForEach($ingredients) { $ingredient in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                TextField("Malzeme adı", text: $ingredient.name)
                                Menu {
                                    ForEach(store.data.inventory) { stock in
                                        Button(stock.name) { ingredient.name = stock.recipeName ?? stock.name }
                                    }
                                } label: { Image(systemName: "carrot").frame(width: 44, height: 44) }
                                    .accessibilityLabel("Mutfaktan malzeme seç")
                            }
                            TextField("Toplam kullanılan · ör. 300 g veya 2 adet", text: $ingredient.quantity)
                            if let stock = store.data.inventory.first(where: { Recipe.ingredientKey($0.recipeName ?? $0.name) == Recipe.ingredientKey(ingredient.name) }) {
                                Text("Mutfakta: \(stock.quantity)").font(.caption).foregroundStyle(.secondary)
                            }
                            Button("Malzemeyi kaldır", role: .destructive) { ingredients.removeAll { $0.id == ingredient.id } }.font(.caption)
                        }.padding(.vertical, 5)
                    }
                    Button { ingredients.append(PersonalIngredient()) } label: { Label("Malzeme ekle", systemImage: "plus") }
                } header: { Text("Malzemeler · \(portions) porsiyon için toplam") }
                  footer: { Text("Yukarıdaki porsiyon sayısının tamamında kullanacağın miktarı yaz. Örneğin 3 porsiyon için toplam 600 g. Miktarlar porsiyona göre ölçeklenir.") }
                Section("Hazırlanışı · isteğe bağlı") {
                    TextField("Her adımı ayrı satıra yazabilirsin", text: $instructions, axis: .vertical).lineLimit(3...8)
                }
                Section {
                    Text("Tarifin kitaplığında saklanır. Öğüne seçtiğinde eksikler alışverişe yansır; yalnızca pişirdiğinde stoktan düşer.").font(.caption)
                    if let error { Text(error).foregroundStyle(.red) }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(initial == nil ? "Kendi yemeğim" : "Tarifimi düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        do {
                            let recipe = try Recipe.personal(id: initial?.id, name: name, minutes: minutes, portions: portions, ingredients: ingredients, instructions: instructions)
                            store.data.savePersonalRecipe(recipe)
                            onSave(recipe, portions)
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ingredients.isEmpty)
                }
            }
            .onAppear {
                guard !loaded else { return }; loaded = true
                portions = min(8, max(1, initialServings))
                name = initialName
                if let initial {
                    name = initial.name
                    minutes = initial.minutes
                    instructions = initial.steps.joined(separator: "\n")
                    ingredients = initial.ingredients.map { PersonalIngredient(name: $0, quantity: initial.amount(for: $0, servings: portions)?.text ?? "") }
                }
            }
        }.tint(Ink.dark)
    }
}
