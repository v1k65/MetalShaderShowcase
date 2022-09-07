import Metal
import simd

struct RenderableMesh {
	let name: String
	
	let position: simd_float3
	
	let positionBuffer: MTLBuffer
	let normalBuffer: MTLBuffer
	
	let indexCnt: Int
	let indexBuffer: MTLBuffer
}

extension RenderableMesh {
	
	var transform: simd_float4x4 {
		matrix_float4x4(columns:(vector_float4(1, 0, 0, 0),
																				 vector_float4(0, 1, 0, 0),
																				 vector_float4(0, 0, 1, 0),
																				 vector_float4(position, 1)))
	}
}
