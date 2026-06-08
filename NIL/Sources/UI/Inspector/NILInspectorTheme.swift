import SwiftUI

enum NILInspectorTheme {
    #if os(iOS)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let elevatedSurface = Color(uiColor: .tertiarySystemBackground)
    #else
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let elevatedSurface = Color(nsColor: .underPageBackgroundColor)
    #endif
    static let border = Color.black.opacity(0.08)
    static let accent = Color(red: 0.70, green: 0.09, blue: 0.17)
    static let warning = Color.orange
    static let error = Color.red
    static let textSecondary = Color.secondary

    static func statusColor(for statusCode: Int?) -> Color {
        switch statusCode ?? -1 {
        case 200...299:
            return accent
        case 300...399:
            return warning
        case 400...599:
            return error
        default:
            return error
        }
    }
}
