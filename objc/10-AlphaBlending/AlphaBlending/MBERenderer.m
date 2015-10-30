#import "MBERenderer.h"
#import "MBETerrainMesh.h"
#import "MBEMathUtilities.h"
#import "MBETypes.h"
#import "MBETextureLoader.h"
#import "MBEOBJModel.h"
#import "MBEOBJMesh.h"
#import "MBEPlaneMesh.h"
#import "MBEMaterial.h"

static const float MBETerrainSize = 64;
static const float MBETerrainHeight = 2.5;
static const float MBETerrainSmoothness = 0.95;

static const float MBEWaterLevel = -0.5;

static const size_t MBETreeCount = 200;
static const float MBECameraHeight = 0.3;

static const size_t MBESharedUniformOffset = 0;
static const size_t MBETerrainUniformOffset = MBESharedUniformOffset + sizeof(Uniforms);
static const size_t MBEWaterUniformOffset = MBETerrainUniformOffset + sizeof(InstanceUniforms);
static const size_t MBETreeUniformOffset = MBEWaterUniformOffset + sizeof(InstanceUniforms);

@interface MBERenderer ()
@property (nonatomic, strong) CAMetalLayer *layer;
// Long-lived Metal objects
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLTexture> depthTexture;
@property (nonatomic, strong) id<MTLSamplerState> sampler;
// Resources
@property (nonatomic, strong) MBETerrainMesh *terrainMesh;
@property (nonatomic, strong) MBEMesh *waterMesh;
@property (nonatomic, strong) MBEMesh *treeMesh;
@property (nonatomic, strong) MBEMaterial *terrainMaterial;
@property (nonatomic, strong) MBEMaterial *waterMaterial;
@property (nonatomic, strong) MBEMaterial *treeMaterial;
@property (nonatomic, strong) id<MTLBuffer> uniformBuffer;
// Parameters
@property (nonatomic, assign) vector_float3 cameraPosition;
@property (nonatomic, assign) float cameraHeading;
@end

@implementation MBERenderer

- (instancetype)initWithLayer:(CAMetalLayer *)layer
{
    if ((self = [super init]))
    {
        _layer = layer;
        [self buildMetal];
        [self buildResources];
    }
    return self;
}

- (void)buildMetal
{
    _device = MTLCreateSystemDefaultDevice();
    _layer.device = _device;
    _layer.pixelFormat = MTLPixelFormatBGRA8Unorm;

    _commandQueue = [_device newCommandQueue];

    MTLSamplerDescriptor *samplerDescriptor = [MTLSamplerDescriptor new];
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterNearest;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.mipFilter = MTLSamplerMipFilterLinear;
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeRepeat;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeRepeat;
    _sampler = [_device newSamplerStateWithDescriptor:samplerDescriptor];
}

- (void)buildResources
{
    [self loadMeshes];
    [self loadTextures];
    [self buildUniformBuffer];
    [self populateTerrainUniforms];
    [self populateWaterUniforms];
    [self populateTreeUniforms];
}

- (void)loadMeshes
{
    _terrainMesh = [[MBETerrainMesh alloc] initWithWidth:MBETerrainSize
                                                  height:MBETerrainHeight
                                              iterations:6
                                              smoothness:MBETerrainSmoothness
                                                  device:self.device];

    _waterMesh = [[MBEPlaneMesh alloc] initWithWidth:MBETerrainSize
                                               depth:MBETerrainSize
                                          divisionsX:32
                                          divisionsZ:32
                                        textureScale:10
                                             opacity:0.2
                                              device:_device];

    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"palm" withExtension:@"obj"];
    MBEOBJModel *treeModel = [[MBEOBJModel alloc] initWithContentsOfURL:modelURL generateNormals:YES];
    if (treeModel)
    {
        MBEOBJGroup *group = [treeModel groupForName:@"palm"];
        if (group)
        {
            _treeMesh = [[MBEOBJMesh alloc] initWithGroup:group device:_device];
        }
    }
}

- (void)loadTextures
{
    MBETextureLoader *textureLoader = [MBETextureLoader sharedTextureLoader];

    id<MTLTexture> terrainTexture = [textureLoader texture2DWithImageNamed:@"sand" mipmapped:YES device:_device];
    _terrainMaterial = [[MBEMaterial alloc] initWithDiffuseTexture:terrainTexture
                                                  alphaTestEnabled:NO
                                                   blendingEnabled:NO
                                                 depthWriteEnabled:YES
                                                            device:_device];

    id<MTLTexture> treeTexture = [textureLoader texture2DWithImageNamed:@"palm_diffuse" mipmapped:YES device:_device];
    _treeMaterial = [[MBEMaterial alloc] initWithDiffuseTexture:treeTexture
                                               alphaTestEnabled:YES
                                                blendingEnabled:NO
                                              depthWriteEnabled:YES
                                                         device:_device];

    id<MTLTexture> waterTexture = [textureLoader texture2DWithImageNamed:@"water" mipmapped:YES device:_device];
    _waterMaterial = [[MBEMaterial alloc] initWithDiffuseTexture:waterTexture
                                                alphaTestEnabled:NO
                                                 blendingEnabled:YES
                                               depthWriteEnabled:NO
                                                          device:_device];
}

