import ScreenSaver
import AppKit
import MetalKit

class LivingGlassView: ScreenSaverView {
    private var gameView: GameOfLifeView?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 60.0
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        animationTimeInterval = 1.0 / 60.0
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(hex: 0x121117).cgColor

        let saverBundle = Bundle(for: LivingGlassView.self)
        let gv = GameOfLifeView(frame: bounds, bundle: saverBundle)
        gv.autoresizingMask = [.width, .height]
        addSubview(gv)
        gameView = gv
    }

    override func startAnimation() {
        super.startAnimation()
        gameView?.resume()
    }

    override func stopAnimation() {
        super.stopAnimation()
        gameView?.pause()
    }

    override func animateOneFrame() {
        // GameOfLifeView drives its own timer, so nothing needed here
    }

    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }

    override func draw(_ rect: NSRect) {
        // Let the Metal subview handle all drawing
    }
}
