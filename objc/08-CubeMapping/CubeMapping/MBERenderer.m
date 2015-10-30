#import "MBERenderer.h"
#import "MBETextureLoader.h"
#import "MBESkyboxMesh.h"
#import "MBETorusKnotMesh.h"
#import "MBETypes.h"
#import "MBEMatrixUtilities.h"

@interface MBERenderer ()
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLLibrary> library;
@property (nonatomic, strong) id<MTLRenderPipelineState> skyboxPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> torusReflectPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> torusRefractPipeline;
@property (nonatomic, strong) id<MTLBuffer> uniformBuffer;
@property (nonatomic, strong) id<MTLTexture> depthTexture;
@property (nonatomic, strong) id<MTLTexture> cubeTexture;
@property (nonatomic, strong) id<MTLSamplerState> samplerState;
@property (nonatomic, strong) MBEMesh *skybox;
@property (nonatomic, strong) MBEMesh *torus;
@property (nonatomic, assign) CGFloat rotationAngle;
@end

@implementation MBERenderer

- (instancetype)initWithLayer:(CAMetalLayer *)layer
{
    self = [super init];
    
    if (self)
    {
        [self buildMetal];
        [self buildPipelines];
        [self buildResources];
        
        _layer = layer;
        _layer.device = _device;
    }
    return self;
}

- (void)buildMetal
{
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];
    _library = [_device newDefaultLibrary];
}

- (id<MTLRenderPipelineState>)pipelineForVertexFunctionNamed:(NSString *)vertexFunctionName
                                       fragmentFunctionNamed:(NSString *)fragmentFunctionName
{
    MTLVertexDescriptor *vertexDescriptor = [MTLVertexDescriptor new];
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat4;
    
    vertexDescriptor.attributes[1].offset = sizeof(vector_float4);
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    vertexDescriptor.layouts[0].stride = sizeof(MBEVertex);
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = [_library newFunctionWithName:vertexFunctionName];
    pipelineDescriptor.fragmentFunction = [_library newFunctionWithName:fragmentFunctionName];
    pipelineDescriptor.vertexDescriptor = vertexDescriptor;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    
    NSError *error = nil;
    id<MTLRenderPipelineState> pipeline = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (!pipeline)
    {
        NSLog(@"Error occurred while creating render pipeline: %@", error);
    }
    
    return pipeline;
}

- (void)buildPipelines
{
    self.skyboxPipeline = [self pipelineForVertexFunctionNamed:@"vertex_skybox"
                                         fragmentFunctionNamed:@"fragment_cube_lookup"];
    
    self.torusReflectPipeline = [self pipelineForVertexFunctionNamed:@"vertex_reflect"
                                               fragmentFunctionNamed:@"fragment_cube_lookup"];

    self.torusRefractPipeline = [self pipelineForVertexFunctionNamed:@"vertex_refract"
                                               fragmentFunctionNamed:@"fragment_cube_lookup"];
}

- (void)buildResources
{
    NSArray *imageNames = @[@"px", @"nx", @"py", @"ny", @"pz", @"nz"];
    self.cubeTexture = [MBETextureLoader textureCubeWithImagesNamed:imageNames device:self.device];

    self.skybox = [[MBESkyboxMesh alloc] initWithDevice:self.device];
    
    self.torus = [[MBETorusKnotMesh alloc] initWithParameters:@[@3, @8]
                                                   tubeRadius:0.2
                                                 tubeSegments:256
                                                   tubeSlices:32
                                                       device:self.device];

    self.uniformBuffer = [self.device newBufferWithLength:sizeof(MBEUniforms) * 2
                                                  options:MTLResourceOptionCPUCacheModeDefault];
    
    MTLSamplerDescriptor *samplerDescriptor = [MTLSamplerDescriptor new];
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterNearest;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    self.samplerState = [self.device newSamplerStateWithDescriptor:samplerDescriptor];
}

- (void)buildDepthBuffer
{
    CGSize drawableSize = self.layer.drawableSize;
    MTLTextureDescriptor *depthTexDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                                                                            width:drawableSize.width
                                                                                           height:drawableSize.height
                                                                                        mipmapped:NO];
    self.depthTexture = [self.device newTextureWithDescriptor:depthTexDesc];
}

- (void)drawSkyboxWithCommandEncoder:(id<MTLRenderCommandEncoder>)commandEncoder
{
    MTLDepthStencilDescriptor *depthDescriptor = [MTLDepthStencilDescriptor new];
    depthDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    depthDescriptor.depthWriteEnabled = NO;
    id <MTLDepthStencilState> depthState = [self.device newDepthStencilStateWithDescriptor:depthDescriptor];

    [commandEncoder setRenderPipelineState:self.skyboxPipeline];
    [commandEncoder setDepthStencilState:depthState];
    [commandEncoder setVertexBuffer:self.skybox.vertexBuffer offset:0 atIndex:0];
    [commandEncoder setVertexBuffer:self.uniformBuffer offset:0 atIndex:1];
    [commandEncoder setFragmentBuffer:self.uniformBuffer offset:0 atIndex:0];
    [commandEncoder setFragmentTexture:self.cubeTexture atIndex:0];
    [commandEncoder setFragmentSamplerState:self.samplerState atIndex:0];

    [commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                               indexCount:[self.skybox.indexBuffer length] / sizeof(UInt16)
                                indexType:MTLIndexTypeUInt16
                              indexBuffer:self.skybox.indexBuffer
                        indexBufferOffset:0];
}

