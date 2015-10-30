#import "MBEMetalView.h"
@import Metal;
@import simd;

typedef struct
{
    vector_float4 position;
    vector_float4 color;
} MBEVertex;

@interface MBEMetalView ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipeline;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@end

@implementation MBEMetalView

@synthesize device=device;

+ (Class)layerClass
{
    return [CAMetalLayer class];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self makeDevice];
        [self makeBuffers];
        [self makePipeline];
    }
    
    return self;
}

- (void)dealloc
{
    [_displayLink invalidate];
}

- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    if (self.superview)
    {
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkDidFire:)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    else
    {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

- (CAMetalLayer *)metalLayer {
    return (CAMetalLayer *)self.layer;
}

- (void)makeDevice
{
    device = MTLCreateSystemDefaultDevice();
    self.metalLayer.device = device;
    self.metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
}

- (void)makePipeline
{
    id<MTLLibrary> library = [device newDefaultLibrary];
    
    id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"fragment_main"];

    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.vertexFunction = vertexFunc;
    pipelineDescriptor.fragmentFunction = fragmentFunc;
    
    NSError *error = nil;
    _pipeline = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor
                                                       error:&error];

    if (!_pipeline)
    {
        NSLog(@"Error occurred when creating render pipeline state: %@", error);
    }
    
    _commandQueue = [device newCommandQueue];
}

- (void)makeBuffers
{
    static const MBEVertex vertices[] =
    {
        { .position = {  0.0,  0.5, 0, 1 }, .color = { 1, 0, 0, 1 } },
        { .position = { -0.5, -0.5, 0, 1 }, .color = { 0, 1, 0, 1 } },
        { .position = {  0.5, -0.5, 0, 1 }, .color = { 0, 0, 1, 1 } }
    };

    _vertexBuffer = [device newBufferWithBytes:vertices
                                        length:sizeof(vertices)
                                       options:MTLResourceOptionCPUCacheModeDefault];
}

- (void)redraw
{
    id<CAMetalDrawable> drawable = [self.metalLayer nextDrawable];
    id<MTLTexture> framebufferTexture = drawable.texture;

    if (drawable)
    {
        MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
        passDescriptor.colorAttachments[0].texture = framebufferTexture;
        passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.85, 0.85, 0.85, 1);
        passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;

        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];

        id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
        [commandEncoder setRenderPipelineState:self.pipeline];
        [commandEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
        [commandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [commandEncoder endEncoding];
        
        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
    }
}

- (void)displayLinkDidFire:(CADisplayLink *)displayLink
{
    [self redraw];
}

@end
