#include <metal_stdlib>
using namespace metal;

struct Uniforms
{
    float4x4 modelViewProjectionMatrix;
};

struct Vertex
{
    packed_float4 position;
    packed_float2 texCoords;
};

struct ProjectedVertex
{
    float4 position [[position]];
    float2 texCoords [[user(texcoords)]];
};

vertex ProjectedVertex vertex_main(device Vertex *vertices [[buffer(0)]],
                                   constant Uniforms *uniforms [[buffer(1)]],
                                   uint vertexID [[vertex_id]])
{
    float4 position = vertices[vertexID].position;
    float2 texCoords = vertices[vertexID].texCoords;

    ProjectedVertex outVert;
    outVert.position = uniforms->modelViewProjectionMatrix * position;
    outVert.texCoords = texCoords;
    return outVert;
}

fragment half4 fragment_main(ProjectedVertex inVert [[stage_in]],
                             texture2d<float, access::sample> diffuseTexture [[texture(0)]],
                             sampler textureSampler [[sampler(0)]])
{
    float4 color = diffuseTexture.sample(textureSampler, inVert.texCoords);

    if (color.a < 0.5)
        discard_fragment();

    return half4(color);
}