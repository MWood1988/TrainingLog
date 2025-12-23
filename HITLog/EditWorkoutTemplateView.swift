import SwiftUI

struct EditWorkoutTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: WorkoutStore
    @State private var templateName: String
    @State private var exercises: [ExerciseTemplate]
    @State private var showingExercisePicker = false
    
    let template: WorkoutTemplate
    let onSave: (WorkoutTemplate) -> Void
    
    init(store: WorkoutStore, template: WorkoutTemplate, onSave: @escaping (WorkoutTemplate) -> Void) {
        self.store = store
        self.template = template
        self.onSave = onSave
        _templateName = State(initialValue: template.name)
        _exercises = State(initialValue: template.exercises)
    }
    
    var body: some View {
        NavigationView {
            Form {
                workoutNameSection
                exercisesSection
            }
            .navigationTitle("Edit Workout Template")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    saveButton
                }
                ToolbarItem(placement: .cancellationAction) {
                    cancelButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(store: store) { exercise in
                    addExercise(exercise)
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
        Section("Exercises") {
            addExerciseButton
            exerciseList
        }
    }
    
    private var addExerciseButton: some View {
        Button {
            showingExercisePicker = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
                Text("Add Exercise")
                    .foregroundColor(.blue)
            }
        }
    }
    
    @ViewBuilder
    private var exerciseList: some View {
        if !exercises.isEmpty {
            ForEach(exercises) { exercise in
                HStack {
                    Text(exercise.name)
                    Spacer()
                    if let libraryExercise = store.exerciseLibrary.first(where: { $0.id == exercise.exerciseId }) {
                        let sessionCount = store.sessions(for: libraryExercise.id).count
                        if sessionCount > 0 {
                            Text("\(sessionCount) session\(sessionCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .onDelete(perform: deleteExercise)
            .onMove(perform: moveExercise)
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
    
    private func addExercise(_ libraryItem: ExerciseLibraryItem) {
        let exercise = ExerciseTemplate(exerciseId: libraryItem.id, name: libraryItem.name)
        exercises.append(exercise)
    }
    
    private func deleteExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
    }
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
    }
    
    private func saveTemplate() {
        let updatedTemplate = WorkoutTemplate(id: template.id, name: templateName, exercises: exercises)
        onSave(updatedTemplate)
        dismiss()
    }
}
