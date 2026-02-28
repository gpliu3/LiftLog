import Foundation

struct CSVFilePayload {
    let content: String
    let fileURL: URL
}

enum CSVDocumentWriter {
    static func writeCSVFile(content: String, filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        // Excel handles UTF-8 reliably when a BOM is present and rows use CRLF.
        let normalizedContent = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "\r\n")

        var data = Data([0xEF, 0xBB, 0xBF])
        guard let csvData = normalizedContent.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        data.append(csvData)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

enum WorkoutHistoryCSVExporter {
    private static let header = [
        "date",
        "time",
        "exercise_name",
        "muscle_group",
        "exercise_type",
        "set_number",
        "weight_kg",
        "reps",
        "duration_seconds",
        "rir",
        "notes",
        "volume_kg"
    ].joined(separator: ",")

    static func makeCSV(from sets: [WorkoutSet]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")

        var lines: [String] = [header]

        for set in sets.sorted(by: WorkoutSet.trainingOrder(lhs:rhs:)) {
            let exercise = set.exercise
            let row: [String] = [
                dateFormatter.string(from: set.date),
                timeFormatter.string(from: set.date),
                CSVDocumentWriter.csvEscape(exercise?.displayName ?? ""),
                CSVDocumentWriter.csvEscape(exercise?.localizedMuscleGroup ?? ""),
                CSVDocumentWriter.csvEscape(exercise?.exerciseType ?? ""),
                "\(set.setNumber)",
                String(format: "%.2f", set.weightKg),
                "\(set.reps)",
                "\(set.durationSeconds)",
                set.rir.map(String.init) ?? "",
                CSVDocumentWriter.csvEscape(set.notes),
                String(format: "%.2f", set.volume)
            ]
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }
}

enum ExerciseLibraryCSVExporter {
    private static let header = [
        "exercise_id",
        "exercise_name",
        "display_name",
        "muscle_group",
        "muscle_group_display",
        "exercise_type",
        "exercise_type_display",
        "user_notes",
        "display_notes",
        "created_at",
        "last_trained_date",
        "times_performed",
        "total_sets"
    ].joined(separator: ",")

    static func makeCSV(from exercises: [Exercise]) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        var lines: [String] = [header]

        for exercise in exercises.sorted(by: ExerciseLibraryCSVExporter.sortExercises(lhs:rhs:)) {
            let row: [String] = [
                exercise.id.uuidString,
                CSVDocumentWriter.csvEscape(exercise.name),
                CSVDocumentWriter.csvEscape(exercise.displayName),
                CSVDocumentWriter.csvEscape(exercise.muscleGroup),
                CSVDocumentWriter.csvEscape(exercise.localizedMuscleGroup),
                CSVDocumentWriter.csvEscape(exercise.exerciseType),
                CSVDocumentWriter.csvEscape(exercise.localizedExerciseType),
                CSVDocumentWriter.csvEscape(exercise.notes),
                CSVDocumentWriter.csvEscape(exercise.displayNotes),
                dateFormatter.string(from: exercise.createdAt),
                exercise.lastTrainedDate.map(dateFormatter.string(from:)) ?? "",
                "\(exercise.timesPerformed)",
                "\(exercise.workoutSets.count)"
            ]
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    private static func sortExercises(lhs: Exercise, rhs: Exercise) -> Bool {
        if lhs.muscleGroup != rhs.muscleGroup {
            return lhs.muscleGroup.localizedStandardCompare(rhs.muscleGroup) == .orderedAscending
        }
        if lhs.displayName != rhs.displayName {
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
        return lhs.createdAt < rhs.createdAt
    }
}
