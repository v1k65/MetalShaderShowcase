#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

struct PhongInOut {
	float4 position_cs [[position]];
	float3 normal_ws;
};

vertex PhongInOut phong_vertex_shader(
    const device packed_float3* positions [[ buffer(VertexBufferIndexPositions) ]],
		const device packed_float3* normals [[ buffer(VertexBufferIndexNormal) ]],
															 
	  constant VertexUniforms &uniforms [[ buffer(VertexBufferIndexUniforms) ]],
															 
		unsigned int vertex_id [[ vertex_id ]])
{
	float4 position = float4(positions[vertex_id], 1.0);
	float4 normal = float4(normals[vertex_id], 0);
	
	float4x4 mvp_transform = uniforms.projectionTransform * uniforms.viewTransform * uniforms.modelTransform;
	
	return PhongInOut {
		.position_cs = mvp_transform * position,
		.normal_ws = (uniforms.modelTransform * normal).xyz,
	};
}

constant PhongMaterial material {
	.ambientColor = simd_float3(0.18, 0.18, 0.18),
	.diffuseColor = simd_float3(0.4, 0.4, 0.4),
	.specularColor = simd_float3(1.0, 1.0, 1.0),
  .materialShine = 50,
};

fragment float4 phong_fragment_shader(
    PhongInOut in [[stage_in]],
	  constant FragmentUniforms &uniforms [[ buffer(FragmentBufferIndexUniforms) ]])
{
	float3 ambientColor = material.ambientColor;
	
	float n_dot_l = saturate(dot(in.normal_ws, uniforms.light_direction_ws));
	float3 diffuse_color = material.diffuseColor * n_dot_l * uniforms.light_color;
	
	float3 r = -uniforms.light_direction_ws + 2.0 * n_dot_l * in.normal_ws;
	float e_dot_r = saturate(dot(uniforms.eye_direction_ws, r));
	float3 specular_color = material.specularColor * uniforms.light_color * pow(e_dot_r, material.materialShine);
	
	return float4(ambientColor + diffuse_color + specular_color, 1);
}
