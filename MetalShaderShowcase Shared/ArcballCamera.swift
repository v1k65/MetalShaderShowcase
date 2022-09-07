import simd

class ArcballCamera {

	var distance: Float = 0.4
	var to = simd_float3(0, 0, 0)
	var up = simd_float3(0, 1, 0)
	
	private var _xRotation: Float = Float.pi / 2
	private var _yRotation: Float = Float.pi / 3
	
	func pan(by point: simd_float2) {
		_xRotation -= point.x
		_yRotation += point.y
	}
	
	private func _from() -> simd_float3 {
		let up = distance * cos(_yRotation)

		let sinTheta = -distance * sin(_yRotation)
		let right = cos(_xRotation) * sinTheta
		let forward = sin(_xRotation) * sinTheta
		
		return simd_float3(right, up, forward)
	}
	
	func buildTransform() -> simd_float4x4 {
		let from = _from()
					
		let zAxis = simd_normalize(to - from)
		let xAxis = simd_normalize(simd_cross(up, zAxis));
		let yAxis = simd_cross(zAxis, xAxis);
		
		let P = simd_float4(xAxis.x, yAxis.x, zAxis.x, 0)
		let Q = simd_float4(xAxis.y, yAxis.y, zAxis.y, 0);
		let R = simd_float4(xAxis.z, yAxis.z, zAxis.z, 0);
		let S = simd_float4(-simd_dot(xAxis, from),
												-simd_dot(yAxis, from),
												-simd_dot(zAxis, from),
												1);
		
		return simd_float4x4(P, Q, R, S);
	}
}
