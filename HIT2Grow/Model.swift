import Foundation
import SwiftUI

// Exercise Library Item - represents a unique exercise across all workouts
struct ExerciseLibraryItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

enum ExerciseForm: String, Codable, CaseIterable {
    case meh = "Meh"
    case good = "Good"
    case perfect = "Perfect"
    
    var icon: String {
        switch self {
        case .meh: return "face.dashed"
        case .good: return "flame"
        case .perfect: return "bolt.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .meh: return .red
        case .good: return .orange
        case .perfect: return .green
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
    var exerciseId: UUID  // References ExerciseLibraryItem
    var name: String      // Cached for display
    
    init(id: UUID = UUID(), exerciseId: UUID, name: String) {
        self.id = id
        self.exerciseId = exerciseId
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
    var exerciseId: UUID  // References ExerciseLibraryItem
    var name: String      // Cached for display
    var sets: [ExerciseSet]
    var form: ExerciseForm
    
    init(id: UUID = UUID(), exerciseId: UUID, name: String, sets: [ExerciseSet], form: ExerciseForm = .good) {
        self.id = id
        self.exerciseId = exerciseId
        self.name = name
        self.sets = sets
        self.form = form
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
