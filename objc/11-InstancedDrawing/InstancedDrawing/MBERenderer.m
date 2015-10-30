@import Metal;
#import "MBERenderer.h"
#import "MBETerrainMesh.h"
#import "MBEOBJModel.h"
#import "MBEOBJMesh.h"
#import "MBEMatrixUtilities.h"
#import "MBETypes.h"
#import "MBETextureLoader.h"
#import "MBECow.h"

static const size_t MBECowCount = 80;
static const float MBECowSpeed = 0.75;
static const float MBECowTurnDamping = 0.95;

static const float MBETerrainSize = 40;
static const float MBETerrainHeight = 1.5;
static const float MBETerrainSmoothness = 0.95;

static const float MBECameraHeight = 1;

static const vector_float3 Y = { 0, 1, 0 };

static inline float random_unit_float()
{
    return arc4random() / (double)UINT32_MAX;
}

@interface MBERenderer ()
@property (nonatomic, strong) CAMetalLayer *layer;
// Long-lived Metal objects
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> renderPipeline;
@property (nonatomic, strong) id<MTLDepthStencilState> depthState;
@property (nonatomic, strong) id<MTLTexture> depthTexture;
@property (nonatomic, strong) id<MTLSamplerState> sampler;
// Resources
@property (nonatomic, strong) MBETerrainMesh *terrainMesh;
@property (nonatomic, strong) id<MTLTexture> terrainTexture;
@property (nonatomic, strong) MBEMesh *cowMesh;
@property (nonatomic, strong) id<MTLTexture> cowTexture;
@property (nonatomic, strong) id<MTLBuffer> sharedUniformBuffer;
@property (nonatomic, strong) id<MTLBuffer> terrainUniformBuffer;
@property (nonatomic, strong) id<MTLBuffer> cowUniformBuffer;
// Parameters
@property (nonatomic, assign) vector_float3 cameraPosition;
@property (nonatomic, assign) float cameraHeading;
@property (nonatomic, assign) float cameraPitch;
@property (nonatomic, copy) NSArray *cows;
@property (nonatomic, assign) size_t frameCount;
@end

@implementation MBERenderer

- (instancetype)initWithLayer:(CAMetalLayer *)layer
{
    if ((self = [super init]))
    {
        _frameDuration = 1 / 60.0;
        _layer = layer;
        [self buildMetal];
        [self buildPipelines];
        [self buildCows];
        [self buildResources];
    }
    return self;
}

- (void)buildMetal
{
    _device = MTLCreateSystemDefaultDevice();
    _layer.device = _device;
    _layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
}

- (void)buildPipelines
{
    _commandQueue = [_device newCommandQueue];
    
    id<MTLLibrary> library = [_device newDefaultLibrary];
    
    MTLVertexDescriptor *vertexDescriptor = [MTLVertexDescriptor new];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[1].offset = sizeof(vector_float4);
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.attributes[2].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[2].offset = sizeof(vector_float4) * 2;
    vertexDescriptor.attributes[2].bufferIndex = 0;
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    vertexDescriptor.layouts[0].stride = sizeof(MBEVertex);
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"vertex_project"];
    pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"fragment_texture"];
    pipelineDescriptor.vertexDescriptor = vertexDescriptor;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

    NSError *error = nil;
    _renderPipeline = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (!_renderPipeline)
    {
        NSLog(@"Failed to create render pipeline state: %@", error);
    }
    
    MTLDepthStencilDescriptor *depthDescriptor = [MTLDepthStencilDescriptor new];
    depthDescriptor.depthWriteEnabled = YES;
    depthDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    _depthState = [self.device newDepthStencilStateWithDescriptor:depthDescriptor];
    
    MTLSamplerDescriptor *samplerDescriptor = [MTLSamplerDescriptor new];
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterNearest;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeRepeat;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeRepeat;
    _sampler = [_device newSamplerStateWithDescriptor:samplerDescriptor];
}

