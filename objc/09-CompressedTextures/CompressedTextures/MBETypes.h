@import simd;

typedef uint16_t MBEIndexType;

typedef struct __attribute((packed))
{
    vector_float4 position;
    vector_float2 texCoords;
} MBEVertex;

typedef struct __attribute((packed))
{
    matrix_float4x4 modelViewProjectionMatrix;
} MBEUniforms;

