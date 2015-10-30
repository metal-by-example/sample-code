@import simd;

typedef uint16_t MBEIndex;

typedef struct
{
    matrix_float4x4 modelMatrix;
    matrix_float3x3 normalMatrix;
    matrix_float4x4 modelViewProjectionMatrix;
} MBEUniforms;

typedef struct
{
    packed_float4 position;
    packed_float4 normal;
    packed_float2 texCoords;
} MBEVertex;
