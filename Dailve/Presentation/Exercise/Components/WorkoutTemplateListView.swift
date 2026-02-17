import SwiftUI
import SwiftData

struct WorkoutTemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]

    @State private var showingCreateSheet = false
    @State private var templateToEdit: WorkoutTemplate?
    @State private var templateToDelete: WorkoutTemplate?
    let onStartTemplate: (WorkoutTemplate) -> Void

    var body: some View {
        Group {
            if templates.isEmpty {
                emptyState
            } else {
                templateList
            }
        }
        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            TemplateFormView()
        }
        .sheet(item: $templateToEdit) { template in
            TemplateFormView(template: template)
        }
        .confirmationDialog(
            "Delete Template?",
            isPresented: .init(
                get: { templateToDelete != nil },
                set: { if !$0 { templateToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let template = templateToDelete {
                    modelContext.delete(template)
                    templateToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                templateToDelete = nil
            }
        } message: {
            Text("This will permanently remove the template from all devices.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No Templates")
                .font(.headline)
            Text("Create templates for your workout routines")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showingCreateSheet = true
            } label: {
                Label("Create Template", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.activity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var templateList: some View {
        List {
            ForEach(templates) { template in
                Button {
                    onStartTemplate(template)
                } label: {
                    templateRow(template)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        templateToEdit = template
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        templateToDelete = template
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text(template.name)
                    .font(.headline)
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(DS.Color.activity)
            }

            HStack(spacing: DS.Spacing.xs) {
                Text("\(template.exerciseEntries.count) exercises")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !template.exerciseEntries.isEmpty {
                    Text("\u{00B7}")
                        .foregroundStyle(.tertiary)
                    Text(template.exerciseEntries.map(\.exerciseName).prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, DS.Spacing.xxs)
    }
}
