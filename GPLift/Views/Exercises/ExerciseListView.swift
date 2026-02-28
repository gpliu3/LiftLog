import SwiftUI
import SwiftData
import UIKit

struct ExerciseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var languageManager = LanguageManager.shared

    @State private var searchText = ""
    @State private var showingAddExercise = false
    @State private var showingExportSheet = false
    @State private var selectedExercise: Exercise?
    @State private var quickAddExercise: Exercise?

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercises
        }
        return exercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.muscleGroup.localizedCaseInsensitiveContains(searchText) ||
            $0.localizedMuscleGroup.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedExercises: [(String, [Exercise])] {
        let grouped = Dictionary(grouping: filteredExercises) { exercise in
            exercise.muscleGroup.isEmpty ? "Other" : exercise.muscleGroup
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            Group {
                if exercises.isEmpty {
                    emptyState
                } else {
                    exerciseList
                }
            }
            .navigationTitle("exercises.title".localized)
            .font(AppTextStyle.body)
            .searchable(text: $searchText, prompt: "exercises.search".localized)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingExportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("exercises.export".localized)

                    Button {
                        showingAddExercise = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                ExerciseEditView(exercise: nil)
            }
            .sheet(item: $selectedExercise) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
            .sheet(item: $quickAddExercise) { exercise in
                AddSetView(preselectedExercise: exercise)
            }
            .sheet(isPresented: $showingExportSheet) {
                ExerciseExportView(exercises: exercises)
            }
        }
        .id(languageManager.currentLanguage)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "exercises.noExercises".localized,
            systemImage: "dumbbell",
            description: Text("exercises.noExercisesDescription".localized)
        )
    }

    private var exerciseList: some View {
        List {
            ForEach(groupedExercises, id: \.0) { muscleGroup, exercises in
                Section(Exercise.localizedMuscleGroupName(for: muscleGroup)) {
                    ForEach(exercises) { exercise in
                        ExerciseRowView(
                            exercise: exercise,
                            onQuickAdd: { quickAddExercise = exercise }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedExercise = exercise
                        }
                    }
                    .onDelete { indexSet in
                        deleteExercises(at: indexSet, from: exercises)
                    }
                }
            }
        }
        .environment(\.defaultMinListRowHeight, 24)
    }

    private func deleteExercises(at offsets: IndexSet, from exercises: [Exercise]) {
        for index in offsets {
            modelContext.delete(exercises[index])
        }
    }
}

private struct ExerciseExportView: View {
    @Environment(\.dismiss) private var dismiss

    let exercises: [Exercise]

    @State private var exportedCSV = ""
    @State private var exportedFileURL: URL?
    @State private var copied = false
    @State private var exportError = false

    private var notesCount: Int {
        exercises.filter { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    private var exportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "gplift_exercises_\(formatter.string(from: Date())).csv"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("history.export.preview".localized) {
                    HStack {
                        Label("history.export.exercises".localized, systemImage: "dumbbell")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(exercises.count)")
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Label("exercises.export.notes".localized, systemImage: "note.text")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(notesCount)")
                            .fontWeight(.semibold)
                    }
                }

                Section {
                    if let url = exportedFileURL, !exercises.isEmpty {
                        ShareLink(item: url) {
                            Label("history.export.share".localized, systemImage: "square.and.arrow.up")
                        }

                        Button {
                            UIPasteboard.general.string = exportedCSV
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copied = false
                            }
                        } label: {
                            Label("history.export.copy".localized, systemImage: "doc.on.doc")
                        }

                        if copied {
                            Text("history.export.copied".localized)
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    Text("history.export.actions".localized)
                } footer: {
                    Text("history.export.footer".localized)
                }
            }
            .navigationTitle("exercises.export.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                refreshExportPayload()
            }
            .alert("history.export.errorTitle".localized, isPresented: $exportError) {
                Button("common.done".localized, role: .cancel) {}
            } message: {
                Text("history.export.errorMessage".localized)
            }
        }
    }

    private func refreshExportPayload() {
        copied = false
        guard !exercises.isEmpty else {
            exportedCSV = ""
            exportedFileURL = nil
            return
        }

        let csv = ExerciseLibraryCSVExporter.makeCSV(from: exercises)
        do {
            exportedFileURL = try CSVDocumentWriter.writeCSVFile(content: csv, filename: exportFilename)
            exportedCSV = csv
        } catch {
            exportedFileURL = nil
            exportedCSV = ""
            exportError = true
        }
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise
    let onQuickAdd: () -> Void

    private var lastTrainedLabel: String {
        guard let lastTrained = exercise.lastTrainedDate else {
            return "addSet.neverTrained".localized
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(lastTrained) {
            return "addSet.lastTrainedTodayWithDays".localized
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = LanguageManager.shared.currentLanguage.locale ?? Locale.current
        return "addSet.lastTrainedWithRelative".localized(
            with: formatter.string(from: lastTrained),
            daysAgoText(for: lastTrained)
        )
    }

    private func daysAgoText(for date: Date) -> String {
        let calendar = Calendar.current
        let fromDay = calendar.startOfDay(for: date)
        let toDay = calendar.startOfDay(for: Date())
        let days = max(0, calendar.dateComponents([.day], from: fromDay, to: toDay).day ?? 0)

        if days == 1 {
            return "addSet.daysAgo.one".localized
        }
        return "addSet.daysAgo.other".localized(with: days)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.displayName)
                    .font(AppTextStyle.sectionTitle)

                Text(lastTrainedLabel)
                    .font(AppTextStyle.caption2)
                    .foregroundStyle(.secondary)

                if !exercise.displayNotes.isEmpty {
                    Text(exercise.displayNotes)
                        .font(AppTextStyle.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if exercise.timesPerformed > 0 {
                    Text("exercises.sessions".localized(with: exercise.timesPerformed))
                        .font(AppTextStyle.caption)
                        .foregroundStyle(.secondary)
                }

                if !exercise.muscleGroup.isEmpty {
                    Text(exercise.localizedMuscleGroup)
                        .font(AppTextStyle.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .cornerRadius(4)
                }

                Button {
                    onQuickAdd()
                } label: {
                    Label("exercises.quickAdd".localized, systemImage: "plus.circle.fill")
                        .font(AppTextStyle.caption2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 0)
    }
}

#Preview {
    ExerciseListView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}
