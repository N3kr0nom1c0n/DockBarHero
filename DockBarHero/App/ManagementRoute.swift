import Foundation

enum ManagementRoute: String, CaseIterable, Hashable, Identifiable, Sendable {
    case overview
    case inventory
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .inventory: "Inventory"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "gauge.with.dots.needle.67percent"
        case .inventory: "shippingbox"
        case .settings: "gearshape"
        }
    }
}
