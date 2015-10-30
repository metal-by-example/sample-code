@import simd;
#import "MBERenderer.h"
#import "MBETypes.h"
#import "MBEMathUtilities.h"
#import "MBETextureDataSource.h"

static const size_t MBEUniformBufferLength = 128;
static const size_t MBEMaxInflightBufferCount = 3;

@interface MBERenderer ()
@property (nonatomic, strong) CAMetalLayer *metalLayer;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> renderPipeline;
@property (nonatomic, strong) id<MTLSamplerState> samplerState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> uniformBuffer;
@property (nonatomic, strong) dispatch_semaphore_t inflightBufferSemaphore;
@property (nonatomic, assign) size_t inflightBufferIndex;
@end

@implementation MBERenderer

- (instancetype)initWithLayer:(CAMetalLayer *)layer
{
    if ((self = [super init]))
    {
        _metalLayer = layer;
        _device = MTLCreateSystemDefaultDevice();

        [self buildPipeline];
        [self buildTextureArray];
        [self buildResources];
    }

    return self;
}

- (void)buildPipeline
{
    _commandQueue = [_device newCommandQueue];

    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragment_main"];

    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    [pipelineDescriptor reset];
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.vertexDescriptor = [self newVertexDescriptor];

    NSError *error = nil;
    _renderPipeline = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (nil == _renderPipeline)
    {
        NSLog(@"Failure when compiling render pipeline: %@", error.localizedDescription);
    }
}

- (void)buildTextureArray
{
    NSError *error = nil;
    NSURL *metadataURL = [[NSBundle mainBundle] URLForResource:@"textures" withExtension:@"json"];
    NSData *metadata = [NSData dataWithContentsOfURL:metadataURL];
    NSArray *textureInfo = [NSJSONSerialization JSONObjectWithData:metadata options:0 error:&error];
    NSMutableArray *textures = [NSMutableArray arrayWithCapacity:[textureInfo count]];

    for (NSDictionary *info in textureInfo)
    {
        NSString *filename = info[@"filename"];
        NSURL *fileURL = [[NSBundle mainBundle] URLForResource:filename withExtension:@""];
        NSString *label = info[@"label"];

        if (fileURL)
        {
            NSLog(@"%@", filename);
            MBETextureDataSource *textureSource = [MBETextureDataSource textureDataSourceWithContentsOfURL:fileURL];
            id<MTLTexture> texture = [textureSource newTextureWithCommandQueue:self.commandQueue generateMipmaps:YES];

            if (texture)
            {
                [texture setLabel:label];
                [textures addObject:texture];
            }
            else
            {
                NSLog(@"Failed when creating texture named %@ (%@)", label, filename);
            }
        }
        else
        {
            NSLog(@"Texture named %@ (%@) was not found in the main bundle", label, filename);
        }
    }

    _textures = [textures copy];
}

- (void)buildResources
{
    MTLSamplerDescriptor *samplerDescriptor = [MTLSamplerDescriptor new];
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterNearest;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.mipFilter = MTLSamplerMipFilterLinear;
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeRepeat;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeRepeat;
    _samplerState = [_device newSamplerStateWithDescriptor:samplerDescriptor];

    _uniformBuffer = [_device newBufferWithLength:MBEMaxInflightBufferCount * MBEUniformBufferLength
                                          options:MTLResourceOptionCPUCacheModeDefault];
    [_uniformBuffer setLabel:@"Uniforms"];

    _inflightBufferSemaphore = dispatch_semaphore_create(MBEMaxInflightBufferCount);

    MBEVertex vertices[] = {
        { { -1,  1, 0, 1 }, { 0, 0 } },
        { { -1, -1, 0, 1 }, { 0, 1 } },
        { {  1, -1, 0, 1 }, { 1, 1 } },
        { {  1, -1, 0, 1 }, { 1, 1 } },
        { {  1,  1, 0, 1 }, { 1, 0 } },
        { { -1,  1, 0, 1 }, { 0, 0 } },
    };
    _vertexBuffer = [_device newBufferWithBytes:&vertices[0]
                                         length:sizeof(vertices)
                                        options:MTLResourceOptionCPUCacheModeDefault];
    [_vertexBuffer setLabel:@"Vertices"];
}

- (MTLVertexDescriptor *)newVertexDescriptor
{
    MTLVertexDescriptor *descriptor = [MTLVertexDescriptor vertexDescriptor];
    descriptor.attributes[0].format = MTLVertexFormatFloat4;
    descriptor.attributes[0].offset = 0;
    descriptor.attributes[0].bufferIndex = 0;

    descriptor.attributes[1].format = MTLVertexFormatFloat2;
    descriptor.attributes[1].offset = offsetof(MBEVertex, texCoords);
    descriptor.attributes[1].bufferIndex = 0;

    descriptor.layouts[0].stride = sizeof(MBEVertex);

    return descriptor;
}

- (void)updateUniforms
{
    NSUInteger offset = self.inflightBufferIndex * MBEUniformBufferLength;

    // Build model-view-projection matrix
    CGSize drawableSize = [self.metalLayer drawableSize];
    double aspect = drawableSize.width / drawableSize.height;
    double fieldOfView = (aspect < 1) ? (M_PI / 2) : (M_PI / 3);
    matrix_float4x4 projectionMatrix = matrix_perspective_projection(aspect, fieldOfView, 0.1, 100);
    const vector_float3 cameraPosition = { 0, 0, 2 };
    matrix_float4x4 viewMatrix = matrix_translation(-cameraPosition);
    const vector_float3 xAxis = { 1, 0, 0 };
    const vector_float3 yAxis = { 0, 1, 0 };
    matrix_float4x4 modelMatrix = matrix_multiply(matrix_rotation(xAxis, self.rotationAngles.dx),
                                                  matrix_rotation(yAxis, self.rotationAngles.dy));

    // Update uniform buffer at current offset
    MBEUniforms uniforms;
    uniforms.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, matrix_multiply(viewMatrix, modelMatrix));
    memcpy([self.uniformBuffer contents] + offset, &uniforms, sizeof(MBEUniforms));
}

- (void)draw
{
    dispatch_semaphore_wait(_inflightBufferSemaphore, DISPATCH_TIME_FOREVER);

    id <CAMetalDrawable> drawable = [self.metalLayer nextDrawable];
    if (drawable)
    {
        [self updateUniforms];

        id<MTLTexture> renderbuffer = [drawable texture];
        [renderbuffer setLabel:@"Renderbuffer"];

        MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor renderPassDescriptor];
        renderPass.colorAttachments[0].texture = renderbuffer;
        renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
        renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.65, 0.8, 1);

        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
        id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPass];

        NSUInteger uniformOffset = self.inflightBufferIndex * MBEUniformBufferLength;
        [commandEncoder setCullMode:MTLCullModeNone];
        [commandEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
        [commandEncoder setRenderPipelineState:self.renderPipeline];
        [commandEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
        [commandEncoder setVertexBuffer:self.uniformBuffer offset:uniformOffset atIndex:1];
        [commandEncoder setFragmentTexture:self.textures[self.currentTextureIndex] atIndex:0];
        [commandEncoder setFragmentSamplerState:self.samplerState atIndex:0];

        [commandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];

        [commandEncoder endEncoding];

        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> completedBuffer) {
            dispatch_semaphore_signal(_inflightBufferSemaphore);
        }];

        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];

        self.inflightBufferIndex = (self.inflightBufferIndex + 1) % MBEMaxInflightBufferCount;
    }
    else
    {
        dispatch_semaphore_signal(_inflightBufferSemaphore);
    }
}

@end
