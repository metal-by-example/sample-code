#import "MBEMetalView.h"
@import Metal;

@interface MBEMetalView ()
@property (readonly) id<MTLDevice> device;
@end

@implementation MBEMetalView

- (CAMetalLayer *)metalLayer {
    return (CAMetalLayer *)self.layer;
}

#if TARGET_OS_IPHONE
+ (id)layerClass
{
    return [CAMetalLayer class];
}

#else
- (CALayer *)makeBackingLayer {
    return [[CAMetalLayer alloc] init];
}

- (BOOL)wantsUpdateLayer {
    return YES;
}

- (void)viewDidMoveToSuperview {
    [self configureMetal];
    [self.layer setNeedsDisplay];
}

- (void)displayLayer:(CALayer *)layer {
    [self redraw];
}
#endif

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        _device = MTLCreateSystemDefaultDevice();
        [self configureMetal];
    }

    return self;
}

- (void)didMoveToWindow
{
    [self redraw];
}

- (void)configureMetal {
    self.metalLayer.device = _device;
    self.metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
}

- (void)redraw
{
    id<CAMetalDrawable> drawable = [self.metalLayer nextDrawable];
    id<MTLTexture> texture = drawable.texture;

    MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    passDescriptor.colorAttachments[0].texture = texture;
    passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 0, 0, 1);

    id<MTLCommandQueue> commandQueue = [self.device newCommandQueue];

    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

    id <MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    [commandEncoder endEncoding];

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];

}

@end
