import SwiftUI
import SwiftData

extension Color {
    /// Marks exercises (and the days they were done) that the user flagged as knee load.
    static let kneeLoad = Color.purple
}

extension DailyCheckIn.Level {
    var color: Color {
        switch self {
        case .good: return .green
        case .fair: return .yellow
        case .poor: return .red
        }
    }
}

/// "Knee 8" capsule, coloured by how the knee felt.
struct KneeScoreBadge: View {
    let score: Int
    /// False where a "Knee" title already sits beside the badge.
    var showsLabel = true
    var font: Font = AppTextStyle.caption2Strong

    var body: some View {
        let color = DailyCheckIn.level(for: score).color
        Text(showsLabel ? "knee.scoreBadge".localized(with: score) : "\(score)/\(DailyCheckIn.scoreRange.upperBound)")
            .font(font)
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.22))
            .overlay(Capsule().stroke(color.opacity(0.7), lineWidth: 1))
            .clipShape(Capsule())
            .foregroundStyle(.primary)
            .accessibilityLabel("knee.scoreAccessibility".localized(with: score))
    }
}

/// Small "Knee load" marker for a day that includes a flagged exercise.
struct KneeLoadBadge: View {
    var body: some View {
        Text("knee.loadBadge".localized)
            .font(AppTextStyle.caption2Strong)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.kneeLoad.opacity(0.15))
            .foregroundStyle(Color.kneeLoad)
            .clipShape(Capsule())
    }
}

/// Score badge followed by the day's symptom tags, for History rows.
struct KneeCheckInSummaryLine: View {
    let checkIn: DailyCheckIn

    var body: some View {
        if checkIn.kneeScore != nil || !checkIn.kneeTags.isEmpty {
            HStack(spacing: 6) {
                if let score = checkIn.kneeScore {
                    KneeScoreBadge(score: score)
                }
                if !checkIn.kneeTags.isEmpty {
                    Text(checkIn.kneeTags.map(\.localizedName).joined(separator: " · "))
                        .font(AppTextStyle.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }
}

/// The day's note as shown in History rows.
struct DayNoteBubble: View {
    let note: String

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "exclamationmark.bubble.fill")
                .font(AppTextStyle.caption2Strong)
                .foregroundStyle(.orange)
                .padding(.top, 2)

            Text(note)
                .font(AppTextStyle.captionStrong)
                .foregroundStyle(Color.orange.opacity(0.95))
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Daily knee check-in: a 1–10 score, symptom tags and the day's note.
/// Collapsed it is just the score row; expanding reveals tags and the note.
struct KneeCheckInCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var logs: [DailyLog]

    let day: Date
    /// Note saved with that day's sets by earlier versions; shown until a check-in exists.
    let legacyNote: String

    @State private var draft = DailyCheckIn()
    @State private var hasLoaded = false
    @State private var isExpanded: Bool
    @FocusState private var isNoteFocused: Bool

    init(day: Date, legacyNote: String, startsExpanded: Bool = false) {
        let dayStart = Calendar.current.startOfDay(for: day)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        self.day = dayStart
        self.legacyNote = legacyNote
        _isExpanded = State(initialValue: startsExpanded)
        _logs = Query(
            filter: #Predicate<DailyLog> { $0.day >= dayStart && $0.day < dayEnd },
            sort: \DailyLog.updatedAt,
            order: .reverse
        )
    }

    private var stored: DailyCheckIn {
        logs.first?.checkIn ?? DailyCheckIn(note: legacyNote)
    }

    private var collapsedDetail: String {
        var parts = draft.kneeTags.map(\.localizedName)
        if let firstLine = draft.trimmedNote.split(whereSeparator: \.isNewline).first {
            parts.append(String(firstLine))
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            scoreRow

            if isExpanded {
                tagGrid
                noteEditor
            } else if !collapsedDetail.isEmpty {
                Text(collapsedDetail)
                    .font(AppTextStyle.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.snappy(duration: 0.2)) { isExpanded = true } }
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            draft = stored
        }
        .onChange(of: stored) { _, newValue in
            if !isNoteFocused { draft = newValue }
        }
        .onChange(of: isNoteFocused) { _, focused in
            if !focused { persist() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active { persist() }
        }
        .onDisappear { persist() }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("knee.title".localized)
                .font(AppTextStyle.subheadlineStrong)
            if let score = draft.kneeScore {
                KneeScoreBadge(score: score, showsLabel: false)
            } else {
                Text("knee.scoreHint".localized)
                    .font(AppTextStyle.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            Button {
                withAnimation(.snappy(duration: 0.2)) { isExpanded.toggle() }
                if !isExpanded { isNoteFocused = false }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(AppTextStyle.captionStrong)
                    .frame(width: 30, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .tint(.secondary)
            .accessibilityLabel((isExpanded ? "knee.collapse" : "knee.expand").localized)
        }
    }

    private var scoreRow: some View {
        HStack(spacing: 4) {
            ForEach(Array(DailyCheckIn.scoreRange), id: \.self) { score in
                let isSelected = draft.kneeScore == score
                Button {
                    draft.kneeScore = isSelected ? nil : score
                    persist()
                } label: {
                    Text("\(score)")
                        .font(AppTextStyle.captionStrong)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? DailyCheckIn.level(for: score).color.opacity(0.85) : Color(.tertiarySystemFill))
                        )
                        .foregroundStyle(isSelected ? Color.black : Color.primary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("knee.scoreAccessibility".localized(with: score))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var tagGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(KneeTag.allCases) { tag in
                let isSelected = draft.kneeTags.contains(tag)
                Button {
                    if isSelected {
                        draft.kneeTags.removeAll { $0 == tag }
                    } else {
                        draft.kneeTags.append(tag)
                    }
                    persist()
                } label: {
                    Text(tag.localizedName)
                        .font(AppTextStyle.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .padding(.horizontal, 6)
                        .background(
                            Capsule().fill(isSelected ? Color.orange.opacity(0.2) : Color(.tertiarySystemFill))
                        )
                        .overlay(Capsule().stroke(isSelected ? Color.orange : Color.clear, lineWidth: 1))
                        .foregroundStyle(Color.primary)
                }
                .buttonStyle(.borderless)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var noteEditor: some View {
        TextEditor(text: $draft.note)
            .font(AppTextStyle.body)
            .frame(minHeight: 72)
            .focused($isNoteFocused)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 4)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .topLeading) {
                if draft.trimmedNote.isEmpty {
                    Text("dayNote.placeholder".localized)
                        .font(AppTextStyle.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 9)
                        .allowsHitTesting(false)
                }
            }
    }

    /// Writes only real changes, so opening a day never creates an empty record.
    private func persist() {
        guard hasLoaded else { return }
        var cleaned = draft
        cleaned.note = draft.trimmedNote
        var current = stored
        current.note = current.trimmedNote
        guard cleaned != current else { return }
        do {
            try DailyLog.save(cleaned, for: day, in: modelContext)
        } catch {
            assertionFailure("Failed to save knee check-in: \(error)")
        }
    }
}
