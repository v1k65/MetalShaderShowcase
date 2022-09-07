import simd

class Transform {
	
	var position = simd_float3(0, 0, 0)
}

extension Transform {
	
	var transform: simd_float4x4 {
		matrix_float4x4(columns:(vector_float4(1, 0, 0, 0),
																				 vector_float4(0, 1, 0, 0),
																				 vector_float4(0, 0, 1, 0),
																				 vector_float4(position, 1)))
	}
}