- (void)buildCows
{
    NSMutableArray *cows = [NSMutableArray arrayWithCapacity:MBECowCount];
    
    for (size_t i = 0; i < MBECowCount; ++i)
    {
        MBECow *cow = [MBECow new];
        
        // Situate the cow somewhere in the internal 80% part of the terrain patch
        float x = (random_unit_float() - 0.5) * MBETerrainSize * 0.8;
        float z = (random_unit_float() - 0.5) * MBETerrainSize * 0.8;
        float y = [self.terrainMesh heightAtPositionX:x z:z];
        
        cow.position = (vector_float3){ x, y, z };
        cow.heading = 2 * M_PI * random_unit_float();
        cow.targetHeading = cow.heading;
        
        [cows addObject:cow];
    }
    
    _cows = [cows copy];
}

- (void)loadMeshes
{
    _terrainMesh = [[MBETerrainMesh alloc] initWithWidth:MBETerrainSize
                                                  height:MBETerrainHeight
                                              iterations:4
                                              smoothness:MBETerrainSmoothness
                                                  device:self.device];

    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"spot" withExtension:@"obj"];
    MBEOBJModel *cowModel = [[MBEOBJModel alloc] initWithContentsOfURL:modelURL generateNormals:YES];
    MBEOBJGroup *spotGroup = [cowModel groupForName:@"spot"];
    _cowMesh = [[MBEOBJMesh alloc] initWithGroup:spotGroup device:_device];
}

- (void)loadTextures
{
    _terrainTexture = [MBETextureLoader texture2DWithImageNamed:@"grass" device:_device];
    [_terrainTexture setLabel:@"Terrain Texture"];
    
    _cowTexture = [MBETextureLoader texture2DWithImageNamed:@"spot" device:_device];
    [_cowTexture setLabel:@"Cow Texture"];
}

- (void)buildUniformBuffers
{
    _sharedUniformBuffer = [_device newBufferWithLength:sizeof(Uniforms)
                                                        options:MTLResourceOptionCPUCacheModeDefault];
    [_sharedUniformBuffer setLabel:@"Shared Uniforms"];
    
    _terrainUniformBuffer = [_device newBufferWithLength:sizeof(PerInstanceUniforms)
                                                         options:MTLResourceOptionCPUCacheModeDefault];
    [_terrainUniformBuffer setLabel:@"Terrain Uniforms"];
    
    _cowUniformBuffer = [_device newBufferWithLength:sizeof(PerInstanceUniforms) * MBECowCount
                                                     options:MTLResourceOptionCPUCacheModeDefault];
    [_cowUniformBuffer setLabel:@"Cow Uniforms"];
}

- (void)buildResources
{
    [self loadMeshes];
    [self loadTextures];
    [self buildUniformBuffers];
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
    
    // limit x and z extent to terrain patch boundaries
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
    
    newPosition.y = [self.terrainMesh heightAtPositionX:newPosition.x z:newPosition.z];
    
    return newPosition;
}

- (void)updateTerrain
{
    PerInstanceUniforms terrainUniforms;
    terrainUniforms.modelMatrix = matrix_identity();
    terrainUniforms.normalMatrix = matrix_upper_left3x3(terrainUniforms.modelMatrix);
    memcpy([self.terrainUniformBuffer contents], &terrainUniforms, sizeof(PerInstanceUniforms));
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
}

- (void)updateCows
{
    for (size_t i = 0; i < MBECowCount; ++i)
    {
        MBECow *cow = self.cows[i];

        // all cows select a new heading every ~4 seconds
        if (self.frameCount % 240 == 0)
            cow.targetHeading = 2 * M_PI * random_unit_float();

        // smooth between the current and intended direction
        cow.heading = (MBECowTurnDamping * cow.heading) + ((1 - MBECowTurnDamping) * cow.targetHeading);
        
        // update cow position based on its orientation, constraining to terrain
        vector_float3 position = cow.position;
        position.x += sin(cow.heading) * MBECowSpeed * self.frameDuration;
        position.z += cos(cow.heading) * MBECowSpeed * self.frameDuration;
        position = [self positionConstrainedToTerrainForPosition:position];
        cow.position = position;

        // build model matrix for cow
        matrix_float4x4 rotation = matrix_rotation(Y, -cow.heading);
        matrix_float4x4 translation = matrix_translation(cow.position);

        // copy matrices into uniform buffers
        PerInstanceUniforms uniforms;
        uniforms.modelMatrix = matrix_multiply(translation, rotation);
        uniforms.normalMatrix = matrix_upper_left3x3(uniforms.modelMatrix);
        memcpy([self.cowUniformBuffer contents] + sizeof(PerInstanceUniforms) * i, &uniforms, sizeof(PerInstanceUniforms));
    }
}

