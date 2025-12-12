import SwiftUI

struct ExerciseNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: WorkoutStore
    let exerciseId: UUID
    let exerciseName: String
    
    @State private var notes: String
    
    init(store: WorkoutStore, exerciseId: UUID, exerciseName: String) {
        self.store = store
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        _notes = State(initialValue: store.getExerciseNotes(exerciseId: exerciseId))
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add notes about how to perform this exercise, form cues, or any other helpful information.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top)
                
                TextEditor(text: $notes)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateExerciseNotes(exerciseId: exerciseId, notes: notes)
                        dismiss()
                    }
                }
            }
        }
    }
}
