import SwiftUI
import Charts

struct WorkoutHistoryView: View {
    let template: WorkoutTemplate
    @ObservedObject var store: WorkoutStore
    
    private var exercisesGrouped: [String: [(WorkoutSession, Exercise)]] {
        var dict: [String: [(WorkoutSession, Exercise)]] = [:]
        for session in store.sessions(for: template) {
            for exercise in session.exercises {
                dict[exercise.name, default: []].append((session, exercise))
            }
        }
        return dict
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(exercisesGrouped.keys.sorted(), id: \.self) { exerciseName in
                    ExerciseHistorySection(
                        exerciseName: exerciseName,
                        records: exercisesGrouped[exerciseName] ?? [],
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
    let records: [(WorkoutSession, Exercise)]
    let template: WorkoutTemplate
    @ObservedObject var store: WorkoutStore
    
    @State private var showAllRecords = false
    
    private var sortedRecords: [(WorkoutSession, Exercise)] {
        records.sorted { $0.0.date > $1.0.date }
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
            Text(exerciseName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
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
                        store: store
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
    
    private var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: session.date)
    }
    
    var body: some View {
        NavigationLink(destination: destinationView) {
            VStack(alignment: .leading, spacing: 0) {
                // Date and Time Header
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formattedDateTime)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
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
        WorkoutSessionView(template: template, existingSession: session) { updatedSession in
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
