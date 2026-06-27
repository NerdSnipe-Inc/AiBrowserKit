#if canImport(AppKit)
import SwiftUI
import WebKit

/// Interactive drag-to-select overlay for capturing a region of the web view.
/// Shows a dimmed mask with the selected rectangle cut out.
public struct ScreenshotSelectionOverlay: View {
    let webView: WKWebView
    let destination: ScreenshotDestination
    let sourceURL: String?
    let onDismiss: () -> Void

    @Environment(BrowserEnvironment.self) private var browserEnv
    @State private var startPoint: CGPoint = .zero
    @State private var currentPoint: CGPoint = .zero
    @State private var isDragging = false

    public init(
        webView: WKWebView,
        destination: ScreenshotDestination,
        sourceURL: String? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.webView = webView
        self.destination = destination
        self.sourceURL = sourceURL
        self.onDismiss = onDismiss
    }

    private var selectionRect: CGRect {
        CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dimmed overlay with selection cutout
                Canvas { context, size in
                    // Fill the whole canvas dimmed
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .color(.black.opacity(0.4))
                    )
                    // Cut out the selection rect (transparent)
                    if isDragging {
                        context.blendMode = .clear
                        context.fill(Path(selectionRect), with: .color(.black))
                    }
                }
                .allowsHitTesting(false)

                // Selection border
                if isDragging && selectionRect.width > 4 && selectionRect.height > 4 {
                    Rectangle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                        .frame(width: selectionRect.width, height: selectionRect.height)
                        .position(
                            x: selectionRect.midX,
                            y: selectionRect.midY
                        )
                        .allowsHitTesting(false)

                    // Size label
                    Text("\(Int(selectionRect.width)) × \(Int(selectionRect.height))")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 4))
                        .position(
                            x: selectionRect.midX,
                            y: max(selectionRect.minY - 18, 16)
                        )
                        .allowsHitTesting(false)
                }

                // Instructions (before drag starts)
                if !isDragging {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.dashed")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.8))
                        Text("Drag to select area")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Escape to cancel")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .local)
                    .onChanged { value in
                        if !isDragging {
                            startPoint = value.startLocation
                            isDragging = true
                        }
                        currentPoint = value.location
                    }
                    .onEnded { _ in
                        let rect = selectionRect
                        guard rect.width > 4 && rect.height > 4 else {
                            onDismiss()
                            return
                        }
                        captureSelection(rect: rect, viewSize: geo.size)
                    }
            )
            .onKeyPress(.escape) {
                onDismiss()
                return .handled
            }
        }
    }

    private func captureSelection(rect: CGRect, viewSize: CGSize) {
        Task { @MainActor in
            let config = WKSnapshotConfiguration()
            guard let snapshot = try? await webView.takeSnapshot(configuration: config) else {
                onDismiss()
                return
            }

            // Map SwiftUI coordinates → snapshot pixel coordinates
            let imageSize = snapshot.size
            let scaleX = imageSize.width / viewSize.width
            let scaleY = imageSize.height / viewSize.height

            let pixelRect = CGRect(
                x: rect.minX * scaleX,
                y: rect.minY * scaleY,
                width: rect.width * scaleX,
                height: rect.height * scaleY
            )

            guard let cgFull = snapshot.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let cropped = cgFull.cropping(to: pixelRect) else {
                onDismiss()
                return
            }

            let result = NSImage(cgImage: cropped, size: NSSize(width: rect.width, height: rect.height))
            if destination == .hostClipboard {
                browserEnv.onAddToClipboard?(.init(kind: .image(result), sourceURL: sourceURL))
            } else {
                deliverScreenshot(result, to: destination)
            }
            onDismiss()
        }
    }
}
#endif
