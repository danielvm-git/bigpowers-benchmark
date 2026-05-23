public enum Screen: String, CaseIterable {
    case dashboard
    case missionControl
    case runExplorer
    case skillInsights
    case modelHealth
    case taskLibrary
    case settings
    case analytics

    public var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .missionControl: "Mission Control"
        case .runExplorer: "Run Explorer"
        case .skillInsights: "Skill Insights"
        case .modelHealth: "Model Health"
        case .taskLibrary: "Task Library"
        case .settings: "Settings"
        case .analytics: "Analytics"
        }
    }

    public var systemImage: String {
        switch self {
        case .dashboard: "chart.bar.xaxis"
        case .missionControl: "scope"
        case .runExplorer: "list.bullet.rectangle"
        case .skillInsights: "hexagon"
        case .modelHealth: "waveform.path.ecg"
        case .taskLibrary: "tray.full"
        case .settings: "gearshape"
        case .analytics: "chart.xyaxis.line"
        }
    }
}
