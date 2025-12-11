import SwiftUI

struct WorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: WorkoutSession
    @FocusState private var focusedField: FocusedField?
    
    let onSave: (WorkoutSession) -> Void
    
    enum FocusedField: Hashable {
        case reps(exerciseId: UUID, setId: UUID)
        case weight(exerciseId: UUID, setId: UUID)
    }
    
    init(template: WorkoutTemplate, existingSession: WorkoutSession? = nil, onSave: @escaping (WorkoutSession) -> Void) {
        if let existing = existingSession {
            _session = State(initialValue: existing)
        } else {
            let exercises = template.exercises.map { exTemplate in
                Exercise(exerciseId: exTemplate.exerciseId, name: exTemplate.name, sets: [ExerciseSet(reps: 0, weight: 0)])
            }
            _session = State(initialValue: WorkoutSession(templateId: template.id, date: Date(), exercises: exercises))
        }
        self.onSave = onSave
    }
    
    var body: some View {
        Form {
            Section {
                DatePicker("Workout Date", selection: $session.date, displayedComponents: [.date, .hourAndMinute])
            }
            
            ForEach($session.exercises) { $exercise in
                exerciseSection(for: $exercise)
            }
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside fields
            focusedField = nil
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                saveButton
            }
            ToolbarItem(placement: .cancellationAction) {
                cancelButton
            }
            
            // Add keyboard toolbar here
            ToolbarItemGroup(placement: .keyboard) {
                if let focused = focusedField {
                    HStack(spacing: 8) {
                        switch focused {
                        case .reps(let exerciseId, let setId):
                            // Next Exercise button
                            Button(action: {
                                jumpToNextExercise(from: exerciseId)
                            }) {
                                Text("Next Exercise")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.green)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            
                            // Enter button (move to weight)
                            Button(action: {
                                focusedField = .weight(exerciseId: exerciseId, setId: setId)
                            }) {
                                Text("Enter")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            
                        case .weight(let exerciseId, let setId):
                            // Next Exercise button
                            Button(action: {
                                jumpToNextExercise(from: exerciseId)
                            }) {
                                Text("Next Exercise")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.green)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            
                            // Enter button (add set or dismiss)
                            Button(action: {
                                // Find the exercise and set to determine if we should add a new set
                                if let exerciseIndex = session.exercises.firstIndex(where: { $0.id == exerciseId }),
                                   let setIndex = session.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }),
                                   setIndex == session.exercises[exerciseIndex].sets.count - 1 {
                                    // This is the last set, add a new one
                                    let newSet = ExerciseSet(reps: 0, weight: 0)
                                    session.exercises[exerciseIndex].sets.append(newSet)
                                    
                                    // Focus on the reps field of the new set
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        focusedField = .reps(exerciseId: exerciseId, setId: newSet.id)
                                    }
                                } else {
                                    // Not the last set, just dismiss keyboard
                                    focusedField = nil
                                }
                            }) {
                                Text("Enter")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
    }
    
    private func exerciseSection(for exercise: Binding<Exercise>) -> some View {
        let hasValidSets = exercise.wrappedValue.sets.contains { $0.reps > 0 }
        
        return Section(
            header: Text(exercise.wrappedValue.name),
            footer: hasValidSets ? nil : Text("This exercise will not be saved (no reps recorded)")
                .font(.caption)
                .foregroundColor(.orange)
        ) {
            ForEach(Array(exercise.wrappedValue.sets.enumerated()), id: \.element.id) { index, set in
                SetRowEditor(
                    set: exercise.sets[index],
                    exerciseId: exercise.wrappedValue.id,
                    focusedField: $focusedField
                )
            }
            addSetButton(for: exercise)
            
            // Intensity selector
            VStack(alignment: .leading, spacing: 8) {
                Text("How was your form?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(ExerciseForm.allCases, id: \.self) { form in
                        FormButton(
                            form: form,
                            isSelected: exercise.wrappedValue.form == form
                        ) {
                            exercise.wrappedValue.form = form
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    private func addSetButton(for exercise: Binding<Exercise>) -> some View {
        Button("Add Set") {
            exercise.wrappedValue.sets.append(ExerciseSet(reps: 0, weight: 0))
        }
    }
    
    private func jumpToNextExercise(from currentExerciseId: UUID) {
        // Find current exercise index
        guard let currentIndex = session.exercises.firstIndex(where: { $0.id == currentExerciseId }) else {
            return
        }
        
        // Check if there's a next exercise
        let nextIndex = currentIndex + 1
        if nextIndex < session.exercises.count {
            let nextExercise = session.exercises[nextIndex]
            // Focus on the first set's reps field of the next exercise
            if let firstSet = nextExercise.sets.first {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusedField = .reps(exerciseId: nextExercise.id, setId: firstSet.id)
                }
            }
        } else {
            // We're at the last exercise, dismiss keyboard
            focusedField = nil
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
            // Filter out exercises that have no valid sets
            var cleanedSession = session
            cleanedSession.exercises = session.exercises.filter { exercise in
                // Keep exercise only if it has at least one set with reps > 0
                exercise.sets.contains { $0.reps > 0 }
            }
            
            // Only save if there's at least one valid exercise
            if !cleanedSession.exercises.isEmpty {
                onSave(cleanedSession)
            }
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
    let exerciseId: UUID
    @FocusState.Binding var focusedField: WorkoutSessionView.FocusedField?
    
    var body: some View {
        HStack {
            TextField("Reps", text: repsBinding)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .reps(exerciseId: exerciseId, setId: set.id))
            
            TextField("Weight", text: weightBinding)
                .keyboardType(.decimalPad)
                .environment(\.locale, Locale(identifier: "en_US"))
                .focused($focusedField, equals: .weight(exerciseId: exerciseId, setId: set.id))
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
            get: {
                if set.weight == 0 {
                    return ""
                } else {
                    // Use the user's locale for display
                    let formatter = NumberFormatter()
                    formatter.numberStyle = .decimal
                    formatter.maximumFractionDigits = 2
                    formatter.minimumFractionDigits = 0
                    return formatter.string(from: NSNumber(value: set.weight)) ?? String(format: "%.2f", set.weight)
                }
            },
            set: { newValue in
                // Replace comma with period for parsing
                let normalizedValue = newValue.replacingOccurrences(of: ",", with: ".")
                if let value = Double(normalizedValue) {
                    // Round to 2 decimal places
                    set.weight = round(value * 100) / 100
                } else {
                    set.weight = 0
                }
            }
        )
    }
}

struct FormButton: View {
    let form: ExerciseForm
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: form.icon)
                    .font(.caption)
                Text(form.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? form.color.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? form.color : .secondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? form.color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
