//
//  WorkoutHistoryView.swift
//  TrainingLogV2
//
//  Created by Michael Woodvine on 03.12.25.
//
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
            VStack(alignment: .leading, spacing: 0) {
                ForEach(exercisesGrouped.keys.sorted(), id: \.self) { exerciseName in
                    ExerciseHistorySection(
                        exerciseName: exerciseName,
                        records: exercisesGrouped[exerciseName] ?? [],
                        template: template,
                        store: store
                    )
                }
            }
        }
        .navigationTitle("\(template.name) History")
    }
}

struct ExerciseHistorySection: View {
    let exerciseName: String
    let records: [(WorkoutSession, Exercise)]
    let template: WorkoutTemplate
    @ObservedObject var store: WorkoutStore
    
    private var chartData: [(Date, Double)] {
        records.map { session, exercise in
            let weights = exercise.sets.map { $0.weight }
            let maxWeight = weights.max() ?? 0
            return (session.date, maxWeight)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exerciseName)
                .font(.title2)
                .bold()
                .padding(.top, 10)
            
            ExerciseProgressChart(data: chartData)
            
            ForEach(records, id: \.0.id) { session, exercise in
                SessionHistoryRow(
                    session: session,
                    exercise: exercise,
                    template: template,
                    store: store
                )
            }
            
            Divider()
        }
        .padding(.horizontal)
    }
}

struct ExerciseProgressChart: View {
    let data: [(Date, Double)]
    
    var body: some View {
        Chart(data, id: \.0) { point in
            LineMark(
                x: .value("Date", point.0),
                y: .value("Max Weight", point.1)
            )
            .interpolationMethod(.catmullRom)
            
            PointMark(
                x: .value("Date", point.0),
                y: .value("Max Weight", point.1)
            )
        }
        .frame(height: 200)
    }
}

struct SessionHistoryRow: View {
    let session: WorkoutSession
    let exercise: Exercise
    let template: WorkoutTemplate
    @ObservedObject var store: WorkoutStore
    
    var body: some View {
        NavigationLink(destination: destinationView) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Date: \(session.date.formatted(date: .numeric, time: .omitted))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ForEach(exercise.sets) { set in
                    SetDetailRow(set: set)
                }
            }
            .padding(.vertical, 4)
        }
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
        HStack {
            Text("Reps: \(set.reps)")
            Spacer()
            Text("Weight: \(set.weight, specifier: "%.1f") kg")
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}
