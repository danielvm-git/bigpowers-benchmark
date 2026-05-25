import SwiftUI

public struct OnboardingSheet: View {
    @Environment(ThemeManager.self) private var themeManager

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 48))
                .foregroundStyle(tokens.fg3)

            Text("Set up your runs directory")
                .font(.title2.bold())
                .foregroundColor(tokens.fg)

            Text(
                "BigPowers stores benchmark results in ~/runs/data/. " +
                    "This directory must be a Git repository so results are " +
                    "version-controlled and shareable."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(tokens.fg3)

            Text("Run `git init ~/runs/data` in Terminal, then relaunch.")
                .font(.callout)
                .foregroundColor(tokens.fg)
                .padding(8)
                .background(tokens.surface, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(32)
        .frame(minWidth: 400, minHeight: 260)
        .background(tokens.bg)
    }
}
