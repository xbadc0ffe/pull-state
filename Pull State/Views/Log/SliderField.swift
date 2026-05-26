import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Stepped slider with an inline editable readout. There is no hidden `Slider`
/// — the visible thumb is the only thing that exists, and a UIKit-backed pan
/// recognizer (via `HorizontalDragView` on iOS / iPadOS / visionOS) maps drag
/// x-position to a stepped, clamped value. The recognizer fails on
/// vertical-first drags so the parent `ScrollView` receives them. Tap on the
/// readout flips the row into a focused decimal text field that commits on
/// submit/blur. See DESIGN.md §5.3 for the gesture spec.
struct SliderField: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    var decimals: Int = 1
    var last: Bool = false

    @Environment(\.psPalette) private var palette
    @State private var editing = false
    @State private var draft: String = ""
    @State private var dragActive: Bool? = nil
    @FocusState private var focused: Bool

    private var clampedValue: Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        return span > 0 ? (clampedValue - range.lowerBound) / span : 0
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(PSFont.body(13, weight: .medium))
                    .foregroundStyle(palette.inkSoft)
                Spacer()
                if editing {
                    HStack(spacing: 4) {
                        TextField("", text: $draft)
                            .modifier(PSDecimalKeyboard(active: true))
                            .font(PSFont.mono(17, weight: .bold))
                            .foregroundStyle(palette.ink)
                            .multilineTextAlignment(.trailing)
                            .focused($focused)
                            .frame(width: 70)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(palette.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onSubmit { commit() }
                        Text(unit)
                            .font(PSFont.mono(11))
                            .foregroundStyle(palette.inkMuted)
                    }
                    .onAppear {
                        draft = formatted
                        focused = true
                    }
                    .onChange(of: focused) { _, new in
                        if !new { commit() }
                    }
                } else {
                    Button {
                        editing = true
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatted)
                                .font(PSFont.mono(17, weight: .bold))
                                .foregroundStyle(palette.ink)
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(
                                    Rectangle()
                                        .fill(palette.lineStrong)
                                        .frame(height: 1)
                                        .padding(.horizontal, 6),
                                    alignment: .bottom
                                )
                            Text(unit)
                                .font(PSFont.mono(11))
                                .foregroundStyle(palette.inkMuted)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            GeometryReader { proxy in
                let trackWidth = proxy.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(palette.surfaceAlt)
                        .frame(height: 4)
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(palette.line, lineWidth: 0.5))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [palette.accent, palette.accentDeep], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, trackWidth * fraction), height: 4)

                    Circle()
                        .fill(palette.accent)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5))
                        .psShadow(strong: false)
                        .offset(x: max(0, min(trackWidth - 18, trackWidth * fraction - 9)))
                }
                .frame(height: 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                #if canImport(UIKit)
                // UIKit-backed pan recognizer. Decides at the first ≥4pt of
                // movement: predominantly horizontal AND starting within
                // ±21pt of the thumb center activates the drag; everything
                // else fails the recognizer so the parent UIScrollView's pan
                // can claim the touch. shouldRecognizeSimultaneouslyWith
                // returns true so the ScrollView's pan can track the touch
                // concurrently from the start — there is no priority gap to
                // wait through.
                .overlay(
                    HorizontalDragView(
                        canBegin: { startX in
                            let halfThumb: CGFloat = 9
                            let forgiveness: CGFloat = 12
                            let unclampedCenter = trackWidth * fraction
                            let thumbCenter = max(halfThumb, min(trackWidth - halfThumb, unclampedCenter))
                            let tolerance = halfThumb + forgiveness
                            return abs(startX - thumbCenter) <= tolerance
                        },
                        onChanged: { x in update(from: x, width: trackWidth) }
                    )
                )
                #else
                // macOS fallback (no UIKit). Scroll passthrough isn't an
                // issue with trackpad scroll semantics, so a plain SwiftUI
                // DragGesture with the same 4pt latch + direction/tolerance
                // gating is sufficient.
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { g in
                            if dragActive == nil {
                                let dx = abs(g.translation.width)
                                let dy = abs(g.translation.height)
                                let halfThumb: CGFloat = 9
                                let forgiveness: CGFloat = 12
                                let unclampedCenter = trackWidth * fraction
                                let thumbCenter = max(halfThumb, min(trackWidth - halfThumb, unclampedCenter))
                                let tolerance = halfThumb + forgiveness
                                let inTolerance = abs(g.startLocation.x - thumbCenter) <= tolerance
                                dragActive = inTolerance && dx > dy
                            }
                            if dragActive == true {
                                update(from: g.location.x, width: trackWidth)
                            }
                        }
                        .onEnded { _ in
                            dragActive = nil
                        }
                )
                #endif
            }
            .frame(height: 22)
        }
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(last ? .clear : palette.line)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    private var formatted: String {
        String(format: "%.*f", decimals, clampedValue)
    }

    private func update(from x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let f = max(0, min(1, x / width))
        let raw = range.lowerBound + Double(f) * (range.upperBound - range.lowerBound)
        let stepped = (raw / step).rounded() * step
        let clamped = min(max(stepped, range.lowerBound), range.upperBound)
        if abs(clamped - value) > 1e-9 {
            value = clamped
        }
    }

    private func commit() {
        defer { editing = false }
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let n = Double(trimmed) else { return }
        value = min(max(n, range.lowerBound), range.upperBound)
    }
}

