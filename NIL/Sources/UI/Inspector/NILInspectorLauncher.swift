import SwiftUI

public struct NILInspectorLauncher<Content: View>: View {
    private let content: Content
    @State private var isPresented = false

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let base = content
            .overlay {
                GeometryReader { proxy in
                    NILFloatingButton(containerSize: proxy.size) {
                        isPresented = true
                    }
                }
            }

        #if os(iOS)
        base
            .fullScreenCover(isPresented: $isPresented) {
                NILInspectorView {
                    isPresented = false
                }
            }
        #else
        base
            .sheet(isPresented: $isPresented) {
                NILInspectorView {
                    isPresented = false
                }
                .frame(minWidth: 900, minHeight: 620)
            }
        #endif
    }
}

public extension View {
    func nilInspectorLauncher() -> some View {
        NILInspectorLauncher {
            self
        }
    }
}

private struct NILFloatingButton: View {
    let containerSize: CGSize
    let openInspector: () -> Void

    @State private var center: CGPoint = .zero
    @State private var dragStartCenter: CGPoint?
    @State private var hasResolvedInitialPosition = false
    @State private var hasDragged = false

    private let buttonSize: CGFloat = 56
    private let inset: CGFloat = 20
    private let tapThreshold: CGFloat = 6

    var body: some View {
        Image(systemName: "network")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: buttonSize, height: buttonSize)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.70, green: 0.09, blue: 0.17),
                                Color(red: 0.52, green: 0.08, blue: 0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
            )
            .contentShape(Circle())
            .position(resolvedCenter)
            .gesture(dragGesture)
            .accessibilityLabel("Open NIL Inspector")
            .onAppear {
                resolveInitialPositionIfNeeded()
            }
            .onChange(of: containerSize) { _ in
                if !hasResolvedInitialPosition {
                    resolveInitialPositionIfNeeded()
                } else {
                    center = clamped(center)
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartCenter == nil {
                    dragStartCenter = resolvedCenter
                    hasDragged = false
                }

                guard let dragStartCenter else { return }
                let translatedCenter = CGPoint(
                    x: dragStartCenter.x + value.translation.width,
                    y: dragStartCenter.y + value.translation.height
                )
                center = clamped(translatedCenter)
                if abs(value.translation.width) > tapThreshold || abs(value.translation.height) > tapThreshold {
                    hasDragged = true
                }
            }
            .onEnded { _ in
                defer {
                    dragStartCenter = nil
                    hasDragged = false
                }
                if !hasDragged {
                    openInspector()
                }
            }
    }

    private var resolvedCenter: CGPoint {
        if center == .zero {
            return defaultCenter
        }
        return center
    }

    private var defaultCenter: CGPoint {
        CGPoint(
            x: max(buttonSize / 2 + inset, containerSize.width - buttonSize / 2 - inset),
            y: max(buttonSize / 2 + inset, containerSize.height - buttonSize / 2 - inset - 24)
        )
    }

    private func resolveInitialPositionIfNeeded() {
        guard containerSize.width > 0, containerSize.height > 0 else { return }
        center = clamped(defaultCenter)
        hasResolvedInitialPosition = true
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        let minX = buttonSize / 2 + inset
        let maxX = max(minX, containerSize.width - buttonSize / 2 - inset)
        let minY = buttonSize / 2 + inset
        let maxY = max(minY, containerSize.height - buttonSize / 2 - inset)
        return CGPoint(
            x: min(max(point.x, minX), maxX),
            y: min(max(point.y, minY), maxY)
        )
    }
}
