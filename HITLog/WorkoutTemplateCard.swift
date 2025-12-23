import SwiftUI

struct WorkoutTemplateCard: View {
    let template: WorkoutTemplate
    @ObservedObject var store: WorkoutStore
    @State private var isPressed = false
    @State private var navigationID = UUID()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            accentBar
            templateTitle
            actionButtons
        }
        .padding()
        .background(cardBackground)
        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .gesture(pressGesture)
    }
    
    private var accentBar: some View {
        Rectangle()
            .fill(Color.blue)
            .frame(height: 5)
            .cornerRadius(2.5)
    }
    
    private var templateTitle: some View {
        Text(template.name)
            .font(.title2)
            .fontWeight(.bold)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            historyButton
            startWorkoutButton
        }
    }
    
    private var historyButton: some View {
        NavigationLink(destination: WorkoutHistoryView(template: template, store: store)) {
            ActionButton(
                icon: "clock",
                title: "View History",
                color: .blue
            )
        }
        .frame(maxWidth: .infinity)
    }
    
    private var startWorkoutButton: some View {
        NavigationLink(destination:
            WorkoutSessionView(template: template, store: store) { newSession in
                store.addSession(newSession)
                // Generate new ID to force view recreation next time
                navigationID = UUID()
            }
            .id(navigationID)
        ) {
            ActionButton(
                icon: "play.fill",
                title: "Log Workout",
                color: .green
            )
        }
        .frame(maxWidth: .infinity)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(UIColor.secondarySystemBackground))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var pressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.1)
            .onChanged { _ in isPressed = true }
            .onEnded { _ in isPressed = false }
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(10)
    }
}
