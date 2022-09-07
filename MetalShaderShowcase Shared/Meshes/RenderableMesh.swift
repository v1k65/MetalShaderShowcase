import Metal
import simd

struct RenderableMesh {
	let name: String
		
	let positionBuffer: MTLBuffer
	let normalBuffer: MTLBuffer
	
	let indexCnt: Int
	let indexBuffer: MTLBuffer
}
