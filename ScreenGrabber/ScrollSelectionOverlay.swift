import SwiftUI
import AppKit

struct ScrollSelectionOverlay: View {
    @Binding var isPresented: Bool
    @Binding var selectedRect: CGRect?
    var onComplete: (CGRect) -> Void

    @State private var startPoint: CGPoint? = nil
    @State private var currentPoint: CGPoint? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .gesture(dragGesture(in: geo))

                if let rect = selectionRect {
                    SelectionRectView(rect: rect)
                }
            }
            .onAppear {
                // Reset selection when presented
                startPoint = nil
                currentPoint = nil
                selectedRect = nil
            }
            .onDisappear {
                // Clear selection on dismiss
                startPoint = nil
                currentPoint = nil
                selectedRect = nil
            }
            .overlay(
                VStack {
                    HStack {
                        Text("Drag to select area for scrolling capture")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        Spacer()
                    }
                    .padding()
                    Spacer()
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zIndex(1)
    }

    private func dragGesture(in geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let location = value.location
                if startPoint == nil {
                    startPoint = location
                }
                currentPoint = location
                selectedRect = selectionRect
            }
            .onEnded { value in
                currentPoint = value.location
                if let rect = selectionRect, rect.width > 2, rect.height > 2 {
                    selectedRect = rect
                    onComplete(rect)
                }
                isPresented = false
                startPoint = nil
                currentPoint = nil
            }
    }

    private var selectionRect: CGRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

private struct SelectionRectView: View {
    let rect: CGRect
    var body: some View {
        ZStack {
            Rectangle()
                .path(in: rect)
                .fill(Color.accentColor.opacity(0.08))
            RoundedRectangle(cornerRadius: 2)
                .path(in: rect)
                .stroke(Color.accentColor, lineWidth: 2)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    StatefulPreviewWrapper(false as Bool, nil as CGRect?) { isPresented, rect in
        ZStack {
            Color.gray.opacity(0.2)
                .ignoresSafeArea()
            if isPresented.wrappedValue {
                ScrollSelectionOverlay(isPresented: isPresented, selectedRect: rect) { _ in }
            }
            VStack {
                Button("Toggle Selection Overlay") {
                    isPresented.wrappedValue.toggle()
                }
                .padding()
                Spacer()
            }
        }
    }
}

// Helper for previews
struct StatefulPreviewWrapper<Content: View, T>: View {
    @State var value1: Bool
    @State var value2: T?
    let content: (Binding<Bool>, Binding<T?>) -> Content

    init(_ value1: Bool, _ value2: T?, content: @escaping (Binding<Bool>, Binding<T?>) -> Content) {
        _value1 = State(initialValue: value1)
        _value2 = State(initialValue: value2)
        self.content = content
    }

    var body: some View { content($value1, $value2) }
}
