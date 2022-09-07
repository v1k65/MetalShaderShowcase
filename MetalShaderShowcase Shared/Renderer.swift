import Metal
import MetalKit
import simd

class Renderer: NSObject {
	
	static let depthStencilPixelFormat = MTLPixelFormat.depth32Float
	static let viewColorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
	
	static let device = MTLCreateSystemDefaultDevice()!
	static let commandQueue = device.makeCommandQueue()!
	static let library = device.makeDefaultLibrary()!
	
	private let _depthState: MTLDepthStencilState
	private let _renderPipelineStates: [MTLRenderPipelineState]
	
	
	private let _mesh: RenderableMesh = RenderableMesh.buildTeapot()
	private let _instanceTransforms: [Transform]
	
	private let _camera = ArcballCamera()
	
	private var _vertexUniforms = VertexUniforms()
	private var _fragmentUniforms = FragmentUniforms(light_direction_ws: simd_normalize(simd_float3(-1, 0.5, -1)),
																									 light_color: simd_float3(1, 1, 1),
																									 eye_direction_ws: simd_float3(0, 0, 0))
		
	override init() {
		self._instanceTransforms = Self._buildInstanceTransforms()
		self._depthState = Self._buildDepthState()
		self._renderPipelineStates = [Self._buildPipelineState(vertexFunction: "phong_vertex_shader", fragmentFunction: "phong_fragment_shader"),]
				
		super.init()
	}
	
	func setup(view: MTKView) {
		view.depthStencilPixelFormat = Self.depthStencilPixelFormat
		view.colorPixelFormat = Self.viewColorPixelFormat
		view.device = Self.device
		view.delegate = self
	}
	
	func handlePan(translation: simd_float2) {
		_camera.pan(by: translation * 0.005)
	}
	
	static func _buildDepthState() -> MTLDepthStencilState {
		let depthStateDescriptor = MTLDepthStencilDescriptor()
		depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
		depthStateDescriptor.isDepthWriteEnabled = true
		return device.makeDepthStencilState(descriptor:depthStateDescriptor)!
	}
	
	static func _buildInstanceTransforms(cnt: Int = 10) -> [Transform] {
		var transforms = [Transform]()
		
		for idx in 0..<cnt {
			let transform = Transform()
			
			if idx > 0 {
				let z = Float.random(in: 0...10)
				let x = Float.random(in: -z...z)
				transform.position = simd_float3(x * 0.5, 0, z)
			}
			
			transforms.append(transform)
		}
		
		return transforms
	}
	
	static func _buildPipelineState(vertexFunction: String, fragmentFunction: String) -> MTLRenderPipelineState {
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.label = "RenderPipeline"
		pipelineDescriptor.vertexFunction = library.makeFunction(name: vertexFunction)!
		pipelineDescriptor.fragmentFunction = library.makeFunction(name: fragmentFunction)!
		
		pipelineDescriptor.colorAttachments[0].pixelFormat = viewColorPixelFormat
		pipelineDescriptor.depthAttachmentPixelFormat = depthStencilPixelFormat
		
		return try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
	}
	
	
	/*
	 class func loadTexture(device: MTLDevice,
	 textureName: String) throws -> MTLTexture {
	 /// Load texture data with optimal parameters for sampling
	 
	 let textureLoader = MTKTextureLoader(device: device)
	 
	 let textureLoaderOptions = [
	 MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
	 MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
	 ]
	 
	 return try textureLoader.newTexture(name: textureName,
	 scaleFactor: 1.0,
	 bundle: nil,
	 options: textureLoaderOptions)
	 
	 } */
	
}

// MARK: - MTKViewDelegate
extension Renderer: MTKViewDelegate {
	
	func draw(in view: MTKView) {
		guard let commandBuffer = Self.commandQueue.makeCommandBuffer(),
					let renderPassDescriptor = view.currentRenderPassDescriptor else {
			return
		}
		
		if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
			renderEncoder.setFrontFacing(.counterClockwise)
			renderEncoder.setRenderPipelineState(_renderPipelineStates[0]) // TODO: Iterate
			renderEncoder.setDepthStencilState(_depthState)
			
			_vertexUniforms.viewTransform = _camera.buildTransform()
			_fragmentUniforms.eye_direction_ws = simd_normalize(_vertexUniforms.viewTransform.inverse[3].xyz)
			
			let instanceTransforms = _instanceTransforms.map { $0.transform }
			
			renderEncoder.pushDebugGroup("Rendering \(_mesh.name)")
			renderEncoder.setVertexBuffer(_mesh.positionBuffer, offset: 0, index: VertexBufferIndex.positions.rawValue)
			renderEncoder.setVertexBuffer(_mesh.normalBuffer, offset: 0, index: VertexBufferIndex.normal.rawValue)
			renderEncoder.setVertexBytes(&_vertexUniforms, length: MemoryLayout<VertexUniforms>.stride, index: VertexBufferIndex.uniforms.rawValue)
			renderEncoder.setVertexBytes(instanceTransforms, length: MemoryLayout<simd_float4x4>.stride * _instanceTransforms.count, index: VertexBufferIndex.instanceTransforms.rawValue)
			renderEncoder.setFragmentBytes(&_fragmentUniforms, length: MemoryLayout<FragmentUniforms>.stride, index: FragmentBufferIndex.uniforms.rawValue)
			renderEncoder.drawIndexedPrimitives(type: .triangleStrip,
																					indexCount: _mesh.indexCnt,
																					indexType: .uint32,
																					indexBuffer: _mesh.indexBuffer,
																					indexBufferOffset: 0,
																					instanceCount: _instanceTransforms.count)
			renderEncoder.popDebugGroup()
			
			renderEncoder.endEncoding()
		}
		
		
		if let drawable = view.currentDrawable {
			commandBuffer.present(drawable)
		}
		commandBuffer.commit()
		
	}
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		_vertexUniforms.projectionTransform = Self._buildPerspectiveTransform(fovyDegree: 65.0,
																																					aspect: Float(size.width / size.height),
																																					near: 0.1,
																																					far: 10.0)
	}
}

// MARK: - Generic matrix math utility functions
extension Renderer {
	
	func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
		let unitAxis = normalize(axis)
		let ct = cosf(radians)
		let st = sinf(radians)
		let ci = 1 - ct
		let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
		return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
																				 vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
																				 vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
																				 vector_float4(                  0,                   0,                   0, 1)))
	}
	
	static func _buildPerspectiveTransform(fovyDegree: Float,
																				 aspect: Float,
																				 near: Float,
																				 far: Float) -> simd_float4x4 {
		let fovyRadians = fovyDegree * 0.5 * .pi / 180
		let yScale = 1.0 / tan(fovyRadians);
		let xScale = yScale / aspect;
		let zScale = far / (far - near);
		
		let P = simd_float4(xScale, 0.0, 0.0, 0.0);
		let Q = simd_float4(0.0, yScale, 0.0, 0.0);
		let R = simd_float4(0.0, 0.0, zScale, 1.0);
		let S = simd_float4(0.0, 0.0, -near * zScale, 0.0);
		
		return simd_float4x4(P, Q, R, S);
	}
}

extension simd_float4 {
	var xyz: simd_float3 { simd_float3(x, y, z) }
}