- (void)updateSharedUniforms
{
    matrix_float4x4 viewMatrix = matrix_multiply(matrix_rotation(Y, self.cameraHeading),
                                                 matrix_translation(-self.cameraPosition));
    
    float aspect = self.layer.drawableSize.width / self.layer.drawableSize.height;
    float fov = (aspect > 1) ? (M_PI / 4) : (M_PI / 3);
    matrix_float4x4 projectionMatrix = matrix_perspective_projection(aspect, fov, 0.1, 100);
    
    Uniforms uniforms;
    uniforms.viewProjectionMatrix = matrix_multiply(projectionMatrix, viewMatrix);
    memcpy([self.sharedUniformBuffer contents], &uniforms, sizeof(Uniforms));
}

- (void)updateUniforms
{
    [self updateTerrain];
    [self updateCows];
    [self updateCamera];
    [self updateSharedUniforms];
}

- (MTLRenderPassDescriptor *)createRenderPassWithColorAttachmentTexture:(id<MTLTexture>)texture
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

- (void)drawTerrainWithCommandEncoder:(id<MTLRenderCommandEncoder>)commandEncoder
{
    [commandEncoder setVertexBuffer:self.terrainMesh.vertexBuffer offset:0 atIndex:0];
    [commandEncoder setVertexBuffer:self.sharedUniformBuffer offset:0 atIndex:1];
    [commandEncoder setVertexBuffer:self.terrainUniformBuffer offset:0 atIndex:2];
    [commandEncoder setFragmentTexture:self.terrainTexture atIndex:0];
    [commandEncoder setFragmentSamplerState:self.sampler atIndex:0];
    
    [commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                               indexCount:[self.terrainMesh.indexBuffer length] / sizeof(MBEIndex)
                                indexType:MTLIndexTypeUInt16
                              indexBuffer:self.terrainMesh.indexBuffer
                        indexBufferOffset:0];
}

- (void)drawCowsWithCommandEncoder:(id<MTLRenderCommandEncoder>)commandEncoder
{
    [commandEncoder setVertexBuffer:self.cowMesh.vertexBuffer offset:0 atIndex:0];
    [commandEncoder setVertexBuffer:self.sharedUniformBuffer offset:0 atIndex:1];
    [commandEncoder setVertexBuffer:self.cowUniformBuffer offset:0 atIndex:2];
    [commandEncoder setFragmentTexture:self.cowTexture atIndex:0];
    [commandEncoder setFragmentSamplerState:self.sampler atIndex:0];
    
    [commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                               indexCount:[self.cowMesh.indexBuffer length] / sizeof(MBEIndex)
                                indexType:MTLIndexTypeUInt16
                              indexBuffer:self.cowMesh.indexBuffer
                        indexBufferOffset:0
                            instanceCount:MBECowCount];
}

- (void)draw
{
    [self updateUniforms];

    id<CAMetalDrawable> drawable = [self.layer nextDrawable];

    if (drawable)
    {
        if ([self.depthTexture width] != self.layer.drawableSize.width ||
            [self.depthTexture height] != self.layer.drawableSize.height)
        {
            [self buildDepthTexture];
        }
        
        MTLRenderPassDescriptor *renderPass = [self createRenderPassWithColorAttachmentTexture:[drawable texture]];

        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];

        id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
        [commandEncoder setRenderPipelineState:self.renderPipeline];
        [commandEncoder setDepthStencilState:self.depthState];
        [commandEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
        [commandEncoder setCullMode:MTLCullModeBack];
        
        [self drawTerrainWithCommandEncoder:commandEncoder];
        [self drawCowsWithCommandEncoder:commandEncoder];

        [commandEncoder endEncoding];
        
        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
        
        ++self.frameCount;
    }
}

@end
