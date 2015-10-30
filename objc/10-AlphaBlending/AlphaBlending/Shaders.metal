#include <metal_stdlib>
using namespace metal;

constant float3 kLightDirection(0.2, -0.96, 0.2);

constant float kMinDiffuseIntensity = 0.5;

constant float kAlphaTestReferenceValue = 0.5;

struct Vertex
{
    packed_float4 position [[attribute(0)]];
    packed_float4 normal [[attribute(1)]];
    packed_float4 diffuseColor [[attribute(2)]];
    packed_float2 texCoords [[attribute(3)]];
};

struct ProjectedVertex
{
    float4 position [[position]];
    float4 normal;
    float4 diffuseColor;
    float2 texCoords;
};

struct Uniforms
{
    float4x4 viewProjectionMatrix;
};

struct InstanceUniforms
{
    float4x4 modelMatrix;
    float4x4 normalMatrix;
};

vertex ProjectedVertex project_vertex(constant Vertex *vertices [[buffer(0)]],
                                      constant Uniforms &uniforms [[buffer(1)]],
                                      constant InstanceUniforms *instanceUniforms [[buffer(2)]],
                                      ushort vid [[vertex_id]],
                                      ushort iid [[instance_id]])
{
    float4x4 modelMatrix = instanceUniforms[iid].modelMatrix;
    float4x4 normalMatrix = instanceUniforms[iid].normalMatrix;

    ProjectedVertex outVert;
    outVert.position = uniforms.viewProjectionMatrix * modelMatrix * float4(vertices[vid].position);
    outVert.normal = normalMatrix * float4(vertices[vid].normal);
    outVert.diffuseColor = vertices[vid].diffuseColor;
    outVert.texCoords = vertices[vid].texCoords;

    return outVert;
}

fragment half4 texture_fragment(ProjectedVertex vert [[stage_in]],
                                texture2d<float, access::sample> texture [[texture(0)]],
                                sampler texSampler [[sampler(0)]])
{
    float4 vertexColor = vert.diffuseColor;
    float4 textureColor = texture.sample(texSampler, vert.texCoords);

    float diffuseIntensity = max(kMinDiffuseIntensity, dot(normalize(vert.normal.xyz), -kLightDirection));
    float4 color = diffuseIntensity * textureColor * vertexColor;

    return half4(color.r, color.g, color.b, vertexColor.a);
}

fragment half4 texture_fragment_alpha_test(ProjectedVertex vert [[stage_in]],
                                           texture2d<float, access::sample> texture [[texture(0)]],
                                           sampler texSampler [[sampler(0)]])
{
    float4 vertexColor = float4(vert.diffuseColor);
    float4 textureColor = texture.sample(texSampler, vert.texCoords);

    float diffuseIntensity = max(kMinDiffuseIntensity, dot(normalize(vert.normal.xyz), -kLightDirection));
    float4 color = diffuseIntensity * textureColor * vertexColor;

    if (textureColor.a < kAlphaTestReferenceValue)
        discard_fragment();

    return half4(color.r, color.g, color.b, vertexColor.a);
}

