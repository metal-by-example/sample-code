#include <metal_stdlib>
using namespace metal;

constant float3 kLightDirection(0, 0, -1);

struct InVertex
{
    float4 position [[attribute(0)]];
    float4 normal [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
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

vertex ProjectedVertex vertex_project(InVertex inVertex [[stage_in]],
                                      constant Uniforms &uniforms [[buffer(1)]])
{
    ProjectedVertex outVert;
    outVert.position = uniforms.modelViewProjectionMatrix * float4(inVertex.position);
    outVert.normal = uniforms.normalMatrix * float4(inVertex.normal).xyz;
    outVert.texCoords = inVertex.texCoords;
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