- (void)buildUniformBuffer
{
    size_t uniformBufferLength = MBETreeUniformOffset + sizeof(InstanceUniforms) * MBETreeCount;
    _uniformBuffer = [_device newBufferWithLength:uniformBufferLength options:MTLResourceOptionCPUCacheModeDefault];
    [_uniformBuffer setLabel:@"Uniforms"];
}

- (void)populateTerrainUniforms
{
    matrix_float4x4 terrainModelMatrix = matrix_identity();

    InstanceUniforms terrainUniforms;
    terrainUniforms.modelMatrix = terrainModelMatrix;
    terrainUniforms.normalMatrix = matrix_transpose(matrix_invert(matrix_extract_linear(terrainModelMatrix)));
    memcpy([self.uniformBuffer contents] + MBETerrainUniformOffset, &terrainUniforms, sizeof(InstanceUniforms));
}

- (void)populateWaterUniforms
{
    vector_float3 waterOffsetVector = { 0, MBEWaterLevel, 0 };
    matrix_float4x4 waterModelmatrix = matrix_translation(waterOffsetVector);

    InstanceUniforms waterUniforms;
    waterUniforms.modelMatrix = waterModelmatrix;
    waterUniforms.normalMatrix = matrix_transpose(matrix_invert(matrix_extract_linear(waterModelmatrix)));
    memcpy([self.uniformBuffer contents] + MBEWaterUniformOffset, &waterUniforms, sizeof(InstanceUniforms));
}

- (void)populateTreeUniforms
{
    for (int i = 0; i < MBETreeCount; ++i)
    {
        const float halfTerrainWidth = self.terrainMesh.width / 2;
        const float halfTerrainDepth = self.terrainMesh.depth / 2;

        vector_float3 position = { 0, 0, 0 };
        BOOL onLand = NO;

        // Attempt to place the palm tree on dry land
        // This will spin forever if the water level is too high
        while (!onLand)
        {
            position.x = random_float(-halfTerrainWidth, halfTerrainWidth);
            position.z = random_float(-halfTerrainDepth, halfTerrainDepth);
            position.y = [self.terrainMesh heightAtPositionX:position.x z:position.z];

            onLand = (position.y > MBEWaterLevel);
        }

        matrix_float4x4 modelMatrix = matrix_translation(position);

        InstanceUniforms uniforms;
        uniforms.modelMatrix = modelMatrix;
        uniforms.normalMatrix = matrix_transpose(matrix_invert(matrix_extract_linear(modelMatrix)));

        uint8_t *treeUniformArray = [self.uniformBuffer contents] + MBETreeUniformOffset;
        memcpy(treeUniformArray + (i * sizeof(InstanceUniforms)), &uniforms, sizeof(InstanceUniforms));
    }
}

- (void)buildDepthTexture
{
    CGSize drawableSize = self.layer.drawableSize;
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                                                                          width:drawableSize.width
                                                                                         height:drawableSize.height
                                                                                      mipmapped:NO];
    self.depthTexture = [self.device newTextureWithDescriptor:descriptor];
    [self.depthTexture setLabel:@"Depth Texture"];
}

- (vector_float3)positionConstrainedToTerrainForPosition:(vector_float3)position
{
    vector_float3 newPosition = position;

    // Limit x and z extent to terrain patch boundaries
    const float halfWidth = self.terrainMesh.width * 0.5;
    const float halfDepth = self.terrainMesh.depth * 0.5;

    if (newPosition.x < -halfWidth)
        newPosition.x = -halfWidth;
    else if (newPosition.x > halfWidth)
        newPosition.x = halfWidth;

    if (newPosition.z < -halfDepth)
        newPosition.z = -halfDepth;
    else if (newPosition.z > halfDepth)
        newPosition.z = halfDepth;

    // Prevent the camera from going below the terrain surface
    newPosition.y = [self.terrainMesh heightAtPositionX:newPosition.x z:newPosition.z];

    // Prevent the camera from going below the water surface
    if (newPosition.y < MBEWaterLevel)
        newPosition.y = MBEWaterLevel;

    return newPosition;
}

