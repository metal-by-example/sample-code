@import simd;

typedef struct
{
    simd_float4x4 modelMatrix;
    simd_float4x4 projectionMatrix;
    simd_float4x4 normalMatrix;
    simd_float4x4 modelViewProjectionMatrix;
    simd_float4 worldCameraPosition;
} MBEUniforms;

typedef struct
{
    simd_float4 position;
    simd_float4 normal;
} MBEVertex;
