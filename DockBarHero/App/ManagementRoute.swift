import Foundation

enum ManagementRoute: String, CaseIterable, Hashable, Identifiable, Sendable {
    case overview
    case inventory
    case book
    case abilities
    case skills
    case shop
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .inventory: "Inventory"
        case .book: "Book"
        case .abilities: "Abilities"
        case .skills: "Skills"
        case .shop: "Shop"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "gauge.with.dots.needle.67percent"
        case .inventory: "shippingbox"
        case .book: "book.pages"
        case .abilities: "bolt.circle"
        case .skills: "point.3.connected.trianglepath.dotted"
        case .shop: "storefront"
        case .settings: "gearshape"
        }
    }
}
