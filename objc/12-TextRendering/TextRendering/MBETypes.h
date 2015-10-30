#import <simd/simd.h>

typedef uint16_t MBEIndexType;

typedef struct
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewProjectionMatrix;
    vector_float4 foregroundColor;
} MBEUniforms;

typedef struct
{
    packed_float4 position;
    packed_float2 texCoords;
} MBEVertex;
