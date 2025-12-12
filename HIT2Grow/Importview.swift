import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: WorkoutStore
    @State private var isImporting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var importStats: ImportStats?
    
    struct ImportStats {
        let sessionsImported: Int
        let exercisesImported: Int
        let templatesCreated: Int
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Import Workout Data")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Select a CSV file exported from HIT2Grow")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button {
                    isImporting = true
                } label: {
                    Text("Choose File")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                if let stats = importStats {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Import Complete!")
                            .font(.headline)
                            .foregroundColor(.green)
                        Text("Templates created: \(stats.templatesCreated)")
                        Text("Sessions imported: \(stats.sessionsImported)")
                        Text("Exercises found: \(stats.exercisesImported)")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert("Import Status", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importCSV(from: url)
        case .failure(let error):
            alertMessage = "Failed to access file: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func importCSV(from url: URL) {
        do {
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                alertMessage = "Cannot access file"
                showAlert = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let csvString = try String(contentsOf: url, encoding: .utf8)
            let stats = parseAndImportCSV(csvString)
            
            importStats = stats
            alertMessage = "Successfully imported \(stats.sessionsImported) sessions!"
            showAlert = true
            
        } catch {
            alertMessage = "Error reading file: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func parseAndImportCSV(_ csvString: String) -> ImportStats {
        let lines = csvString.components(separatedBy: .newlines)
        
        // Skip header row
        guard lines.count > 1 else {
            return ImportStats(sessionsImported: 0, exercisesImported: 0, templatesCreated: 0)
        }
        
        // Dictionary to group rows by session (date + time + template)
        var sessionGroups: [String: [(date: Date, templateName: String, exerciseName: String, setNumber: Int, reps: Int, weight: Double, form: String)]] = [:]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        // Parse all rows
        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            
            let columns = parseCSVLine(line)
            guard columns.count >= 8 else { continue }
            
            let dateString = columns[0]
            let timeString = columns[1]
            let templateName = columns[2]
            let exerciseName = columns[3]
            let setNumber = Int(columns[4]) ?? 0
            let reps = Int(columns[5]) ?? 0
            let weight = Double(columns[6]) ?? 0
            let form = columns[7]
            
            // Combine date and time
            guard let date = dateFormatter.date(from: "\(dateString) \(timeString)") else {
                continue
            }
            
            let sessionKey = "\(dateString)_\(timeString)_\(templateName)"
            
            if sessionGroups[sessionKey] == nil {
                sessionGroups[sessionKey] = []
            }
            
            sessionGroups[sessionKey]?.append((
                date: date,
                templateName: templateName,
                exerciseName: exerciseName,
                setNumber: setNumber,
                reps: reps,
                weight: weight,
                form: form
            ))
        }
        
        var templatesCreated = 0
        var sessionsImported = 0
        var exercisesSet: Set<String> = []
        
        // Process each session group
        for (_, rows) in sessionGroups {
            guard let firstRow = rows.first else { continue }
            
            let templateName = firstRow.templateName
            let sessionDate = firstRow.date
            
            // Find or create template
            var template = store.templates.first { $0.name == templateName }
            if template == nil {
                // Create new template with exercises from this session
                let uniqueExerciseNames = Set(rows.map { $0.exerciseName })
                let exerciseTemplates = uniqueExerciseNames.map { name -> ExerciseTemplate in
                    let libraryItem = store.getOrCreateExercise(name: name)
                    exercisesSet.insert(name)
                    return ExerciseTemplate(exerciseId: libraryItem.id, name: name)
                }
                
                template = WorkoutTemplate(name: templateName, exercises: exerciseTemplates)
                store.addTemplate(template!)
                templatesCreated += 1
            }
            
            guard let finalTemplate = template else { continue }
            
            // Group rows by exercise
            var exerciseGroups: [String: [(setNumber: Int, reps: Int, weight: Double, form: String)]] = [:]
            for row in rows {
                if exerciseGroups[row.exerciseName] == nil {
                    exerciseGroups[row.exerciseName] = []
                }
                exerciseGroups[row.exerciseName]?.append((
                    setNumber: row.setNumber,
                    reps: row.reps,
                    weight: row.weight,
                    form: row.form
                ))
            }
            
            // Create exercises for session
            var sessionExercises: [Exercise] = []
            for (exerciseName, sets) in exerciseGroups {
                // Get or create exercise in library
                let libraryItem = store.getOrCreateExercise(name: exerciseName)
                exercisesSet.insert(exerciseName)
                
                // Sort sets by set number
                let sortedSets = sets.sorted { $0.setNumber < $1.setNumber }
                
                // Convert to ExerciseSet objects
                let exerciseSets = sortedSets.map { ExerciseSet(reps: $0.reps, weight: $0.weight) }
                
                // Parse form
                let form = ExerciseForm(rawValue: sets.first?.form ?? "Good") ?? .good
                
                let exercise = Exercise(
                    exerciseId: libraryItem.id,
                    name: exerciseName,
                    sets: exerciseSets,
                    form: form
                )
                
                sessionExercises.append(exercise)
            }
            
            // Create and save session
            let session = WorkoutSession(
                templateId: finalTemplate.id,
                date: sessionDate,
                exercises: sessionExercises
            )
            
            store.addSession(session)
            sessionsImported += 1
        }
        
        return ImportStats(
            sessionsImported: sessionsImported,
            exercisesImported: exercisesSet.count,
            templatesCreated: templatesCreated
        )
    }
    
    // Helper function to parse CSV lines properly (handles quoted fields)
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        // Add the last field
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        
        return fields
    }
}
