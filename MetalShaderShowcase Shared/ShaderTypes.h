#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
typedef metal::int32_t EnumBackingType;
#else
#import <Foundation/Foundation.h>
typedef NSInteger EnumBackingType;
#endif

#include <simd/simd.h>

typedef NS_ENUM(EnumBackingType, VertexBufferIndex)
{
	VertexBufferIndexPositions = 0,
	VertexBufferIndexNormal,
	
	VertexBufferIndexUniforms,
};

typedef NS_ENUM(EnumBackingType, FragmentBufferIndex)
{
	FragmentBufferIndexUniforms = 0,
};

struct VertexUniforms {
	matrix_float4x4 modelTransform;
	matrix_float4x4 viewTransform;
	matrix_float4x4 projectionTransform;
};

struct FragmentUniforms {
	simd_float3 light_direction_ws;
	simd_float3 light_color;
	
	simd_float3 eye_direction_ws;
};

struct PhongMaterial {
	simd_float3 ambientColor;
	simd_float3 diffuseColor;
	simd_float3 specularColor;
	float materialShine;
};

#endif /* ShaderTypes_h */

