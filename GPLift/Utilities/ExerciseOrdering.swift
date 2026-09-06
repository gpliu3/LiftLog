import Foundation

enum ExerciseOrdering: String, CaseIterable, Identifiable {
    case due
    case standard

    var id: String { rawValue }
    var localizedName: String { "addSet.sort.\(rawValue)".localized }

    func precedes(_ lhs: Exercise, _ rhs: Exercise, lastTrainedDates: [UUID: Date]) -> Bool {
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

    private static func compareDates(_ lhs: Date?, _ rhs: Date?) -> Bool? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?) where lhs != rhs: return lhs < rhs
        case (_?, nil): return true
        case (nil, _?): return false
        default: return nil
        }
    }
}
