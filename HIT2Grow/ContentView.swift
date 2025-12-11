import SwiftUI

struct ContentView: View {
    @StateObject private var store = WorkoutStore()
    @State private var showingNewTemplate = false
    @State private var editMode = false
    @State private var exportFileURL: URL?
    
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
                exportButton
                    .padding()
            }
            .sheet(isPresented: $showingNewTemplate) {
                NewWorkoutTemplateView(store: store) { template in
                    store.addTemplate(template)
                    showingNewTemplate = false
                }
            }
            .sheet(item: $exportFileURL) { url in
                ShareSheet(items: [url])
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
        }
        .padding(.horizontal)
        .animation(.default, value: editMode)
    }
    
    private func deleteButton(for template: WorkoutTemplate) -> some View {
        Button {
            if let index = store.templates.firstIndex(where: { $0.id == template.id }) {
                store.deleteTemplate(at: IndexSet(integer: index))
            }
        } label: {
            Image(systemName: "minus.circle.fill")
                .foregroundColor(.red)
                .font(.title2)
        }
    }
    
    private var editButton: some View {
        Button(editMode ? "Done" : "Edit") {
            editMode.toggle()
        }
    }
    
    private var exportButton: some View {
        Button {
            exportData()
        } label: {
            Image(systemName: "square.and.arrow.up.circle.fill")
                .font(.system(size: 32))
        }
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
        
        // Create a temporary file
        let fileName = "workout_export_\(Date().ISO8601Format()).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            exportFileURL = tempURL
        } catch {
            print("Error exporting data: \(error)")
        }
    }
    
    private func generateCSV() -> String {
        var csv = "Date,Time,Workout Template,Exercise,Set Number,Reps,Weight (kg),Form\n"
        
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
                for (index, set) in exercise.sets.enumerated() {
                    let setNumber = index + 1
                    let row = "\(date),\(time),\(templateName),\(exercise.name),\(setNumber),\(set.reps),\(set.weight),\(exercise.form.rawValue)\n"
                    csv += row
                }
            }
        }
        
        return csv
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
