#import <simd/simd.h>

typedef uint16_t MBEIndex;

typedef struct
{
    matrix_float4x4 viewProjectionMatrix;
} Uniforms;

typedef struct
{
    matrix_float4x4 modelMatrix;
    matrix_float4x4 normalMatrix;
} InstanceUniforms;

typedef struct
{
    packed_float4 position;
    packed_float4 normal;
    packed_float4 diffuseColor;
    packed_float2 texCoords;
} MBEVertex;
