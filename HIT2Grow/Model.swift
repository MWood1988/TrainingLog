import Foundation
import SwiftUI

enum ExerciseIntensity: String, Codable, CaseIterable {
    case meh = "Meh"
    case good = "Good"
    case intense = "Intense"
    
    var icon: String {
        switch self {
        case .meh: return "face.dashed"
        case .good: return "flame"
        case .intense: return "bolt.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .meh: return .gray
        case .good: return .orange
        case .intense: return .red
        }
    }
}

struct WorkoutTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var exercises: [ExerciseTemplate]
    
    init(id: UUID = UUID(), name: String, exercises: [ExerciseTemplate]) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}

struct ExerciseTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct WorkoutSession: Identifiable, Codable, Equatable {
    let id: UUID
    let templateId: UUID
    var date: Date
    var exercises: [Exercise]
    
    init(id: UUID = UUID(), templateId: UUID, date: Date, exercises: [Exercise]) {
        self.id = id
        self.templateId = templateId
        self.date = date
        self.exercises = exercises
    }
}

struct Exercise: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var sets: [ExerciseSet]
    var intensity: ExerciseIntensity
    
    init(id: UUID = UUID(), name: String, sets: [ExerciseSet], intensity: ExerciseIntensity = .good) {
        self.id = id
        self.name = name
        self.sets = sets
        self.intensity = intensity
    }
}

struct ExerciseSet: Identifiable, Codable, Equatable {
    let id: UUID
    var reps: Int
    var weight: Double
    
    init(id: UUID = UUID(), reps: Int, weight: Double) {
        self.id = id
        self.reps = reps
        self.weight = weight
    }
}
