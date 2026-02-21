import SwiftUI

/// A view that renders the GPLift app icon
/// This can be used to preview the icon or export it at various sizes
struct AppIconView: View {
    let size: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color

    init(
        size: CGFloat = 1024,
        backgroundColor: Color = Color(red: 1.0, green: 0.45, blue: 0.1), // Vibrant orange
        foregroundColor: Color = .white
    ) {
        self.size = size
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }

    var body: some View {
        ZStack {
            // Background with gradient
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.5, blue: 0.15),
                            Color(red: 0.95, green: 0.35, blue: 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Subtle inner shadow/depth
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.clear,
                            Color.black.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Main icon design - Stylized barbell/dumbbell forming abstract "L"
            VStack(spacing: 0) {
                // Main dumbbell icon
                DumbbellShape()
                    .fill(foregroundColor)
                    .frame(width: size * 0.65, height: size * 0.5)
                    .shadow(color: .black.opacity(0.2), radius: size * 0.02, y: size * 0.01)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Custom dumbbell shape for the logo
struct DumbbellShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height

        // Proportions
        let plateWidth = width * 0.22
        let plateHeight = height * 0.85
        let barHeight = height * 0.18
        let plateCornerRadius = width * 0.06
        let innerPlateWidth = width * 0.12
        let innerPlateHeight = height * 0.6

        // Center Y
        let centerY = height / 2

        // Left outer plate
        let leftOuterPlate = RoundedRectangle(cornerRadius: plateCornerRadius)
            .path(in: CGRect(
                x: 0,
                y: centerY - plateHeight / 2,
                width: plateWidth,
                height: plateHeight
            ))
        path.addPath(leftOuterPlate)

        // Left inner plate
        let leftInnerPlate = RoundedRectangle(cornerRadius: plateCornerRadius * 0.7)
            .path(in: CGRect(
                x: plateWidth + width * 0.02,
                y: centerY - innerPlateHeight / 2,
                width: innerPlateWidth,
                height: innerPlateHeight
            ))
        path.addPath(leftInnerPlate)

        // Center bar
        let barStartX = plateWidth + innerPlateWidth + width * 0.04
        let barEndX = width - plateWidth - innerPlateWidth - width * 0.04
        let bar = RoundedRectangle(cornerRadius: barHeight / 2)
            .path(in: CGRect(
                x: barStartX,
                y: centerY - barHeight / 2,
                width: barEndX - barStartX,
                height: barHeight
            ))
        path.addPath(bar)

        // Right inner plate
        let rightInnerPlate = RoundedRectangle(cornerRadius: plateCornerRadius * 0.7)
            .path(in: CGRect(
                x: width - plateWidth - innerPlateWidth - width * 0.02,
                y: centerY - innerPlateHeight / 2,
                width: innerPlateWidth,
                height: innerPlateHeight
            ))
        path.addPath(rightInnerPlate)

        // Right outer plate
        let rightOuterPlate = RoundedRectangle(cornerRadius: plateCornerRadius)
            .path(in: CGRect(
                x: width - plateWidth,
                y: centerY - plateHeight / 2,
                width: plateWidth,
                height: plateHeight
            ))
        path.addPath(rightOuterPlate)

        return path
    }
}

/// Alternative modern logo design with upward arrow/chart motif
struct AppIconViewAlternative: View {
    let size: CGFloat

    init(size: CGFloat = 1024) {
        self.size = size
    }

    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.55, blue: 0.2),
                            Color(red: 0.95, green: 0.35, blue: 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Stylized "L" made of weight plates stacked like a progress chart
            HStack(alignment: .bottom, spacing: size * 0.03) {
                // First bar (short)
                RoundedRectangle(cornerRadius: size * 0.03)
                    .fill(Color.white)
                    .frame(width: size * 0.12, height: size * 0.25)

                // Second bar (medium)
                RoundedRectangle(cornerRadius: size * 0.03)
                    .fill(Color.white)
                    .frame(width: size * 0.12, height: size * 0.4)

                // Third bar (tall) - represents progress
                RoundedRectangle(cornerRadius: size * 0.03)
                    .fill(Color.white)
                    .frame(width: size * 0.12, height: size * 0.55)

                // Fourth bar (tallest)
                RoundedRectangle(cornerRadius: size * 0.03)
                    .fill(Color.white)
                    .frame(width: size * 0.12, height: size * 0.65)
            }
            .shadow(color: .black.opacity(0.15), radius: size * 0.02, y: size * 0.01)
        }
        .frame(width: size, height: size)
    }
}

/// Modern minimalist design with single weight plate and progress indicator
struct AppIconViewModern: View {
    let size: CGFloat

    init(size: CGFloat = 1024) {
        self.size = size
    }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.15, blue: 0.18),
                            Color(red: 0.1, green: 0.1, blue: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Weight plate circle
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.55, blue: 0.2),
                            Color(red: 1.0, green: 0.4, blue: 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: size * 0.08
                )
                .frame(width: size * 0.55, height: size * 0.55)

            // Inner ring
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: size * 0.015)
                .frame(width: size * 0.35, height: size * 0.35)

            // Center hole
            Circle()
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                .frame(width: size * 0.15, height: size * 0.15)

            // Upward arrow indicating progress
            Image(systemName: "arrow.up")
                .font(.system(size: size * 0.08, weight: .bold))
                .foregroundStyle(Color(red: 1.0, green: 0.5, blue: 0.15))
                .offset(y: -size * 0.01)
        }
        .frame(width: size, height: size)
    }
}

#Preview("Dumbbell Icon") {
    AppIconView(size: 200)
}

#Preview("Progress Bars Icon") {
    AppIconViewAlternative(size: 200)
}

#Preview("Modern Dark Icon") {
    AppIconViewModern(size: 200)
}

#Preview("All Icons") {
    HStack(spacing: 20) {
        VStack {
            AppIconView(size: 120)
            Text("Dumbbell").font(.caption)
        }
        VStack {
            AppIconViewAlternative(size: 120)
            Text("Progress").font(.caption)
        }
        VStack {
            AppIconViewModern(size: 120)
            Text("Modern").font(.caption)
        }
    }
    .padding()
}
