#import "MBERenderer.h"
#import "MBETextureGenerator.h"
#import "MBECubeMesh.h"
#import "MBETypes.h"
#import "MBEMatrixUtilities.h"

static const vector_float3 X = { 1, 0, 0 };
static const vector_float3 Y = { 0, 1, 0 };

@interface MBERenderer ()
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLLibrary> library;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipeline;
@property (nonatomic, strong) id<MTLBuffer> uniformBuffer;
@property (nonatomic, strong) id<MTLTexture> depthTexture;
@property (nonatomic, strong) id<MTLTexture> checkerTexture;
@property (nonatomic, strong) id<MTLTexture> vibrantCheckerTexture;
@property (nonatomic, strong) id<MTLDepthStencilState> depthState;
@property (nonatomic, strong) id<MTLSamplerState> notMipSamplerState;
@property (nonatomic, strong) id<MTLSamplerState> nearestMipSamplerState;
@property (nonatomic, strong) id<MTLSamplerState> linearMipSamplerState;
@property (nonatomic, strong) MBEMesh *cube;
@property (nonatomic, assign) float angleX, angleY;
@end

@implementation MBERenderer

- (instancetype)initWithLayer:(CAMetalLayer *)layer
{
    self = [super init];
    
    if (self)
    {
        _cameraDistance = 1;
        _mipmappingMode = MBEMipmappingModeVibrantLinear;
        
        [self buildMetal];
        [self buildPipeline];
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

- (void)buildPipeline
{
    MTLVertexDescriptor *vertexDescriptor = [MTLVertexDescriptor new];
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat4;
    
    vertexDescriptor.attributes[1].offset = sizeof(vector_float4);
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    vertexDescriptor.layouts[0].stepRate = 1;
    vertexDescriptor.layouts[0].stride = sizeof(MBEVertex);
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = [_library newFunctionWithName:@"vertex_project"];
    pipelineDescriptor.fragmentFunction = [_library newFunctionWithName:@"fragment_texture"];
    pipelineDescriptor.vertexDescriptor = vertexDescriptor;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    
    NSError *error = nil;
    _pipeline = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (!_pipeline)
    {
        NSLog(@"Error occurred while creating render pipeline: %@", error);
    }
    
    MTLDepthStencilDescriptor *depthDescriptor = [MTLDepthStencilDescriptor new];
    depthDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    depthDescriptor.depthWriteEnabled = YES;
    _depthState = [self.device newDepthStencilStateWithDescriptor:depthDescriptor];
    
    MTLSamplerDescriptor *samplerDescriptor = [MTLSamplerDescriptor new];
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeClampToEdge;
    
    samplerDescriptor.mipFilter = MTLSamplerMipFilterNotMipmapped;
    _notMipSamplerState = [self.device newSamplerStateWithDescriptor:samplerDescriptor];
    
    samplerDescriptor.mipFilter = MTLSamplerMipFilterNearest;
    _nearestMipSamplerState = [self.device newSamplerStateWithDescriptor:samplerDescriptor];
    
    samplerDescriptor.mipFilter = MTLSamplerMipFilterLinear;
    _linearMipSamplerState = [self.device newSamplerStateWithDescriptor:samplerDescriptor];
}

- (void)buildResources
{
    _cube = [[MBECubeMesh alloc] initWithDevice:_device];
    
    const CGSize textureSize = CGSizeMake(512, 512);
    const size_t tileCount = 8;
    
    [MBETextureGenerator checkerboardTextureWithSize:textureSize
                                           tileCount:tileCount
                                     colorfulMipmaps:NO
                                              device:_device
                                          completion:^(id<MTLTexture> texture)
     {
         _checkerTexture = texture;
     }];
    
    [MBETextureGenerator checkerboardTextureWithSize:textureSize
                                           tileCount:tileCount
                                     colorfulMipmaps:YES
                                              device:_device
                                          completion:^(id<MTLTexture> texture)
     {
         _vibrantCheckerTexture = texture;
     }];
    
    
    _uniformBuffer = [self.device newBufferWithLength:sizeof(MBEUniforms)
                                              options:MTLResourceOptionCPUCacheModeDefault];
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

- (void)drawSceneWithCommandEncoder:(id<MTLRenderCommandEncoder>)commandEncoder
{
    id<MTLTexture> texture;
    id<MTLSamplerState> sampler;
    
    switch (self.mipmappingMode)
    {
        case MBEMipmappingModeNone:
            texture = self.checkerTexture;
            sampler = self.notMipSamplerState;
            break;
        case MBEMipmappingModeBlitGeneratedLinear:
            texture = self.checkerTexture;
            sampler = self.linearMipSamplerState;
            break;
        case MBEMipmappingModeVibrantNearest:
            texture = self.vibrantCheckerTexture;
            sampler = self.nearestMipSamplerState;
            break;
        case MBEMipmappingModeVibrantLinear:
        default:
            texture = self.vibrantCheckerTexture;
            sampler = self.linearMipSamplerState;
            break;
    }
    
    [commandEncoder setRenderPipelineState:self.pipeline];
    [commandEncoder setDepthStencilState:self.depthState];
    [commandEncoder setFragmentTexture:texture atIndex:0];
    [commandEncoder setFragmentSamplerState:sampler atIndex:0];
    
    [commandEncoder setVertexBuffer:self.cube.vertexBuffer offset:0 atIndex:0];
    [commandEncoder setVertexBuffer:self.uniformBuffer offset:0 atIndex:1];
    [commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                               indexCount:[self.cube.indexBuffer length] / sizeof(MBEIndex)
                                indexType:MTLIndexTypeUInt16
                              indexBuffer:self.cube.indexBuffer
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
    const CGSize size = self.layer.bounds.size;
    const float aspectRatio = size.width / size.height;
    const float verticalFOV = (aspectRatio > 1) ? (M_PI / 3) : (M_PI / 2);
    static const float near = 0.1;
    static const float far = 100;
    matrix_float4x4 projectionMatrix = matrix_perspective_projection(aspectRatio, verticalFOV, near, far);
    
    const vector_float3 cameraPosition = { 0, 0, self.cameraDistance };
    matrix_float4x4 viewMatrix = matrix_translation(-cameraPosition);
    
    MBEUniforms uniforms;
    
    vector_float3 cubePosition = { 0, 0, 0 };
    matrix_float4x4 cubeModelMatrix = matrix_multiply(matrix_translation(cubePosition),
                                                      matrix_multiply(matrix_rotation(X, self.angleX),
                                                                      matrix_rotation(Y, self.angleY)));
    uniforms.modelMatrix = cubeModelMatrix;
    uniforms.normalMatrix = matrix_transpose(matrix_invert(matrix_upper_left3x3(cubeModelMatrix)));
    uniforms.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, matrix_multiply(viewMatrix, cubeModelMatrix));
    
    memcpy(self.uniformBuffer.contents, &uniforms, sizeof(MBEUniforms));
    
    self.angleY += 0.01;
    self.angleX += 0.015;
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
        
        [self drawSceneWithCommandEncoder:commandEncoder];
        
        [commandEncoder endEncoding];
        
        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
    }
}

@end
