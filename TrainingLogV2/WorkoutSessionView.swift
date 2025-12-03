import SwiftUI

struct WorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: WorkoutSession
    
    let onSave: (WorkoutSession) -> Void
    
    init(template: WorkoutTemplate, existingSession: WorkoutSession? = nil, onSave: @escaping (WorkoutSession) -> Void) {
        if let existing = existingSession {
            _session = State(initialValue: existing)
        } else {
            let exercises = template.exercises.map { exTemplate in
                Exercise(name: exTemplate.name, sets: [ExerciseSet(reps: 0, weight: 0)])
            }
            _session = State(initialValue: WorkoutSession(templateId: template.id, date: Date(), exercises: exercises))
        }
        self.onSave = onSave
    }
    
    var body: some View {
        Form {
            ForEach($session.exercises) { $exercise in
                exerciseSection(for: $exercise)
            }
        }
        .navigationTitle(formattedDate)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                saveButton
            }
            ToolbarItem(placement: .cancellationAction) {
                cancelButton
            }
        }
    }
    
    private func exerciseSection(for exercise: Binding<Exercise>) -> some View {
        Section(header: Text(exercise.wrappedValue.name)) {
            ForEach(Array(exercise.wrappedValue.sets.enumerated()), id: \.element.id) { index, _ in
                SetRowEditor(set: exercise.sets[index])
            }
            addSetButton(for: exercise)
        }
    }
    
    private func addSetButton(for exercise: Binding<Exercise>) -> some View {
        Button("Add Set") {
            exercise.wrappedValue.sets.append(ExerciseSet(reps: 0, weight: 0))
        }
    }
    
    private var formattedDate: String {
        session.date.formatted(
            Date.FormatStyle()
                .month(.abbreviated)
                .day()
                .year()
                .hour(.defaultDigits(amPM: .abbreviated))
                .minute()
        )
    }
    
    private var saveButton: some View {
        Button("Save") {
            onSave(session)
            dismiss()
        }
    }
    
    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
        }
    }
}

struct SetRowEditor: View {
    @Binding var set: ExerciseSet
    
    var body: some View {
        HStack {
            TextField("Reps", text: repsBinding)
                .keyboardType(.numberPad)
            
            TextField("Weight", text: weightBinding)
                .keyboardType(.decimalPad)
        }
    }
    
    private var repsBinding: Binding<String> {
        Binding(
            get: { set.reps == 0 ? "" : String(set.reps) },
            set: { set.reps = Int($0) ?? 0 }
        )
    }
    
    private var weightBinding: Binding<String> {
        Binding(
            get: { set.weight == 0 ? "" : String(set.weight) },
            set: { set.weight = Double($0) ?? 0 }
        )
    }
}
