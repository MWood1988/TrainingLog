import SwiftUI

struct ExerciseNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: WorkoutStore
    let exerciseId: UUID
    let exerciseName: String
    
    @State private var notes: String = ""
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Exercise Instructions")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                
                TextEditor(text: $notes)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                
                Text("Add notes about form, cues, or tips for this exercise")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom)
                
                Spacer()
            }
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveNotes()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                notes = store.getExerciseNotes(exerciseId: exerciseId)
            }
        }
    }
    
    private func saveNotes() {
        store.updateExerciseNotes(exerciseId: exerciseId, notes: notes)
    }
}
