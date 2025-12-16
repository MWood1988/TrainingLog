import SwiftUI
import Combine

class WorkoutStore: ObservableObject {
    @Published var templates: [WorkoutTemplate] = []
    @Published var sessions: [WorkoutSession] = []
    @Published var exerciseLibrary: [ExerciseLibraryItem] = []
    
    private let templatesKey = "templates"
    private let sessionsKey = "sessions"
    private let exerciseLibraryKey = "exerciseLibrary"
    
    init() {
        loadExerciseLibrary()
        loadTemplates()
        loadSessions()
    }
    
    // MARK: - Exercise Library
    
    func addExercise(_ exercise: ExerciseLibraryItem) {
        exerciseLibrary.append(exercise)
        saveExerciseLibrary()
    }
    
    func getOrCreateExercise(name: String) -> ExerciseLibraryItem {
        // Check if exercise already exists (case-insensitive)
        if let existing = exerciseLibrary.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return existing
        }
        
        // Create new exercise
        let newExercise = ExerciseLibraryItem(name: name)
        addExercise(newExercise)
        return newExercise
    }
    
    func exerciseExists(name: String) -> Bool {
        exerciseLibrary.contains(where: { $0.name.lowercased() == name.lowercased() })
    }
    
    // NEW: Update exercise notes
    func updateExerciseNotes(exerciseId: UUID, notes: String) {
        if let index = exerciseLibrary.firstIndex(where: { $0.id == exerciseId }) {
            exerciseLibrary[index].notes = notes
            saveExerciseLibrary()
        }
    }
    
    // NEW: Get exercise notes
    func getExerciseNotes(exerciseId: UUID) -> String {
        return exerciseLibrary.first(where: { $0.id == exerciseId })?.notes ?? ""
    }
    
    // Delete exercise from library and all associated data
    func deleteExercise(_ exercise: ExerciseLibraryItem) {
        // Remove from exercise library
        exerciseLibrary.removeAll { $0.id == exercise.id }
        saveExerciseLibrary()
        
        // Remove from all templates
        for i in 0..<templates.count {
            templates[i].exercises.removeAll { $0.exerciseId == exercise.id }
        }
        saveTemplates()
        
        // Remove from all sessions
        for i in 0..<sessions.count {
            sessions[i].exercises.removeAll { $0.exerciseId == exercise.id }
        }
        // Remove sessions that have no exercises left
        sessions.removeAll { $0.exercises.isEmpty }
        saveSessions()
    }
    
    // MARK: - Templates
    
    func addTemplate(_ template: WorkoutTemplate) {
        templates.append(template)
        saveTemplates()
    }
    
    func updateTemplate(_ template: WorkoutTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            saveTemplates()
        }
    }
    
    func deleteTemplate(at offsets: IndexSet) {
        templates.remove(atOffsets: offsets)
        saveTemplates()
    }
    
    func sessions(for template: WorkoutTemplate) -> [WorkoutSession] {
        sessions
            .filter { $0.templateId == template.id }
            .sorted { $0.date > $1.date }
    }
    
    // Get all sessions for a specific exercise (across all templates)
    func sessions(for exerciseId: UUID) -> [(WorkoutSession, Exercise)] {
        var results: [(WorkoutSession, Exercise)] = []
        
        for session in sessions {
            for exercise in session.exercises where exercise.exerciseId == exerciseId {
                results.append((session, exercise))
            }
        }
        
        return results.sorted { $0.0.date > $1.0.date }
    }
    
    // MARK: - Sessions
    
    func addSession(_ session: WorkoutSession) {
        sessions.append(session)
        saveSessions()
    }
    
    func updateSession(_ session: WorkoutSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            saveSessions()
        }
    }
    
    // MARK: - Persistence
    
    private func loadExerciseLibrary() {
        guard let data = UserDefaults.standard.data(forKey: exerciseLibraryKey),
              let decoded = try? JSONDecoder().decode([ExerciseLibraryItem].self, from: data) else {
            return
        }
        exerciseLibrary = decoded
    }
    
    private func saveExerciseLibrary() {
        guard let encoded = try? JSONEncoder().encode(exerciseLibrary) else { return }
        UserDefaults.standard.set(encoded, forKey: exerciseLibraryKey)
    }
    
    private func loadTemplates() {
        guard let data = UserDefaults.standard.data(forKey: templatesKey),
              let decoded = try? JSONDecoder().decode([WorkoutTemplate].self, from: data) else {
            return
        }
        templates = decoded
    }
    
    private func saveTemplates() {
        guard let encoded = try? JSONEncoder().encode(templates) else { return }
        UserDefaults.standard.set(encoded, forKey: templatesKey)
    }
    
    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let decoded = try? JSONDecoder().decode([WorkoutSession].self, from: data) else {
            return
        }
        sessions = decoded
    }
    
    // Made public so WorkoutHistoryView can call it after deleting sessions
    func saveSessions() {
        guard let encoded = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(encoded, forKey: sessionsKey)
    }
}
