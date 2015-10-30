#include <metal_stdlib>
using namespace metal;

constant float3 kLightDirection(0, 0, -1);

struct InVertex
{
    packed_float4 position [[attribute(0)]];
    packed_float4 normal [[attribute(1)]];
    packed_float2 texCoords [[attribute(2)]];
};

struct ProjectedVertex
{
    float4 position [[position]];
    float3 normal [[user(normal)]];
    float2 texCoords [[user(tex_coords)]];
};

struct Uniforms
{
    float4x4 modelMatrix;
    float3x3 normalMatrix;
    float4x4 modelViewProjectionMatrix;
};

vertex ProjectedVertex vertex_project(constant InVertex *vertices [[buffer(0)]],
                                      constant Uniforms &uniforms [[buffer(1)]],
                                      ushort vid [[vertex_id]])
{
    ProjectedVertex outVert;
    outVert.position = uniforms.modelViewProjectionMatrix * float4(vertices[vid].position);
    outVert.normal = uniforms.normalMatrix * float4(vertices[vid].normal).xyz;
    outVert.texCoords = vertices[vid].texCoords;
    return outVert;
}

fragment half4 fragment_texture(ProjectedVertex vert [[stage_in]],
                                texture2d<float, access::sample> texture [[texture(0)]],
                                sampler texSampler [[sampler(0)]])
{
    float diffuseIntensity = max(0.33, dot(normalize(vert.normal), -kLightDirection));
    float4 diffuseColor = texture.sample(texSampler, vert.texCoords);
    float4 color = diffuseColor * diffuseIntensity;
    return half4(color.r, color.g, color.b, 1);
}
