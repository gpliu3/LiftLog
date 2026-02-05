import Foundation

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
