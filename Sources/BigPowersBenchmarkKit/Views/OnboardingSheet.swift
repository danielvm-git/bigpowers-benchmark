import SwiftUI

public struct OnboardingSheet: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Set up your runs directory")
                .font(.title2.bold())

            Text(
                "BigPowers stores benchmark results in ~/runs/data/. " +
                    "This directory must be a Git repository so results are " +
                    "version-controlled and shareable."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

            Text("Run `git init ~/runs/data` in Terminal, then relaunch.")
                .font(.callout)
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(32)
        .frame(minWidth: 400, minHeight: 260)
    }
}