- (void)updateCamera
{
    vector_float3 cameraPosition = self.cameraPosition;

    self.cameraHeading += self.angularVelocity * self.frameDuration;

    // update camera location based on current heading
    cameraPosition.x += -sin(self.cameraHeading) * self.velocity * self.frameDuration;
    cameraPosition.z += -cos(self.cameraHeading) * self.velocity * self.frameDuration;
    cameraPosition = [self positionConstrainedToTerrainForPosition:cameraPosition];
    cameraPosition.y += MBECameraHeight;

    self.cameraPosition = cameraPosition;

    static const vector_float3 Y = { 0, 1, 0 };

    matrix_float4x4 viewMatrix = matrix_multiply(matrix_rotation(Y, self.cameraHeading), matrix_translation(-self.cameraPosition));

    float aspect = self.layer.drawableSize.width / self.layer.drawableSize.height;
    float fov = (aspect > 1) ? (M_PI / 4) : (M_PI / 3);
    matrix_float4x4 projectionMatrix = matrix_perspective_projection(aspect, fov, 0.1, 100);

    Uniforms uniforms;
    uniforms.viewProjectionMatrix = matrix_multiply(projectionMatrix, viewMatrix);
    memcpy([self.uniformBuffer contents] + MBESharedUniformOffset, &uniforms, sizeof(Uniforms));
}

- (MTLRenderPassDescriptor *)newRenderPassWithColorAttachmentTexture:(id<MTLTexture>)texture
{
    MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor new];

    renderPass.colorAttachments[0].texture = texture;
    renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.2, 0.5, 0.95, 1.0);

    renderPass.depthAttachment.texture = self.depthTexture;
    renderPass.depthAttachment.loadAction = MTLLoadActionClear;
    renderPass.depthAttachment.storeAction = MTLStoreActionStore;
    renderPass.depthAttachment.clearDepth = 1.0;

    return renderPass;
}

- (void)drawInstancedMesh:(MBEMesh *)mesh
       withCommandEncoder:(id<MTLRenderCommandEncoder>)commandEncoder
                 material:(MBEMaterial *)material
            instanceCount:(uint32_t)instanceCount
{
    [commandEncoder setRenderPipelineState:material.pipelineState];

    [commandEncoder setDepthStencilState:material.depthState];

    [commandEncoder setFragmentSamplerState:self.sampler atIndex:0];

    [commandEncoder setVertexBuffer:mesh.vertexBuffer offset:0 atIndex:0];

    [commandEncoder setFragmentTexture:material.diffuseTexture atIndex:0];

    [commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                               indexCount:[mesh.indexBuffer length] / sizeof(MBEIndex)
                                indexType:MTLIndexTypeUInt16
                              indexBuffer:mesh.indexBuffer
                        indexBufferOffset:0
                            instanceCount:instanceCount];
}

- (void)draw
{
    [self updateCamera];

    id<CAMetalDrawable> drawable = [self.layer nextDrawable];

    if (drawable)
    {
        if ([self.depthTexture width] != self.layer.drawableSize.width ||
            [self.depthTexture height] != self.layer.drawableSize.height)
        {
            [self buildDepthTexture];
        }

        MTLRenderPassDescriptor *renderPass = [self newRenderPassWithColorAttachmentTexture:[drawable texture]];

        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];

        id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
        [commandEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
        [commandEncoder setCullMode:MTLCullModeNone];

        // Set the shared uniforms as vertex buffer at index 1
        [commandEncoder setVertexBuffer:self.uniformBuffer offset:MBESharedUniformOffset atIndex:1];

        // Set terrain uniforms as vertex buffer at index 2 and draw terrain
        [commandEncoder setVertexBuffer:self.uniformBuffer offset:MBETerrainUniformOffset atIndex:2];
        [self drawInstancedMesh:self.terrainMesh
             withCommandEncoder:commandEncoder
                       material:self.terrainMaterial
                  instanceCount:1];

        // Set palm tree uniforms as vertex buffer at index 2 and draw trees
        [commandEncoder setVertexBuffer:self.uniformBuffer offset:MBETreeUniformOffset atIndex:2];
        [self drawInstancedMesh:self.treeMesh
             withCommandEncoder:commandEncoder
                       material:self.treeMaterial
                  instanceCount:MBETreeCount];

        // Set water surface uniforms as vertex buffer at index 2 and draw water surface
        // Order is important here, since the water material uses alpha blending,
        // and all translucent surfaces must be drawn last to blend properly.
        [commandEncoder setVertexBuffer:self.uniformBuffer offset:MBEWaterUniformOffset atIndex:2];
        [self drawInstancedMesh:self.waterMesh
             withCommandEncoder:commandEncoder
                       material:self.waterMaterial
                  instanceCount:1];
        
        [commandEncoder endEncoding];
        
        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
    }
}

@end
