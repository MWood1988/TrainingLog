import SwiftUI

struct WorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: WorkoutSession
    @State private var hasLoadedDraft: Bool = false // Track if we've already loaded the draft this session
    @FocusState private var focusedField: FocusedField?
    @State private var showingNotesFor: UUID?
    @State private var showingResetAlert = false
    @State private var lastFocusedField: FocusedField? // Track last focused field for restoration
    @ObservedObject var store: WorkoutStore
    
    let template: WorkoutTemplate
    let onSave: (WorkoutSession) -> Void
    let isViewingExisting: Bool
    
    // Static storage for last focused field per template (persists across view recreation)
    private static var savedFocusedFields: [UUID: FocusedField] = [:]
    
    enum FocusedField: Hashable {
        case reps(exerciseId: UUID, setId: UUID)
        case weight(exerciseId: UUID, setId: UUID)
    }
    
    init(template: WorkoutTemplate, store: WorkoutStore, existingSession: WorkoutSession? = nil, onSave: @escaping (WorkoutSession) -> Void) {
        self.template = template
        self.store = store
        self.isViewingExisting = existingSession != nil
        if let existing = existingSession {
            _session = State(initialValue: existing)
            _hasLoadedDraft = State(initialValue: true) // Don't load drafts for existing sessions
        } else {
            // Start with empty session - draft will be loaded in onAppear
            let exercises = template.exercises.map { exTemplate in
                Exercise(exerciseId: exTemplate.exerciseId, name: exTemplate.name, sets: [ExerciseSet(reps: 0, weight: 0)])
            }
            _session = State(initialValue: WorkoutSession(templateId: template.id, date: Date(), exercises: exercises))
            _hasLoadedDraft = State(initialValue: false) // Will load draft in onAppear
        }
        self.onSave = onSave
    }
    
    // Get the previous session data for a specific exercise
    private func previousSessionData(for exerciseId: UUID) -> Exercise? {
        // Get all sessions for this exercise, sorted by date (newest first)
        let exerciseSessions = store.sessions(for: exerciseId)
        
        // If we're viewing an existing session, find the one before it
        // Otherwise, just get the most recent one
        if isViewingExisting {
            // Find sessions before the current session date
            let previousSessions = exerciseSessions.filter { $0.0.date < session.date }
            return previousSessions.first?.1
        } else {
            // For new sessions, just get the most recent
            return exerciseSessions.first?.1
        }
    }
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            Form {
                Section {
                    DatePicker("Workout Date", selection: $session.date, displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: session.date) { _, _ in
                            saveDraft()
                        }
                }
                
                ForEach($session.exercises) { $exercise in
                    exerciseSection(for: $exercise)
                        .id(exercise.id)
                }
            }
            .contentShape(Rectangle()) // Make entire background tappable
            .onTapGesture {
                // Dismiss keyboard when tapping outside text fields
                focusedField = nil
            }
            .onAppear {
                // Restore focus to the last field the user was editing
                if let savedFocus = Self.savedFocusedFields[template.id] {
                    // First scroll to the exercise, then restore focus
                    switch savedFocus {
                    case .reps(let exerciseId, _), .weight(let exerciseId, _):
                        // Scroll to the exercise section first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                scrollProxy.scrollTo(exerciseId, anchor: .center)
                            }
                        }
                        // Then restore focus after scroll completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            focusedField = savedFocus
                        }
                    }
                }
            }
            .onDisappear {
                // Save the currently focused field
                if let currentFocus = focusedField {
                    Self.savedFocusedFields[template.id] = currentFocus
                } else if let lastFocus = lastFocusedField {
                    // If no current focus, use the last known focus
                    Self.savedFocusedFields[template.id] = lastFocus
                }
            }
            .onChange(of: focusedField) { _, newValue in
                // Track the last focused field even when focus is lost
                if let newFocus = newValue {
                    lastFocusedField = newFocus
                }
            }
        }
        .overlay(alignment: .trailing) {
            if let focused = focusedField {
                VStack(spacing: 8) {
                    switch focused {
                    case .reps(let exerciseId, let setId):
                        // Enter button (move to weight)
                        Button(action: {
                            focusedField = .weight(exerciseId: exerciseId, setId: setId)
                        }) {
                            Text("Enter")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 120)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                        // Next Exercise button
                        Button(action: {
                            jumpToNextExercise(from: exerciseId)
                        }) {
                            Text("Next Exercise")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 120)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                    case .weight(let exerciseId, let setId):
                        // Enter button (move to next set or add new set)
                        Button(action: {
                            // Find the exercise and current set
                            if let exerciseIndex = session.exercises.firstIndex(where: { $0.id == exerciseId }),
                               let setIndex = session.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }) {
                                
                                let isLastSet = setIndex == session.exercises[exerciseIndex].sets.count - 1
                                
                                if isLastSet {
                                    // This is the last set, add a new one
                                    let newSet = ExerciseSet(reps: 0, weight: 0)
                                    session.exercises[exerciseIndex].sets.append(newSet)
                                    saveDraft()
                                    
                                    // Focus on the reps field of the new set
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        focusedField = .reps(exerciseId: exerciseId, setId: newSet.id)
                                    }
                                } else {
                                    // Not the last set, move to the next set's reps field
                                    let nextSet = session.exercises[exerciseIndex].sets[setIndex + 1]
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        focusedField = .reps(exerciseId: exerciseId, setId: nextSet.id)
                                    }
                                }
                            }
                        }) {
                            Text("Enter")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 120)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                        // Next Exercise button
                        Button(action: {
                            jumpToNextExercise(from: exerciseId)
                        }) {
                            Text("Next Exercise")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 120)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
                .frame(maxHeight: .infinity)
                .padding(.trailing, 13)
                .offset(y: 160)
            }
        }
        .sheet(item: $showingNotesFor) { exerciseId in
            if let exercise = session.exercises.first(where: { $0.exerciseId == exerciseId }) {
                ExerciseNotesView(store: store, exerciseId: exerciseId, exerciseName: exercise.name)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: {
                    showingResetAlert = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset")
                    }
                    .font(.subheadline)
                    .foregroundColor(.orange)
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                saveButton
            }
            ToolbarItem(placement: .cancellationAction) {
                cancelButton
            }
        }
        .alert("Reset Workout", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetWorkout()
            }
        } message: {
            Text("Are you sure you want to reset this workout? All entered data will be cleared.")
        }
        .onDisappear {
            // Save draft when view disappears (navigating away) - only for new sessions
            if !isViewingExisting {
                saveDraft()
            }
        }
        .onAppear {
            // Load draft only once when view first appears (not on subsequent appears)
            if !isViewingExisting && !hasLoadedDraft {
                hasLoadedDraft = true
                if let draft = store.loadDraft(for: template.id) {
                    session = draft
                }
            }
        }
    }
    
    private func saveDraft() {
        // Only save drafts for new sessions, not when editing existing ones
        if !isViewingExisting {
            store.saveDraft(session)
        }
    }
    
    private func resetWorkout() {
        // Create fresh session with empty sets
        let exercises = template.exercises.map { exTemplate in
            Exercise(exerciseId: exTemplate.exerciseId, name: exTemplate.name, sets: [ExerciseSet(reps: 0, weight: 0)])
        }
        session = WorkoutSession(templateId: template.id, date: Date(), exercises: exercises)
        
        // Clear the draft
        store.clearDraft(for: template.id)
        
        // Save the empty draft (so it appears empty if they navigate away and come back)
        saveDraft()
    }
    
    private func exerciseSection(for exercise: Binding<Exercise>) -> some View {
        let hasValidSets = exercise.wrappedValue.sets.contains { $0.reps > 0 }
        let exerciseNotes = store.getExerciseNotes(exerciseId: exercise.wrappedValue.exerciseId)
        let hasNotes = !exerciseNotes.isEmpty
        let previousData = previousSessionData(for: exercise.wrappedValue.exerciseId)
        
        return Section(
            header: HStack {
                Text(exercise.wrappedValue.name)
                Spacer()
                // Info icon button
                Button(action: {
                    showingNotesFor = exercise.wrappedValue.exerciseId
                }) {
                    Image(systemName: hasNotes ? "info.circle.fill" : "info.circle")
                        .foregroundColor(hasNotes ? .blue : .secondary)
                        .font(.body)
                }
                .buttonStyle(.plain)
            },
            footer: VStack(alignment: .leading, spacing: 8) {
                if !hasValidSets {
                    Text("This exercise will not be saved (no reps recorded)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                // Previous workout data
                if let previous = previousData {
                    PreviousWorkoutDataView(exercise: previous)
                }
            }
        ) {
            ForEach(Array(exercise.wrappedValue.sets.enumerated()), id: \.element.id) { index, set in
                SetRowEditor(
                    set: exercise.sets[index],
                    exerciseId: exercise.wrappedValue.id,
                    focusedField: $focusedField,
                    onValueChange: saveDraft
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
                            saveDraft()
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    private func addSetButton(for exercise: Binding<Exercise>) -> some View {
        Button("Add Set") {
            var updatedExercise = exercise.wrappedValue
            updatedExercise.sets.append(ExerciseSet(reps: 0, weight: 0))
            exercise.wrappedValue = updatedExercise
            saveDraft()
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
        Button("Finish") {
            // Filter out empty sets and exercises
            var cleanedSession = session
            
            // For each exercise, remove sets where both reps and weight are zero
            cleanedSession.exercises = session.exercises.compactMap { exercise in
                var cleanedExercise = exercise
                cleanedExercise.sets = exercise.sets.filter { set in
                    // Keep set only if it has reps > 0 OR weight > 0
                    set.reps > 0 || set.weight > 0
                }
                
                // Only keep exercise if it has at least one valid set
                return cleanedExercise.sets.isEmpty ? nil : cleanedExercise
            }
            
            // Only save if there's at least one valid exercise
            if !cleanedSession.exercises.isEmpty {
                onSave(cleanedSession)
                // Note: clearDraft is now called inside addSession in WorkoutStore
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

// MARK: - Previous Workout Data View
struct PreviousWorkoutDataView: View {
    let exercise: Exercise
    
    private var formattedSets: String {
        exercise.sets.map { "\($0.reps) × \(formatWeight($0.weight))" }.joined(separator: "  •  ")
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight)) kg"
        } else {
            return String(format: "%.1f kg", weight)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption2)
                Text("Last workout:")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.secondary)
            
            Text(formattedSets)
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(.top, 4)
    }
}

struct SetRowEditor: View {
    @Binding var set: ExerciseSet
    let exerciseId: UUID
    @FocusState.Binding var focusedField: WorkoutSessionView.FocusedField?
    let onValueChange: () -> Void
    
    var body: some View {
        HStack {
            TextField("Reps", text: repsBinding)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .reps(exerciseId: exerciseId, setId: set.id))
            
            TextField("Weight", text: weightBinding)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .weight(exerciseId: exerciseId, setId: set.id))
        }
    }
    
    private var repsBinding: Binding<String> {
        Binding(
            get: { set.reps == 0 ? "" : String(set.reps) },
            set: { newValue in
                set.reps = Int(newValue) ?? 0
                onValueChange()
            }
        )
    }
    
    private var weightBinding: Binding<String> {
        Binding(
            get: {
                if set.weight == 0 {
                    return ""
                } else {
                    // Always format with period as decimal separator
                    return String(format: "%.2f", set.weight).replacingOccurrences(of: ".00", with: "")
                }
            },
            set: { newValue in
                // Accept both comma and period, but convert comma to period for parsing
                let normalizedValue = newValue.replacingOccurrences(of: ",", with: ".")
                if let value = Double(normalizedValue) {
                    // Round to 2 decimal places
                    set.weight = round(value * 100) / 100
                } else {
                    set.weight = 0
                }
                onValueChange()
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

// Make UUID Identifiable for sheet presentation
extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
