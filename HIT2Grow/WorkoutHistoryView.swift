import SwiftUI
import Charts

struct WorkoutHistoryView: View {
    let template: WorkoutTemplate
    @ObservedObject var store: WorkoutStore
    
    private var exerciseSections: [(exerciseName: String, exerciseId: UUID, records: [(WorkoutSession, Exercise)])] {
        // Build sections for each exercise in the template
        return template.exercises.map { exerciseTemplate in
            // Get all sessions from THIS template that include this exercise
            let records = store.sessions(for: template)
                .flatMap { session -> [(WorkoutSession, Exercise)] in
                    session.exercises
                        .filter { $0.exerciseId == exerciseTemplate.exerciseId }
                        .map { (session, $0) }
                }
            
            return (
                exerciseName: exerciseTemplate.name,
                exerciseId: exerciseTemplate.exerciseId,
                records: records
            )
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(exerciseSections, id: \.exerciseId) { section in
                    ExerciseHistorySection(
                        exerciseName: section.exerciseName,
                        exerciseId: section.exerciseId,
                        records: section.records,
                        template: template,
                        store: store
                    )
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("\(template.name) History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ExerciseHistorySection: View {
    let exerciseName: String
    let exerciseId: UUID
    let records: [(WorkoutSession, Exercise)]
    let template: WorkoutTemplate
    @ObservedObject var store: WorkoutStore
    
    @State private var showAllRecords = false
    
    // Get all sessions for this exercise across ALL templates
    private var allRecords: [(WorkoutSession, Exercise)] {
        store.sessions(for: exerciseId)
    }
    
    private var sortedRecords: [(WorkoutSession, Exercise)] {
        allRecords.sorted { $0.0.date > $1.0.date }
    }
    
    private var displayedRecords: [(WorkoutSession, Exercise)] {
        if showAllRecords || sortedRecords.count <= 3 {
            return sortedRecords
        } else {
            return Array(sortedRecords.prefix(3))
        }
    }
    
    private var chartData: [(Date, Double)] {
        sortedRecords.map { session, exercise in
            let weights = exercise.sets.map { $0.weight }
            let maxWeight = weights.max() ?? 0
            return (session.date, maxWeight)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise Header
            HStack {
                Text(exerciseName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Total sessions info
            Text("\(allRecords.count) total session\(allRecords.count == 1 ? "" : "s") across all workouts")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Show content or empty state
            if sortedRecords.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No sessions recorded yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Start a workout to see your progress here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                // Progress Chart
                ExerciseProgressChart(data: chartData)
                    .padding(.bottom, 8)
                
                // Session Records
                VStack(spacing: 12) {
                    ForEach(displayedRecords, id: \.0.id) { session, exercise in
                        SessionHistoryRow(
                            session: session,
                            exercise: exercise,
                            template: template,
                            store: store,
                            showTemplateName: true
                        )
                    }
                }
                
                // Show More/Less Button
                if sortedRecords.count > 3 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAllRecords.toggle()
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text(showAllRecords ? "Show Less" : "Show More (\(sortedRecords.count - 3) older)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: showAllRecords ? "chevron.up" : "chevron.down")
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    .padding(.top, 4)
                }
            }
            
            // Section Divider
            Divider()
                .padding(.top, 8)
        }
        .padding(.horizontal)
    }
}

struct ExerciseProgressChart: View {
    let data: [(Date, Double)]
    
    private var indexedData: [(Int, Double)] {
        data.enumerated().map { (index, point) in
            (index + 1, point.1)
        }
    }
    
    private var xAxisRange: ClosedRange<Int> {
        let maxWorkout = indexedData.map { $0.0 }.max() ?? 1
        return 1...(maxWorkout + 1)
    }
    
    private var yAxisRange: ClosedRange<Double> {
        let weights = indexedData.map { $0.1 }
        guard let minWeight = weights.min(), let maxWeight = weights.max() else {
            return 0...100
        }
        
        let range = maxWeight - minWeight
        let padding = range > 0 ? range * 0.1 : 5.0
        let lowerBound = max(0, minWeight - padding)
        let upperBound = maxWeight + padding
        
        // Ensure we have a valid range (upperBound must be > lowerBound)
        if upperBound <= lowerBound {
            return 0...100
        }
        
        return lowerBound...upperBound
    }
    
    var body: some View {
        Chart(indexedData, id: \.0) { point in
            LineMark(
                x: .value("Workout", point.0),
                y: .value("Max Weight", point.1)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(.blue)
            
            PointMark(
                x: .value("Workout", point.0),
                y: .value("Max Weight", point.1)
            )
            .foregroundStyle(.blue)
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                if let intValue = value.as(Int.self) {
                    AxisValueLabel {
                        Text("\(intValue)")
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel()
                AxisGridLine()
            }
        }
        .chartXScale(domain: xAxisRange)
        .chartYScale(domain: yAxisRange)
        .frame(height: 200)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SessionHistoryRow: View {
    let session: WorkoutSession
    let exercise: Exercise
    let template: WorkoutTemplate
    @ObservedObject var store: WorkoutStore
    let showTemplateName: Bool
    
    private var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: session.date)
    }
    
    private var sessionTemplateName: String {
        store.templates.first(where: { $0.id == session.templateId })?.name ?? "Unknown"
    }
    
    var body: some View {
        NavigationLink(destination: destinationView) {
            VStack(alignment: .leading, spacing: 0) {
                // Date and Time Header with Intensity
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formattedDateTime)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            if showTemplateName {
                                Text(sessionTemplateName)
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Add form badge
                    HStack(spacing: 4) {
                        Image(systemName: exercise.form.icon)
                            .font(.caption)
                        Text(exercise.form.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(exercise.form.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(exercise.form.color.opacity(0.15))
                    .cornerRadius(6)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray5))
                .cornerRadius(8, corners: [.topLeft, .topRight])
                
                // Sets Details
                VStack(spacing: 6) {
                    ForEach(exercise.sets) { set in
                        SetDetailRow(set: set)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .cornerRadius(8, corners: [.bottomLeft, .bottomRight])
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var destinationView: some View {
        // Get the actual template for this session
        let sessionTemplate = store.templates.first(where: { $0.id == session.templateId }) ?? template
        return WorkoutSessionView(template: sessionTemplate, existingSession: session) { updatedSession in
            store.updateSession(updatedSession)
        }
    }
}

struct SetDetailRow: View {
    let set: ExerciseSet
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "repeat")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .frame(width: 16)
                Text("\(set.reps) reps")
                    .font(.subheadline)
            }
            
            Spacer()
            
            HStack {
                Image(systemName: "scalemass")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .frame(width: 16)
                Text("\(set.weight, specifier: "%.1f") kg")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.primary)
    }
}
// Extension for selective corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
