import SwiftUI

struct AIEntitlementBadge: View {
    @StateObject private var entitlementManager = AIEntitlementManager.shared
    
    var body: some View {
        Group {
            switch entitlementManager.entitlementResult {
            case .allowed(let source):
                switch source {
                case .subscription:
                    BadgeView(text: "PRO", color: .blue)
                case .byok:
                    BadgeView(text: "BYOK", color: .green)
                case .local:
                    BadgeView(text: "LOCAL", color: .orange)
                }
            case .denied:
                BadgeView(text: "LOCKED", color: .gray)
            }
        }
    }
}

private struct BadgeView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
