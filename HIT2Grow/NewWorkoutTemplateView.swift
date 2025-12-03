import SwiftUI

struct NewWorkoutTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var templateName = ""
    @State private var exercises: [ExerciseTemplate] = []
    @State private var newExerciseName = ""
    
    let onSave: (WorkoutTemplate) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                workoutNameSection
                exercisesSection
            }
            .navigationTitle("New Workout Template")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    saveButton
                }
                ToolbarItem(placement: .cancellationAction) {
                    cancelButton
                }
            }
        }
    }
    
    private var workoutNameSection: some View {
        Section("Workout Name") {
            TextField("Enter workout name", text: $templateName)
        }
    }
    
    private var exercisesSection: some View {
        Section("Add Exercises") {
            addExerciseRow
            exerciseList
        }
    }
    
    private var addExerciseRow: some View {
        HStack {
            TextField("Exercise name", text: $newExerciseName)
            Button("Add") {
                addExercise()
            }
            .disabled(newExerciseName.isEmpty)
        }
    }
    
    @ViewBuilder
    private var exerciseList: some View {
        if !exercises.isEmpty {
            ForEach(exercises) { exercise in
                Text(exercise.name)
            }
            .onDelete(perform: deleteExercise)
        }
    }
    
    private var saveButton: some View {
        Button("Save") {
            saveTemplate()
        }
        .disabled(!canSave)
    }
    
    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
        }
    }
    
    private var canSave: Bool {
        !templateName.isEmpty && !exercises.isEmpty
    }
    
    private func addExercise() {
        let exercise = ExerciseTemplate(name: newExerciseName)
        exercises.append(exercise)
        newExerciseName = ""
    }
    
    private func deleteExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
    }
    
    private func saveTemplate() {
        let template = WorkoutTemplate(name: templateName, exercises: exercises)
        onSave(template)
        dismiss()
    }
}