- (void)drawTorusWithCommandEncoder:(id<MTLRenderCommandEncoder>)commandEncoder
{
    MTLDepthStencilDescriptor *depthDescriptor = [MTLDepthStencilDescriptor new];
    depthDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    depthDescriptor.depthWriteEnabled = YES;
    id <MTLDepthStencilState> depthState = [self.device newDepthStencilStateWithDescriptor:depthDescriptor];

    [commandEncoder setRenderPipelineState:self.useRefractionMaterial ? self.torusRefractPipeline : self.torusReflectPipeline];
    [commandEncoder setDepthStencilState:depthState];
    [commandEncoder setVertexBuffer:self.torus.vertexBuffer offset:0 atIndex:0];
    [commandEncoder setVertexBuffer:self.uniformBuffer offset:sizeof(MBEUniforms) atIndex:1];
    [commandEncoder setFragmentBuffer:self.uniformBuffer offset:sizeof(MBEUniforms) atIndex:0];
    [commandEncoder setFragmentTexture:self.cubeTexture atIndex:0];
    [commandEncoder setFragmentSamplerState:self.samplerState atIndex:0];
    
    [commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                               indexCount:[self.torus.indexBuffer length] / sizeof(UInt16)
                                indexType:MTLIndexTypeUInt16
                              indexBuffer:self.torus.indexBuffer
                        indexBufferOffset:0];
}

- (MTLRenderPassDescriptor *)renderPassForDrawable:(id<CAMetalDrawable>)drawable
{
    MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor renderPassDescriptor];

    renderPass.colorAttachments[0].texture = drawable.texture;
    renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPass.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1);
    
    renderPass.depthAttachment.texture = self.depthTexture;
    renderPass.depthAttachment.loadAction = MTLLoadActionClear;
    renderPass.depthAttachment.storeAction = MTLStoreActionDontCare;
    renderPass.depthAttachment.clearDepth = 1;
    
    return renderPass;
}

- (void)updateUniforms
{
    static const vector_float4 cameraPosition = { 0, 0, -4, 1 };

    const CGSize size = self.layer.bounds.size;
    const CGFloat aspectRatio = size.width / size.height;
    const CGFloat verticalFOV = (aspectRatio > 1) ? 60 : 90;
    static const CGFloat near = 0.1;
    static const CGFloat far = 100;
    
    matrix_float4x4 projectionMatrix = perspective_projection(aspectRatio, verticalFOV * (M_PI / 180), near, far);
    matrix_float4x4 modelMatrix = identity();
    matrix_float4x4 skyboxViewMatrix = self.sceneOrientation;
    matrix_float4x4 torusViewMatrix = matrix_multiply(translation(cameraPosition), self.sceneOrientation);
    vector_float4 worldCameraPosition = matrix_multiply(matrix_invert(self.sceneOrientation), -cameraPosition);

    MBEUniforms skyboxUniforms;
    skyboxUniforms.modelMatrix = modelMatrix;
    skyboxUniforms.projectionMatrix = projectionMatrix;
    skyboxUniforms.normalMatrix = matrix_transpose(matrix_invert(skyboxUniforms.modelMatrix));
    skyboxUniforms.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, matrix_multiply(skyboxViewMatrix, modelMatrix));
    skyboxUniforms.worldCameraPosition = worldCameraPosition;
    memcpy(self.uniformBuffer.contents, &skyboxUniforms, sizeof(MBEUniforms));

    MBEUniforms torusUniforms;
    torusUniforms.modelMatrix = modelMatrix;
    torusUniforms.projectionMatrix = projectionMatrix;
    torusUniforms.normalMatrix = matrix_transpose(matrix_invert(torusUniforms.modelMatrix));
    torusUniforms.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, matrix_multiply(torusViewMatrix, modelMatrix));
    torusUniforms.worldCameraPosition = worldCameraPosition;
    memcpy(self.uniformBuffer.contents + sizeof(MBEUniforms), &torusUniforms, sizeof(MBEUniforms));
}

- (void)draw
{
    CGSize drawableSize = self.layer.drawableSize;
    if (self.depthTexture.width != drawableSize.width || self.depthTexture.height != drawableSize.height)
    {
        [self buildDepthBuffer];
    }
    
    id<CAMetalDrawable> drawable = [self.layer nextDrawable];
    if (drawable)
    {
        [self updateUniforms];

        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
        
        MTLRenderPassDescriptor *renderPass = [self renderPassForDrawable:drawable];
        
        id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
        [commandEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
        [commandEncoder setCullMode:MTLCullModeBack];
        
        [self drawSkyboxWithCommandEncoder:commandEncoder];
        [self drawTorusWithCommandEncoder:commandEncoder];

        [commandEncoder endEncoding];
        
        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
    }
}

@end
