#include <metal_stdlib>

using namespace metal;

// some common indices of refraction
constant float kEtaAir = 1.000277;
//constant float kEtaWater = 1.333;
constant float kEtaGlass = 1.5;

constant float kEtaRatio = kEtaAir / kEtaGlass;

struct Vertex
{
    float4 position [[attribute(0)]];
    float4 normal [[attribute(1)]];
};

struct ProjectedVertex
{
    float4 position [[position]];
    float4 texCoords;
};

struct Uniforms
{
    float4x4 modelMatrix;
    float4x4 projectionMatrix;
    float4x4 normalMatrix;
    float4x4 modelViewProjectionMatrix;
    float4 worldCameraPosition;
};

vertex ProjectedVertex vertex_skybox(Vertex inVertex             [[stage_in]],
                                     constant Uniforms &uniforms [[buffer(1)]],
                                     uint vid                    [[vertex_id]])
{
    float4 position = inVertex.position;
    
    ProjectedVertex outVert;
    outVert.position = uniforms.modelViewProjectionMatrix * position;
    outVert.texCoords = position;
    return outVert;
}

vertex ProjectedVertex vertex_reflect(Vertex inVertex             [[stage_in]],
                                      constant Uniforms &uniforms [[buffer(1)]],
                                      uint vid                    [[vertex_id]])
{
    float4 modelPosition = inVertex.position;
    float4 modelNormal = inVertex.normal;
    
    float4 worldCameraPosition = uniforms.worldCameraPosition;
    float4 worldPosition = uniforms.modelMatrix * modelPosition;
    float4 worldNormal = normalize(uniforms.normalMatrix * modelNormal);
    float4 worldEyeDirection = normalize(worldPosition - worldCameraPosition);
    
    ProjectedVertex outVert;
    outVert.position = uniforms.modelViewProjectionMatrix * modelPosition;
    outVert.texCoords = reflect(worldEyeDirection, worldNormal);
    
    return outVert;
}

vertex ProjectedVertex vertex_refract(Vertex inVertex             [[stage_in]],
                                      constant Uniforms &uniforms [[buffer(1)]],
                                      uint vid                    [[vertex_id]])
{
    float4 modelPosition = inVertex.position;
    float4 modelNormal = inVertex.normal;

    float4 worldCameraPosition = uniforms.worldCameraPosition;
    float4 worldPosition = uniforms.modelMatrix * modelPosition;
    float4 worldNormal = normalize(uniforms.normalMatrix * modelNormal);
    float4 worldEyeDirection = normalize(worldPosition - worldCameraPosition);

    ProjectedVertex outVert;
    outVert.position = uniforms.modelViewProjectionMatrix * modelPosition;
    outVert.texCoords = refract(worldEyeDirection, worldNormal, kEtaRatio);

    return outVert;
}

fragment half4 fragment_cube_lookup(ProjectedVertex vert          [[stage_in]],
                                    constant Uniforms &uniforms   [[buffer(0)]],
                                    texturecube<half> cubeTexture [[texture(0)]],
                                    sampler cubeSampler           [[sampler(0)]])
{
    float3 texCoords = float3(vert.texCoords.x, vert.texCoords.y, -vert.texCoords.z);
    return cubeTexture.sample(cubeSampler, texCoords);
}
