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
        let rowsImported: Int
        let rowsSkipped: Int
        let sessionsAffected: Int
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
                
                Text("Select a CSV file exported from HITLog. Only new unique rows will be added.")
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
                        
                        if stats.rowsImported > 0 {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Rows added: \(stats.rowsImported)")
                            }
                        }
                        
                        if stats.rowsSkipped > 0 {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.orange)
                                Text("Duplicate rows skipped: \(stats.rowsSkipped)")
                            }
                        }
                        
                        if stats.sessionsAffected > 0 {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.blue)
                                Text("Sessions affected: \(stats.sessionsAffected)")
                            }
                        }
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
            
            // Create a detailed message
            var message = ""
            if stats.rowsImported > 0 {
                message += "Successfully added \(stats.rowsImported) new row\(stats.rowsImported == 1 ? "" : "s")!"
            }
            if stats.rowsSkipped > 0 {
                if !message.isEmpty { message += "\n" }
                message += "Skipped \(stats.rowsSkipped) duplicate row\(stats.rowsSkipped == 1 ? "" : "s")."
            }
            if stats.rowsImported == 0 && stats.rowsSkipped == 0 {
                message = "No rows found to import."
            }
            
            alertMessage = message
            showAlert = true
            
        } catch {
            alertMessage = "Error reading file: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    // Represents a single row from the CSV
    struct CSVRow: Hashable {
        let date: Date
        let templateName: String
        let exerciseName: String
        let exerciseOrder: Int  // NEW: Track exercise order
        let setNumber: Int
        let reps: Int
        let weight: Double
        let form: String
        let notes: String
        
        // Normalize date to minute precision for consistent hashing
        var normalizedDate: Date {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            return calendar.date(from: components) ?? date
        }
        
        // Normalize weight to 1 decimal place
        var normalizedWeight: Int {
            return Int((weight * 10).rounded())
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(normalizedDate)
            hasher.combine(templateName)
            hasher.combine(exerciseName)
            hasher.combine(setNumber)
            hasher.combine(reps)
            hasher.combine(normalizedWeight)
            hasher.combine(form)
            // Note: We don't hash notes or exerciseOrder for duplicate detection
        }
        
        static func == (lhs: CSVRow, rhs: CSVRow) -> Bool {
            return lhs.normalizedDate == rhs.normalizedDate &&
                   lhs.templateName == rhs.templateName &&
                   lhs.exerciseName == rhs.exerciseName &&
                   lhs.setNumber == rhs.setNumber &&
                   lhs.reps == rhs.reps &&
                   lhs.normalizedWeight == rhs.normalizedWeight &&
                   lhs.form == rhs.form
            // Note: We don't compare notes or exerciseOrder for duplicate detection
        }
    }
    
    private func parseAndImportCSV(_ csvString: String) -> ImportStats {
        let lines = csvString.components(separatedBy: .newlines)
        
        // Skip header row
        guard lines.count > 1 else {
            return ImportStats(rowsImported: 0, rowsSkipped: 0, sessionsAffected: 0)
        }
        
        // Detect CSV format by checking header
        let header = lines.first ?? ""
        let hasExerciseOrder = header.lowercased().contains("exercise order")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        // Build a set of all existing rows in the database
        var existingRows = Set<CSVRow>()
        
        for session in store.sessions {
            guard let template = store.templates.first(where: { $0.id == session.templateId }) else {
                continue
            }
            
            for (exerciseIndex, exercise) in session.exercises.enumerated() {
                let notes = store.getExerciseNotes(exerciseId: exercise.exerciseId)
                for (index, set) in exercise.sets.enumerated() {
                    let row = CSVRow(
                        date: session.date,
                        templateName: template.name,
                        exerciseName: exercise.name,
                        exerciseOrder: exerciseIndex + 1,
                        setNumber: index + 1,
                        reps: set.reps,
                        weight: set.weight,
                        form: exercise.form.rawValue,
                        notes: notes
                    )
                    existingRows.insert(row)
                }
            }
        }
        
        // Parse CSV rows and check for duplicates
        var rowsToImport: [CSVRow] = []
        var rowsSkipped = 0
        
        // Track notes to update (exerciseName -> notes)
        var notesToUpdate: [String: String] = [:]
        
        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            
            let columns = parseCSVLine(line)
            
            // Handle both old format (without Exercise Order) and new format (with Exercise Order)
            let minColumns = hasExerciseOrder ? 9 : 8
            guard columns.count >= minColumns else { continue }
            
            let dateString: String
            let timeString: String
            let templateName: String
            let exerciseName: String
            let exerciseOrder: Int
            let setNumber: Int
            let reps: Int
            let weight: Double
            let form: String
            let notes: String
            
            if hasExerciseOrder {
                // New format: Date,Time,Workout Template,Exercise,Exercise Order,Set Number,Reps,Weight (kg),Form,Notes
                dateString = columns[0]
                timeString = columns[1]
                templateName = columns[2]
                exerciseName = columns[3]
                exerciseOrder = Int(columns[4]) ?? 1
                setNumber = Int(columns[5]) ?? 0
                reps = Int(columns[6]) ?? 0
                weight = Double(columns[7]) ?? 0
                form = columns[8]
                notes = columns.count > 9 ? columns[9] : ""
            } else {
                // Old format: Date,Time,Workout Template,Exercise,Set Number,Reps,Weight (kg),Form,Notes
                dateString = columns[0]
                timeString = columns[1]
                templateName = columns[2]
                exerciseName = columns[3]
                exerciseOrder = 0  // Will be determined by order of appearance
                setNumber = Int(columns[4]) ?? 0
                reps = Int(columns[5]) ?? 0
                weight = Double(columns[6]) ?? 0
                form = columns[7]
                notes = columns.count > 8 ? columns[8] : ""
            }
            
            // Combine date and time
            guard let date = dateFormatter.date(from: "\(dateString) \(timeString)") else {
                continue
            }
            
            let csvRow = CSVRow(
                date: date,
                templateName: templateName,
                exerciseName: exerciseName,
                exerciseOrder: exerciseOrder,
                setNumber: setNumber,
                reps: reps,
                weight: weight,
                form: form,
                notes: notes
            )
            
            // Track notes for this exercise (use the latest non-empty notes)
            if !notes.isEmpty {
                notesToUpdate[exerciseName] = notes
            }
            
            // Check if this row already exists
            if existingRows.contains(csvRow) {
                rowsSkipped += 1
            } else {
                rowsToImport.append(csvRow)
                existingRows.insert(csvRow) // Add to set to prevent duplicates within the import file itself
            }
        }
        
        // Group rows by session (date + time + template)
        var sessionGroups: [String: [CSVRow]] = [:]
        
        for row in rowsToImport {
            let dateFormatter2 = DateFormatter()
            dateFormatter2.dateFormat = "yyyy-MM-dd HH:mm"
            let dateTimeString = dateFormatter2.string(from: row.date)
            let sessionKey = "\(dateTimeString)|\(row.templateName)"
            
            if sessionGroups[sessionKey] == nil {
                sessionGroups[sessionKey] = []
            }
            sessionGroups[sessionKey]?.append(row)
        }
        
        var sessionsAffected = 0
        
        // Process each session group
        for (_, rows) in sessionGroups {
            guard let firstRow = rows.first else { continue }
            
            let templateName = firstRow.templateName
            let sessionDate = firstRow.date
            
            // Find or create template
            var template = store.templates.first { $0.name == templateName }
            if template == nil {
                // Create new template
                template = WorkoutTemplate(name: templateName, exercises: [])
                store.addTemplate(template!)
            }
            
            guard var finalTemplate = template else { continue }
            
            // Check if a session already exists for this date/time and template
            let existingSession = store.sessions.first { session in
                guard session.templateId == finalTemplate.id else { return false }
                let timeDiff = abs(session.date.timeIntervalSince(sessionDate))
                return timeDiff < 60
            }
            
            if let existingSession = existingSession {
                // Add rows to existing session
                var updatedSession = existingSession
                
                // Group new rows by exercise, preserving order
                let exerciseGroups = Dictionary(grouping: rows, by: { $0.exerciseName })
                
                // UPDATED: Sort exercises by their order value
                let sortedExerciseNames = exerciseGroups.keys.sorted { name1, name2 in
                    let order1 = exerciseGroups[name1]?.first?.exerciseOrder ?? Int.max
                    let order2 = exerciseGroups[name2]?.first?.exerciseOrder ?? Int.max
                    // If both have order 0 (old format), maintain original order
                    if order1 == 0 && order2 == 0 {
                        return false // Keep original order
                    }
                    return order1 < order2
                }
                
                for exerciseName in sortedExerciseNames {
                    guard let exerciseRows = exerciseGroups[exerciseName] else { continue }
                    
                    let libraryItem = store.getOrCreateExercise(name: exerciseName)
                    
                    // Update notes if provided
                    if let notes = notesToUpdate[exerciseName], !notes.isEmpty {
                        store.updateExerciseNotes(exerciseId: libraryItem.id, notes: notes)
                    }
                    
                    // Add exercise to template if not already there
                    if !finalTemplate.exercises.contains(where: { $0.exerciseId == libraryItem.id }) {
                        let exerciseTemplate = ExerciseTemplate(exerciseId: libraryItem.id, name: libraryItem.name)
                        finalTemplate.exercises.append(exerciseTemplate)
                        store.updateTemplate(finalTemplate)
                    }
                    
                    // Find or create exercise in session
                    if let exerciseIndex = updatedSession.exercises.firstIndex(where: { $0.exerciseId == libraryItem.id }) {
                        // Add sets to existing exercise
                        let sortedRows = exerciseRows.sorted(by: { $0.setNumber < $1.setNumber })
                        for row in sortedRows {
                            let newSet = ExerciseSet(reps: row.reps, weight: row.weight)
                            updatedSession.exercises[exerciseIndex].sets.append(newSet)
                        }
                    } else {
                        // Create new exercise with sets
                        let sortedRows = exerciseRows.sorted(by: { $0.setNumber < $1.setNumber })
                        let sets = sortedRows.map { ExerciseSet(reps: $0.reps, weight: $0.weight) }
                        let form = ExerciseForm(rawValue: exerciseRows.first?.form ?? "Good") ?? .good
                        
                        let newExercise = Exercise(
                            exerciseId: libraryItem.id,
                            name: exerciseName,
                            sets: sets,
                            form: form
                        )
                        updatedSession.exercises.append(newExercise)
                    }
                }
                
                store.updateSession(updatedSession)
                sessionsAffected += 1
                
            } else {
                // Create new session
                let exerciseGroups = Dictionary(grouping: rows, by: { $0.exerciseName })
                var sessionExercises: [Exercise] = []
                
                // UPDATED: Sort exercises by their order value to preserve sequence
                let sortedExerciseNames = exerciseGroups.keys.sorted { name1, name2 in
                    let order1 = exerciseGroups[name1]?.first?.exerciseOrder ?? Int.max
                    let order2 = exerciseGroups[name2]?.first?.exerciseOrder ?? Int.max
                    // If both have order 0 (old format), maintain original order from CSV
                    if order1 == 0 && order2 == 0 {
                        // Find first occurrence index in rows array
                        let index1 = rows.firstIndex(where: { $0.exerciseName == name1 }) ?? 0
                        let index2 = rows.firstIndex(where: { $0.exerciseName == name2 }) ?? 0
                        return index1 < index2
                    }
                    return order1 < order2
                }
                
                for exerciseName in sortedExerciseNames {
                    guard let exerciseRows = exerciseGroups[exerciseName] else { continue }
                    
                    let libraryItem = store.getOrCreateExercise(name: exerciseName)
                    
                    // Update notes if provided
                    if let notes = notesToUpdate[exerciseName], !notes.isEmpty {
                        store.updateExerciseNotes(exerciseId: libraryItem.id, notes: notes)
                    }
                    
                    // Add exercise to template if not already there
                    if !finalTemplate.exercises.contains(where: { $0.exerciseId == libraryItem.id }) {
                        let exerciseTemplate = ExerciseTemplate(exerciseId: libraryItem.id, name: libraryItem.name)
                        finalTemplate.exercises.append(exerciseTemplate)
                        store.updateTemplate(finalTemplate)
                    }
                    
                    // Sort rows by set number
                    let sortedRows = exerciseRows.sorted(by: { $0.setNumber < $1.setNumber })
                    let sets = sortedRows.map { ExerciseSet(reps: $0.reps, weight: $0.weight) }
                    let form = ExerciseForm(rawValue: exerciseRows.first?.form ?? "Good") ?? .good
                    
                    let exercise = Exercise(
                        exerciseId: libraryItem.id,
                        name: exerciseName,
                        sets: sets,
                        form: form
                    )
                    
                    sessionExercises.append(exercise)
                }
                
                let session = WorkoutSession(
                    templateId: finalTemplate.id,
                    date: sessionDate,
                    exercises: sessionExercises
                )
                
                store.addSession(session)
                sessionsAffected += 1
            }
        }
        
        // Also update notes for exercises that were skipped (in case notes changed)
        for (exerciseName, notes) in notesToUpdate {
            if let libraryItem = store.exerciseLibrary.first(where: { $0.name == exerciseName }) {
                store.updateExerciseNotes(exerciseId: libraryItem.id, notes: notes)
            }
        }
        
        return ImportStats(
            rowsImported: rowsToImport.count,
            rowsSkipped: rowsSkipped,
            sessionsAffected: sessionsAffected
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
