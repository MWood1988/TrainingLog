import SwiftUI

struct NewWorkoutTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: WorkoutStore
    @State private var templateName = ""
    @State private var exercises: [ExerciseTemplate] = []
    @State private var showingExercisePicker = false
    
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
        Section("Add Exercises") {
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
    
    private func saveTemplate() {
        let template = WorkoutTemplate(name: templateName, exercises: exercises)
        onSave(template)
        dismiss()
    }
}

// Exercise Picker View
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: WorkoutStore
    @State private var searchText = ""
    @State private var showingNewExercise = false
    
    let onSelect: (ExerciseLibraryItem) -> Void
    
    private var filteredExercises: [ExerciseLibraryItem] {
        if searchText.isEmpty {
            return store.exerciseLibrary.sorted { $0.name < $1.name }
        } else {
            return store.exerciseLibrary
                .filter { $0.name.lowercased().contains(searchText.lowercased()) }
                .sorted { $0.name < $1.name }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                
                if filteredExercises.isEmpty && !searchText.isEmpty {
                    createNewExercisePrompt
                } else {
                    exerciseList
                }
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("New Exercise", isPresented: $showingNewExercise) {
                TextField("Exercise Name", text: $searchText)
                Button("Create") {
                    createNewExercise()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Create a new exercise named '\(searchText)'?")
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search exercises", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }
    
    private var createNewExercisePrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "plus.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            Text("No exercises found")
                .font(.title3)
                .fontWeight(.semibold)
            Button {
                showingNewExercise = true
            } label: {
                Text("Create '\(searchText)'")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var exerciseList: some View {
        List {
            ForEach(filteredExercises) { exercise in
                exerciseRow(exercise)
            }
        }
        .listStyle(.plain)
    }
    
    private func exerciseRow(_ exercise: ExerciseLibraryItem) -> some View {
        Button {
            onSelect(exercise)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .foregroundColor(.primary)
                    
                    let sessionCount = store.sessions(for: exercise.id).count
                    if sessionCount > 0 {
                        Text("\(sessionCount) previous session\(sessionCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Never used")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    private func createNewExercise() {
        guard !searchText.isEmpty else { return }
        let newExercise = store.getOrCreateExercise(name: searchText)
        onSelect(newExercise)
        dismiss()
    }
}
