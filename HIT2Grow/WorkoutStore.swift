import SwiftUI
import Combine

class WorkoutStore: ObservableObject {
    @Published var templates: [WorkoutTemplate] = []
    @Published var sessions: [WorkoutSession] = []
    
    private let templatesKey = "templates"
    private let sessionsKey = "sessions"
    
    init() {
        loadTemplates()
        loadSessions()
    }
    
    // MARK: - Templates
    
    func addTemplate(_ template: WorkoutTemplate) {
        templates.append(template)
        saveTemplates()
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
    
    private func saveSessions() {
        guard let encoded = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(encoded, forKey: sessionsKey)
    }
}
