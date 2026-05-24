import SwiftUI

/// A premium-styled empty state view that adapts to the active theme.
/// Shows a large circular icon background, a title, subtitle, and optional action button.
struct ThemedEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    let tokens: ThemeTokens
    var actionLabel: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 28) {
            // Icon with layered circular glow
            ZStack {
                Circle()
                    .fill(tokens.accent.opacity(0.06))
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(tokens.accent.opacity(0.10))
                    .frame(width: 72, height: 72)

                Image(systemName: icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(tokens.accent.opacity(0.7))
            }

            VStack(spacing: 10) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(tokens.fg)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(tokens.fg3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 340)
            }

            if let label = actionLabel, let handler = action {
                Button(label, action: handler)
                    .buttonStyle(ThemedButtonStyle(tokens: tokens))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

/// Compact inline variant — fits inside chart-height containers.
struct ThemedInlineEmpty: View {
    let icon: String
    let title: String
    let tokens: ThemeTokens

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tokens.accent.opacity(0.08))
                    .frame(width: 52, height: 52)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(tokens.accent.opacity(0.6))
            }

            Text(title)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(tokens.fg3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(tokens.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tokens.border, lineWidth: 1)
        )
    }
}

/// Themed bordered button style.
struct ThemedButtonStyle: ButtonStyle {
    let tokens: ThemeTokens

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(tokens.bg)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? tokens.accentD : tokens.accent)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
