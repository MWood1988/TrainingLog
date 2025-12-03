//
//  ContentView.swift
//  TrainingLogV2
//
//  Created by Michael Woodvine on 03.12.25.
//
import SwiftUI

struct ContentView: View {
    @StateObject private var store = WorkoutStore()
    @State private var showingNewTemplate = false
    @State private var editMode = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(store.templates) { template in
                        templateRow(for: template)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    editButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    addButton
                }
            }
            .sheet(isPresented: $showingNewTemplate) {
                NewWorkoutTemplateView { template in
                    store.addTemplate(template)
                    showingNewTemplate = false
                }
            }
        }
    }
    
    private func templateRow(for template: WorkoutTemplate) -> some View {
        HStack(spacing: 12) {
            if editMode {
                deleteButton(for: template)
                    .transition(.scale)
            }
            WorkoutTemplateCard(template: template, store: store)
        }
        .padding(.horizontal)
        .animation(.default, value: editMode)
    }
    
    private func deleteButton(for template: WorkoutTemplate) -> some View {
        Button {
            if let index = store.templates.firstIndex(where: { $0.id == template.id }) {
                store.deleteTemplate(at: IndexSet(integer: index))
            }
        } label: {
            Image(systemName: "minus.circle.fill")
                .foregroundColor(.red)
                .font(.title2)
        }
    }
    
    private var editButton: some View {
        Button(editMode ? "Done" : "Edit") {
            editMode.toggle()
        }
    }
    
    private var addButton: some View {
        Button {
            showingNewTemplate = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title)
        }
    }
}
