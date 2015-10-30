#import "MBERenderer.h"
#import "MBEMathUtilities.h"
#import "MBEOBJModel.h"
#import "MBEOBJMesh.h"
#import "MBETypes.h"
#import "MBETextureLoader.h"

@import Metal;
@import QuartzCore.CAMetalLayer;
@import simd;

static const NSInteger MBEInFlightBufferCount = 3;

@interface MBERenderer ()
@property (strong) id<MTLDevice> device;
@property (strong) id<MTLTexture> diffuseTexture;
@property (strong) MBEMesh *mesh;
@property (strong) id<MTLBuffer> uniformBuffer;
@property (strong) id<MTLCommandQueue> commandQueue;
@property (strong) id<MTLRenderPipelineState> renderPipelineState;
@property (strong) id<MTLDepthStencilState> depthStencilState;
@property (strong) id<MTLSamplerState> samplerState;
@property (strong) dispatch_semaphore_t displaySemaphore;
@property (assign) NSInteger bufferIndex;
@end

@implementation MBERenderer

- (instancetype)init
{
    if ((self = [super init]))
    {
        _device = MTLCreateSystemDefaultDevice();
        _displaySemaphore = dispatch_semaphore_create(MBEInFlightBufferCount);
        [self makePipeline];
        [self makeResources];
    }

    return self;
}

- (void)makePipeline
{
    self.commandQueue = [self.device newCommandQueue];

    id<MTLLibrary> library = [self.device newDefaultLibrary];

    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"vertex_project"];
    pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"fragment_texture"];
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

    MTLDepthStencilDescriptor *depthStencilDescriptor = [MTLDepthStencilDescriptor new];
    depthStencilDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    depthStencilDescriptor.depthWriteEnabled = YES;
    self.depthStencilState = [self.device newDepthStencilStateWithDescriptor:depthStencilDescriptor];

    NSError *error = nil;
    self.renderPipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor
                                                                           error:&error];

    if (!self.renderPipelineState)
    {
        NSLog(@"Error occurred when creating render pipeline state: %@", error);
    }

    self.commandQueue = [self.device newCommandQueue];
}

- (void)makeResources
{
    // load texture
    MBETextureLoader *textureLoader = [MBETextureLoader new];
    _diffuseTexture = [textureLoader texture2DWithImageNamed:@"spot_texture" mipmapped:YES commandQueue:_commandQueue];

    // load model
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"spot" withExtension:@"obj"];
    MBEOBJModel *model = [[MBEOBJModel alloc] initWithContentsOfURL:modelURL generateNormals:YES];
    MBEOBJGroup *group = [model groupForName:@"spot"];
    _mesh = [[MBEOBJMesh alloc] initWithGroup:group device:_device];

    // create uniform storage
    _uniformBuffer = [self.device newBufferWithLength:sizeof(MBEUniforms) * MBEInFlightBufferCount
                                              options:MTLResourceOptionCPUCacheModeDefault];
    [_uniformBuffer setLabel:@"Uniforms"];

    // create sampler state
    MTLSamplerDescriptor *samplerDesc = [MTLSamplerDescriptor new];
    samplerDesc.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDesc.tAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
    samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDesc.mipFilter = MTLSamplerMipFilterLinear;
    _samplerState = [_device newSamplerStateWithDescriptor:samplerDesc];
}

- (void)updateUniformsForView:(MBEMetalView *)view duration:(NSTimeInterval)duration
{
    float scaleFactor = 1;
    const vector_float3 xAxis = { 1, 0, 0 };
    const vector_float3 yAxis = { 0, 1, 0 };
    const matrix_float4x4 xRot = matrix_float4x4_rotation(xAxis, self.rotationX);
    const matrix_float4x4 yRot = matrix_float4x4_rotation(yAxis, self.rotationY);
    const matrix_float4x4 scale = matrix_float4x4_uniform_scale(scaleFactor);
    const matrix_float4x4 modelMatrix = matrix_multiply(matrix_multiply(xRot, yRot), scale);

    const vector_float3 cameraTranslation = { 0, 0, -1.5 };
    const matrix_float4x4 viewMatrix = matrix_float4x4_translation(cameraTranslation);

    const CGSize drawableSize = view.metalLayer.drawableSize;
    const float aspect = drawableSize.width / drawableSize.height;
    const float fov = (2 * M_PI) / 5;
    const float near = 0.1;
    const float far = 100;
    const matrix_float4x4 projectionMatrix = matrix_float4x4_perspective(aspect, fov, near, far);

    MBEUniforms uniforms;
    uniforms.modelViewMatrix = matrix_multiply(viewMatrix, modelMatrix);
    uniforms.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, uniforms.modelViewMatrix);
    uniforms.normalMatrix = matrix_float4x4_extract_linear(uniforms.modelViewMatrix);

    const NSUInteger uniformBufferOffset = sizeof(MBEUniforms) * self.bufferIndex;
    memcpy([self.uniformBuffer contents] + uniformBufferOffset, &uniforms, sizeof(uniforms));
}

- (void)drawInView:(MBEMetalView *)view
{
    if (view.currentDrawable)
    {
        dispatch_semaphore_wait(self.displaySemaphore, DISPATCH_TIME_FOREVER);

        view.clearColor = MTLClearColorMake(0.95, 0.95, 0.95, 1);

        [self updateUniformsForView:view duration:view.frameDuration];

        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];

        MTLRenderPassDescriptor *passDescriptor = [view currentRenderPassDescriptor];

        id<MTLRenderCommandEncoder> renderPass = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
        [renderPass setRenderPipelineState:self.renderPipelineState];
        [renderPass setDepthStencilState:self.depthStencilState];
        [renderPass setFrontFacingWinding:MTLWindingCounterClockwise];
        [renderPass setCullMode:MTLCullModeBack];

        const NSUInteger uniformBufferOffset = sizeof(MBEUniforms) * self.bufferIndex;

        [renderPass setVertexBuffer:self.mesh.vertexBuffer offset:0 atIndex:0];
        [renderPass setVertexBuffer:self.uniformBuffer offset:uniformBufferOffset atIndex:1];

        [renderPass setFragmentTexture:self.diffuseTexture atIndex:0];
        [renderPass setFragmentSamplerState:self.samplerState atIndex:0];

        [renderPass drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                               indexCount:[self.mesh.indexBuffer length] / sizeof(MBEIndex)
                                indexType:MBEIndexType
                              indexBuffer:self.mesh.indexBuffer
                        indexBufferOffset:0];

        [renderPass endEncoding];

        [commandBuffer presentDrawable:view.currentDrawable];

        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
            self.bufferIndex = (self.bufferIndex + 1) % MBEInFlightBufferCount;
            dispatch_semaphore_signal(self.displaySemaphore);
        }];
        
        [commandBuffer commit];
    }
}

@end
