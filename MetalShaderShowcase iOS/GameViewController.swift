import UIKit
import MetalKit

class GameViewController: UIViewController {

	lazy var renderer = Renderer()

	override func viewDidLoad() {
		super.viewDidLoad()

		guard let mtkView = self.view as? MTKView else {
			print("View attached to GameViewController is not an MTKView")
			fatalError()
		}

		renderer.setup(view: mtkView)
		renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
		
		mtkView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(gesture:))))
	}
	
	@objc func handlePan(gesture: UIPanGestureRecognizer) {
		let translation = gesture.translation(in: gesture.view)
		renderer.handlePan(translation: simd_float2(Float(translation.x), Float(translation.y)))
		gesture.setTranslation(.zero, in: gesture.view)
	}
}
