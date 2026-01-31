import SwiftUI

struct InviteCardRenderer {
    @MainActor
    static func render(
        eventName: String,
        joinCode: String,
        startDate: Date,
        hostName: String,
        isPremium: Bool
    ) -> UIImage? {
        let card = InviteCardView(
            eventName: eventName,
            joinCode: joinCode,
            startDate: startDate,
            hostName: hostName,
            isPremium: isPremium
        )
        .frame(width: 320)
        .padding(24)
        .background(Color.black)

        let controller = UIHostingController(rootView: card)
        controller.view.backgroundColor = .clear

        let targetSize = controller.sizeThatFits(in: CGSize(width: 368, height: CGFloat.greatestFiniteMagnitude))
        controller.view.frame = CGRect(origin: .zero, size: targetSize)
        controller.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}
