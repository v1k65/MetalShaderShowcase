#include <metal_stdlib>

#import "../ShaderTypes.h"

using namespace metal;

struct PhongInOut {
	float4 position_cs [[position]];
	float3 position_ms;
	float3 normal_ws;
};

vertex PhongInOut wood_vertex_shader(
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
		.position_ms = position.xyz,
		.normal_ws = (uniforms.modelNormalTransform * normal).xyz,
	};
}
	
	constant uint NOISE_DIM = 512;
	constant float NOISE_SIZE = 64;

	constant float teapotMin = -0.144000;
	constant float teapotMax = 0.164622;
	constant float scaleLength = teapotMax - teapotMin;
	
// Generate a random float in the range [0.0f, 1.0f] using x, y, and z (based on the xor128 algorithm)
float rand(int x, int y, int z)
{
	int seed = x + y * 57 + z * 241;
	seed= (seed<< 13) ^ seed;
	return (( 1.0 - ( (seed * (seed * seed * 15731 + 789221) + 1376312589) & 2147483647) / 1073741824.0f) + 1.0f) / 2.0f;
}

// Return the interpolated noise for the given x, y, and z values. This is done by finding the whole
// number before and after the given position in each dimension. Using these values we can get 6 vertices
// that represent a cube that surrounds the position. We get each of the vertices noise values, and using the
// given position, interpolate between the noise values of the vertices to get the smooth noise.
float smoothNoise(float x, float y, float z)
{
	// Get the truncated x, y, and z values
	int intX = x;
	int intY = y;
	int intZ = z;
	
	// Get the fractional reaminder of x, y, and z
	float fractX = x - intX;
	float fractY = y - intY;
	float fractZ = z - intZ;
	
	// Get first whole number before
	int x1 = (intX + NOISE_DIM) % NOISE_DIM;
	int y1 = (intY + NOISE_DIM) % NOISE_DIM;
	int z1 = (intZ + NOISE_DIM) % NOISE_DIM;
	
	// Get the number after
	int x2 = (x1 + NOISE_DIM - 1) % NOISE_DIM;
	int y2 = (y1 + NOISE_DIM - 1) % NOISE_DIM;
	int z2 = (z1 + NOISE_DIM - 1) % NOISE_DIM;
	
	// Tri-linearly interpolate the noise
	float sumY1Z1 = mix(rand(x2,y1,z1), rand(x1,y1,z1), fractX);
	float sumY1Z2 = mix(rand(x2,y1,z2), rand(x1,y1,z2), fractX);
	float sumY2Z1 = mix(rand(x2,y2,z1), rand(x1,y2,z1), fractX);
	float sumY2Z2 = mix(rand(x2,y2,z2), rand(x1,y2,z2), fractX);
	
	float sumZ1 = mix(sumY2Z1, sumY1Z1, fractY);
	float sumZ2 = mix(sumY2Z2, sumY1Z2, fractY);
	
	float value = mix(sumZ2, sumZ1, fractZ);
	
	return value;
}
	
// Generate perlin noise for the given input values. This is done by generating smooth noise at mutiple
// different sizes and adding them together.
float noise3D(float unscaledX, float unscaledY, float unscaledZ)
{
		// Scale the values to force them in the range [0, NOISE_DIM]
		float x = ((unscaledX - teapotMin) / scaleLength) * NOISE_DIM;
		float y = ((unscaledY - teapotMin) / scaleLength) * NOISE_DIM;
		float z = ((unscaledZ - teapotMin) / scaleLength) * NOISE_DIM;
		
		float value = 0.0f, size = NOISE_SIZE, div = 0.0;
		
		//Add together smooth noise of increasingly smaller size.
		while(size >= 1.0f)
		{
				value += smoothNoise(x / size, y / size, z / size) * size;
				div += size;
				size /= 2.0f;
		}
		value /= div;
		
		return value;
}

	constant float3 darkBrown = float3(0.234f, 0.125f, 0.109f);
	constant float3 lightBrown = float3(0.168f, 0.133f, 0.043f);
	constant float numberOfRings = 84.0;
	constant float turbulence = 0.015;
	constant float PI = 3.14159;

// Calculate the wood color given the position
float3 woodColor(float3 position)
{
		float x = position.x, y = position.y, z = position.z;
		
		// Get the distance of the point from the y-axis to identify whether it will be a ring or not.
		// Get the smooth value for that point to add some randomness to the rings and scale the
		// randomness by a factor called turbulence. Use the cosine function to make the rings and
		// interpolate between the two wood ring colors.
		float distanceValue = sqrt(x*x + z*z) + turbulence * noise3D(x, y, z);
		float cosineValue = fabs(cos(2.0f * numberOfRings * distanceValue * PI));
		
		float3 finalColor = darkBrown + cosineValue * lightBrown;
		return finalColor;
	}

fragment float4 wood_fragment_shader(
		PhongInOut in [[stage_in]],
		constant FragmentUniforms &uniforms [[ buffer(FragmentBufferIndexUniforms) ]])
{
	float3 baseColor = woodColor(in.position_ms);
	float3 ambientColor = baseColor * 0.2;
	
	float n_dot_l = saturate(dot(in.normal_ws, uniforms.light_direction_ws));
	float3 diffuse_color = baseColor * n_dot_l * uniforms.light_color;
	
	
	float3 color = ambientColor + diffuse_color;
	
	return float4(color, 1);
}

