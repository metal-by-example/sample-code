#include <metal_stdlib>
using namespace metal;

constant float3 kLightDirection(-0.43, -0.8, -0.43);

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
    float4x4 viewProjectionMatrix;
};

struct PerInstanceUniforms
{
    float4x4 modelMatrix;
    float3x3 normalMatrix;
};

vertex ProjectedVertex vertex_project(device InVertex *vertices [[buffer(0)]],
                                      constant Uniforms &uniforms [[buffer(1)]],
                                      constant PerInstanceUniforms *perInstanceUniforms [[buffer(2)]],
                                      ushort vid [[vertex_id]],
                                      ushort iid [[instance_id]])
{
    float4x4 instanceModelMatrix = perInstanceUniforms[iid].modelMatrix;
    float3x3 instanceNormalMatrix = perInstanceUniforms[iid].normalMatrix;
    
    ProjectedVertex outVert;
    outVert.position = uniforms.viewProjectionMatrix * instanceModelMatrix * float4(vertices[vid].position);
    outVert.normal = instanceNormalMatrix * float4(vertices[vid].normal).xyz;
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
