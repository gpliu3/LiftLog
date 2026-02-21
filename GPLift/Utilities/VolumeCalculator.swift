import Foundation
import SwiftUI

enum VolumeCalculator {
    /// Calculate volume for a single set: weight × reps
    static func setVolume(weightKg: Double, reps: Int) -> Double {
        weightKg * Double(reps)
    }

    /// Calculate total volume for multiple sets
    static func totalVolume(sets: [(weightKg: Double, reps: Int)]) -> Double {
        sets.reduce(0) { $0 + setVolume(weightKg: $1.weightKg, reps: $1.reps) }
    }

    /// Calculate estimated 1RM using Epley formula: weight × (1 + reps/30)
    static func estimatedOneRepMax(weightKg: Double, reps: Int) -> Double {
        guard reps > 0 else { return weightKg }
        return weightKg * (1 + Double(reps) / 30)
    }

    /// Calculate estimated 1RM using Brzycki formula: weight × 36 / (37 - reps)
    static func estimatedOneRepMaxBrzycki(weightKg: Double, reps: Int) -> Double {
        guard reps > 0 && reps < 37 else { return weightKg }
        return weightKg * 36 / Double(37 - reps)
    }

    /// Calculate tonnage (total weight lifted including bar weight)
    static func tonnage(sets: [(weightKg: Double, reps: Int)]) -> Double {
        totalVolume(sets: sets) / 1000 // Convert to tonnes
    }
}

enum AppTextStyle {
    static let screenTitle = Font.system(.title3, design: .rounded).weight(.semibold)
    static let sectionTitle = Font.system(.headline, design: .rounded).weight(.semibold)
    static let body = Font.system(.body, design: .rounded)
    static let bodyStrong = Font.system(.body, design: .rounded).weight(.semibold)
    static let caption = Font.system(.caption, design: .rounded)
    static let captionStrong = Font.system(.caption, design: .rounded).weight(.semibold)
    static let caption2 = Font.system(.caption2, design: .rounded)
    static let caption2Strong = Font.system(.caption2, design: .rounded).weight(.semibold)
    static let metric = Font.system(.title3, design: .rounded).weight(.bold)
}
