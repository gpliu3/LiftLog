import Foundation

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg
    case lb

    var id: String { rawValue }

    var step: Double {
        switch self {
        case .kg:
            return 2.5
        case .lb:
            return 5
        }
    }

    var localizedLabel: String {
        switch self {
        case .kg:
            return "common.kg".localized
        case .lb:
            return "common.lb".localized
        }
    }

    func convertFromKilograms(_ kilograms: Double) -> Double {
        switch self {
        case .kg:
            return kilograms
        case .lb:
            return kilograms / 0.45359237
        }
    }

    func convertToKilograms(_ value: Double) -> Double {
        switch self {
        case .kg:
            return value
        case .lb:
            return value * 0.45359237
        }
    }

    func formattedInputValue(fromKilograms kilograms: Double) -> Double {
        let value = convertFromKilograms(kilograms)
        switch self {
        case .kg:
            return (value * 10).rounded() / 10
        case .lb:
            return value.rounded()
        }
    }

    func formattedInputText(fromKilograms kilograms: Double) -> String {
        switch self {
        case .kg:
            return String(format: "%.1f", formattedInputValue(fromKilograms: kilograms))
        case .lb:
            return String(format: "%.0f", formattedInputValue(fromKilograms: kilograms))
        }
    }
}