#if canImport(UIKit)

/// Transparent UIView overlay that hosts a `HorizontalDragRecognizer`. The
/// view fills its SwiftUI overlay frame, receives touches, and forwards them
/// to the recognizer. `canBegin` is consulted once per touch — at the moment
/// the recognizer decides the drag is horizontal — and a `false` return fails
/// the recognizer before it ever enters `.began`.
private struct HorizontalDragView: UIViewRepresentable {
    let canBegin: (CGFloat) -> Bool
    let onChanged: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        let recognizer = HorizontalDragRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handle(_:))
        )
        recognizer.delegate = context.coordinator
        recognizer.canBegin = canBegin
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        // Refresh closures captured at the moment of update — `fraction` and
        // `trackWidth` change every time the binding does, so the recognizer
        // must see the latest tolerance window.
        if let r = uiView.gestureRecognizers?.compactMap({ $0 as? HorizontalDragRecognizer }).first {
            r.canBegin = canBegin
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: HorizontalDragView
        init(parent: HorizontalDragView) { self.parent = parent }

        @objc func handle(_ g: HorizontalDragRecognizer) {
            switch g.state {
            case .began, .changed:
                parent.onChanged(g.currentX)
            default:
                break
            }
        }

        // Allow concurrent recognition with the parent UIScrollView's pan
        // recognizer (and anything else upstream). Returning true on this
        // side is sufficient — UIKit honors "either side says yes."
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}

/// Custom UIGestureRecognizer that stays in `.possible` until the user has
/// moved ≥4pt, then commits to one of two terminal-or-active states:
///   • Horizontal-dominant AND start within tolerance → `.began`, then
///     `.changed` on subsequent moves, `.ended` on lift.
///   • Vertical-dominant OR start outside tolerance → `.failed`. The
///     parent UIScrollView's pan recognizer is free to claim the touch.
/// Tapping without significant movement also resolves to `.failed`, so
/// tap-to-jump never fires.
private final class HorizontalDragRecognizer: UIGestureRecognizer {
    var canBegin: (CGFloat) -> Bool = { _ in true }
    private(set) var startX: CGFloat = 0
    private(set) var currentX: CGFloat = 0
    private var startLocation: CGPoint = .zero
    private var decided: Bool = false
    private let threshold: CGFloat = 4

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first, let view else {
            state = .failed
            return
        }
        startLocation = touch.location(in: view)
        startX = startLocation.x
        currentX = startLocation.x
        decided = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first, let view else { return }
        let current = touch.location(in: view)
        currentX = current.x

        if !decided {
            let dx = abs(current.x - startLocation.x)
            let dy = abs(current.y - startLocation.y)
            if max(dx, dy) < threshold { return }
            decided = true
            if dx <= dy {
                state = .failed
                return
            }
            if !canBegin(startX) {
                state = .failed
                return
            }
            state = .began
            return
        }
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        if state == .began || state == .changed {
            state = .ended
        } else {
            state = .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        state = .cancelled
    }

    override func reset() {
        super.reset()
        startLocation = .zero
        startX = 0
        currentX = 0
        decided = false
    }
}

#endif
