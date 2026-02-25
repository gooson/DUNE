import SwiftUI
import SwiftData

/// CRUD view for managing user-defined exercise categories
struct UserCategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserCategory.sortOrder) private var categories: [UserCategory]
    @State private var showingAddSheet = false
    @State private var editingCategory: UserCategory?

    var body: some View {
        List {
            // Built-in categories (read-only)
            Section("Built-in") {
                ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                    HStack {
                        Image(systemName: "tag.fill")
                            .font(.caption)
                            .foregroundStyle(DS.Color.activity)
                            .frame(width: 24)
                        Text(cat.displayName)
                        Spacer()
                        Text("Default")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // User categories (editable)
            Section("Custom") {
                if categories.isEmpty {
                    Text("No custom categories yet")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(categories) { category in
                        Button {
                            editingCategory = category
                        } label: {
                            HStack {
                                Image(systemName: category.iconName)
                                    .font(.caption)
                                    .foregroundStyle(Color(hex: category.colorHex) ?? DS.Color.activity)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                    Text(category.name)
                                        .foregroundStyle(.primary)
                                    Text(category.defaultInputType.displayLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete(perform: deleteCategories)
                }
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            UserCategoryEditView(mode: .create) { name, icon, color, inputType in
                let newCategory = UserCategory(
                    name: name,
                    iconName: icon,
                    colorHex: color,
                    defaultInputType: inputType,
                    sortOrder: categories.count
                )
                modelContext.insert(newCategory)
            }
        }
        .sheet(item: $editingCategory) { category in
            UserCategoryEditView(
                mode: .edit(category)
            ) { name, icon, color, inputType in
                category.name = name
                category.iconName = icon
                category.colorHex = color
                category.defaultInputTypeRaw = inputType.rawValue
            }
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
    }
}

// MARK: - Edit View

struct UserCategoryEditView: View {
    enum Mode: Identifiable {
        case create
        case edit(UserCategory)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let cat): return cat.id.uuidString
            }
        }
    }

    let mode: Mode
    let onSave: (String, String, String, ExerciseInputType) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    @State private var selectedInputType: ExerciseInputType

    private static let availableIcons = [
        "tag.fill", "star.fill", "bolt.fill", "flame.fill",
        "heart.fill", "figure.run", "dumbbell.fill", "trophy.fill",
        "target", "wind", "drop.fill", "leaf.fill"
    ]

    private static let availableColors = [
        "007AFF", "FF3B30", "FF9500", "FFCC00",
        "34C759", "5AC8FA", "AF52DE", "FF2D55"
    ]

    init(mode: Mode, onSave: @escaping (String, String, String, ExerciseInputType) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _selectedIcon = State(initialValue: "tag.fill")
            _selectedColor = State(initialValue: "007AFF")
            _selectedInputType = State(initialValue: .setsRepsWeight)
        case .edit(let category):
            _name = State(initialValue: category.name)
            _selectedIcon = State(initialValue: category.iconName)
            _selectedColor = State(initialValue: category.colorHex)
            _selectedInputType = State(initialValue: category.defaultInputType)
        }
    }

    private static let maxNameLength = 50

    private var isValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.count <= Self.maxNameLength
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                        .autocorrectionDisabled()
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: DS.Spacing.sm) {
                        ForEach(Self.availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        selectedIcon == icon
                                            ? (Color(hex: selectedColor) ?? DS.Color.activity).opacity(0.2)
                                            : Color.secondary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                                    )
                                    .foregroundStyle(
                                        selectedIcon == icon
                                            ? (Color(hex: selectedColor) ?? DS.Color.activity)
                                            : .secondary
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: DS.Spacing.sm) {
                        ForEach(Self.availableColors, id: \.self) { hex in
                            Button {
                                selectedColor = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .blue)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if selectedColor == hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Default Input Type") {
                    Picker("Input Type", selection: $selectedInputType) {
                        Text("Sets × Reps × Weight").tag(ExerciseInputType.setsRepsWeight)
                        Text("Sets × Reps").tag(ExerciseInputType.setsReps)
                        Text("Duration + Distance").tag(ExerciseInputType.durationDistance)
                        Text("Duration + Intensity").tag(ExerciseInputType.durationIntensity)
                        Text("Rounds Based").tag(ExerciseInputType.roundsBased)
                    }
                }
            }
            .navigationTitle(mode.isCreate ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedName = String(name.trimmingCharacters(in: .whitespaces).prefix(Self.maxNameLength))
                        onSave(
                            trimmedName,
                            selectedIcon,
                            selectedColor,
                            selectedInputType
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Helpers

extension UserCategoryEditView.Mode {
    var isCreate: Bool {
        if case .create = self { return true }
        return false
    }
}

extension ExerciseInputType {
    var displayLabel: String {
        switch self {
        case .setsRepsWeight: "Sets × Reps × Weight"
        case .setsReps: "Sets × Reps"
        case .durationDistance: "Duration + Distance"
        case .durationIntensity: "Duration + Intensity"
        case .roundsBased: "Rounds Based"
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgbValue: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgbValue) else { return nil }

        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
