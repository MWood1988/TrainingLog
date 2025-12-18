import SwiftUI

struct ContentView: View {
    @StateObject private var store = WorkoutStore()
    @State private var showingNewTemplate = false
    @State private var editMode = false
    @State private var exportFileURL: URL?
    @State private var showingImport = false
    @State private var templateToDelete: WorkoutTemplate?  // Track template pending deletion
    @State private var templateToEdit: WorkoutTemplate?  // Track template being edited
    @State private var showingEditSheet = false  // Simple boolean for testing
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(store.templates) { template in
                        templateRow(for: template)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    editButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    addButton
                }
            }
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                HStack(spacing: 16) {
                    importButton
                    exportButton
                }
                .padding()
            }
            .sheet(isPresented: $showingNewTemplate) {
                NewWorkoutTemplateView(store: store) { template in
                    store.addTemplate(template)
                    showingNewTemplate = false
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                if let template = templateToEdit {
                    EditWorkoutTemplateView(store: store, template: template) { updatedTemplate in
                        store.updateTemplate(updatedTemplate)
                        showingEditSheet = false
                        templateToEdit = nil
                    }
                }
            }
            .onChange(of: showingEditSheet) { oldValue, newValue in
                print("showingEditSheet changed from \(oldValue) to \(newValue)")
            }
            .sheet(item: $exportFileURL) { url in
                ShareSheet(items: [url])
            }
            .sheet(isPresented: $showingImport) {
                ImportView(store: store)
            }
            .alert("Delete Workout", isPresented: .constant(templateToDelete != nil), presenting: templateToDelete) { template in
                Button("Cancel", role: .cancel) {
                    templateToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    deleteTemplate(template)
                    templateToDelete = nil
                }
            } message: { template in
                Text("Are you sure you want to delete '\(template.name)'?")
            }
        }
    }
    
    private func templateRow(for template: WorkoutTemplate) -> some View {
        HStack(spacing: 12) {
            if editMode {
                deleteButton(for: template)
                    .transition(.scale)
            }
            
            WorkoutTemplateCard(template: template, store: store)
                .overlay(
                    Group {
                        if editMode {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    print("Overlay tapped for: \(template.name)")
                                    templateToEdit = template
                                    showingEditSheet = true
                                    print("showingEditSheet set to true, templateToEdit: \(template.name)")
                                }
                        }
                    }
                )
        }
        .padding(.horizontal)
        .animation(.default, value: editMode)
    }
    
    private func deleteButton(for template: WorkoutTemplate) -> some View {
        Button {
            templateToDelete = template
        } label: {
            Image(systemName: "minus.circle.fill")
                .foregroundColor(.red)
                .font(.title2)
        }
    }
    
    private func deleteTemplate(_ template: WorkoutTemplate) {
        if let index = store.templates.firstIndex(where: { $0.id == template.id }) {
            store.deleteTemplate(at: IndexSet(integer: index))
        }
    }
    
    private var editButton: some View {
        Button(editMode ? "Done" : "Edit") {
            editMode.toggle()
        }
    }
    
    private var importButton: some View {
        Button {
            showingImport = true
        } label: {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)
        }
        .background(
            Circle()
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }
    
    private var exportButton: some View {
        Button {
            exportData()
        } label: {
            Image(systemName: "square.and.arrow.up.circle.fill")
                .font(.system(size: 32))
        }
        .background(
            Circle()
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }
    
    private var addButton: some View {
        Button {
            showingNewTemplate = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title)
        }
    }
    
    private func exportData() {
        let csvString = generateCSV()
        
        // Create a temporary file with abbreviated date/time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmm"
        let dateTimeString = dateFormatter.string(from: Date())
        
        let fileName = "HITLog Export \(dateTimeString).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            exportFileURL = tempURL
        } catch {
            print("Error exporting data: \(error)")
        }
    }
    
    private func generateCSV() -> String {
        var csv = "Date,Time,Workout Template,Exercise,Set Number,Reps,Weight (kg),Form,Notes\n"
        
        // Sort sessions by date (most recent first)
        let sortedSessions = store.sessions.sorted { $0.date > $1.date }
        
        for session in sortedSessions {
            // Find the template name
            let templateName = store.templates.first(where: { $0.id == session.templateId })?.name ?? "Unknown"
            
            // Format date and time
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date = dateFormatter.string(from: session.date)
            
            dateFormatter.dateFormat = "HH:mm"
            let time = dateFormatter.string(from: session.date)
            
            for exercise in session.exercises {
                // Get notes for this exercise from the library
                let notes = store.getExerciseNotes(exerciseId: exercise.exerciseId)
                // Escape notes for CSV (wrap in quotes if contains comma, newline, or quotes)
                let escapedNotes = escapeCSVField(notes)
                
                for (index, set) in exercise.sets.enumerated() {
                    let setNumber = index + 1
                    let row = "\(date),\(time),\(templateName),\(exercise.name),\(setNumber),\(set.reps),\(set.weight),\(exercise.form.rawValue),\(escapedNotes)\n"
                    csv += row
                }
            }
        }
        
        return csv
    }
    
    private func escapeCSVField(_ field: String) -> String {
        // If field contains comma, newline, or quotes, wrap in quotes and escape internal quotes
        if field.contains(",") || field.contains("\n") || field.contains("\"") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}

// Share sheet for exporting files
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Make URL Identifiable so it can be used with sheet(item:)
extension URL: @retroactive Identifiable {
    public var id: String {
        self.absoluteString
    }
}
