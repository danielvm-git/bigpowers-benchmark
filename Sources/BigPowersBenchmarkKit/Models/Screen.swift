public enum Screen: String, CaseIterable {
    case dashboard
    case missionControl
    case runExplorer
    case skillInsights
    case modelHealth
    case modelHealthHistory
    case healthInventory
    case healthInsight
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
        case .modelHealthHistory: "Health History"
        case .healthInventory: "Health Inventory"
        case .healthInsight: "Health Insight"
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
        case .modelHealth: "network"
        case .modelHealthHistory: "clock.arrow.circlepath"
        case .healthInventory: "checklist"
        case .healthInsight: "chart.bar.doc.horizontal"
        case .taskLibrary: "tray.full"
        case .settings: "gearshape"
        case .analytics: "chart.xyaxis.line"
        }
    }
}
