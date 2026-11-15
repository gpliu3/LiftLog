import Foundation

/// Order of exercise sections within one training day (Today and History day detail).
///
/// Sections are grouped by category, then the most recently *started* exercise comes first.
/// Ordering by start time (the earliest set of the day) rather than the latest set keeps each
/// exercise in place while more sets are added, so the list never reshuffles under the user.
enum DayExerciseOrder {
    static func sorted<Sets>(
        _ groups: [(Exercise, Sets)],
        setDates: (Sets) -> [Date]
    ) -> [(Exercise, Sets)] {
        groups
            .map { group in (group: group, start: setDates(group.1).min() ?? .distantPast) }
            .sorted { lhs, rhs in
                let lhsExercise = lhs.group.0
                let rhsExercise = rhs.group.0
                if lhsExercise.resolvedCategory != rhsExercise.resolvedCategory {
                    return lhsExercise.resolvedCategory.sortOrder < rhsExercise.resolvedCategory.sortOrder
                }
                if lhs.start != rhs.start { return lhs.start > rhs.start }
                if lhsExercise.displayName != rhsExercise.displayName {
                    return lhsExercise.displayName < rhsExercise.displayName
                }
                return lhsExercise.id.uuidString < rhsExercise.id.uuidString
            }
            .map(\.group)
    }
}

enum ExerciseOrdering: String, CaseIterable, Identifiable {
    case due
    case standard
    /// The user's own drag-and-drop order for groups and exercises.
    case custom

    var id: String { rawValue }
    var localizedName: String { "addSet.sort.\(rawValue)".localized }

    func precedes(_ lhs: Exercise, _ rhs: Exercise, lastTrainedDates: [UUID: Date]) -> Bool {
        if self == .custom, let order = Self.comparePositions(lhs.customOrder, rhs.customOrder) {
            return order
        }
        if self == .due,
           let dateOrder = Self.compareDates(lastTrainedDates[lhs.id], lastTrainedDates[rhs.id]) {
            return dateOrder
        }
        let nameOrder = lhs.displayName.localizedStandardCompare(rhs.displayName)
        if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    func groupPrecedes(_ lhs: String, _ rhs: String, lhsDate: Date?, rhsDate: Date?) -> Bool {
        if self == .due, let dateOrder = Self.compareDates(lhsDate, rhsDate) {
            return dateOrder
        }
        return Self.standardGroupPrecedes(lhs, rhs)
    }

    static func standardGroupPrecedes(_ lhs: String, _ rhs: String) -> Bool {
        let lhsIndex = Exercise.muscleGroups.firstIndex(of: lhs) ?? Exercise.muscleGroups.count
        let rhsIndex = Exercise.muscleGroups.firstIndex(of: rhs) ?? Exercise.muscleGroups.count
        if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
        return lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    /// Custom group order: groups the user has placed come first in their saved order;
    /// groups never placed keep the standard order after them.
    static func customGroupPrecedes(_ lhs: String, _ rhs: String, savedOrder: [String]) -> Bool {
        if let order = comparePositions(savedOrder.firstIndex(of: lhs), savedOrder.firstIndex(of: rhs)) {
            return order
        }
        return standardGroupPrecedes(lhs, rhs)
    }

    /// Moves one item within `items` the way SwiftUI's `onMove` reports it.
    static func moved<Item>(_ items: [Item], from source: IndexSet, to destination: Int) -> [Item] {
        var result = items
        let picked = source.sorted().map { result[$0] }
        for index in source.sorted(by: >) { result.remove(at: index) }
        let insertAt = destination - source.filter { $0 < destination }.count
        result.insert(contentsOf: picked, at: min(max(insertAt, 0), result.count))
        return result
    }

    /// Placed items come before unplaced ones; nil when the positions do not decide the order.
    private static func comparePositions(_ lhs: Int?, _ rhs: Int?) -> Bool? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?) where lhs != rhs: return lhs < rhs
        case (_?, nil): return true
        case (nil, _?): return false
        default: return nil
        }
    }

    private static func compareDates(_ lhs: Date?, _ rhs: Date?) -> Bool? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?) where lhs != rhs: return lhs < rhs
        case (_?, nil): return true
        case (nil, _?): return false
        default: return nil
        }
    }
}
