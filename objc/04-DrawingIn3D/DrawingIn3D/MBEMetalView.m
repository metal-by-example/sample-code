#import "MBEMetalView.h"

@interface MBEMetalView ()
@property (strong) id<CAMetalDrawable> currentDrawable;
@property (assign) NSTimeInterval frameDuration;
@property (strong) id<MTLTexture> depthTexture;
@property (strong) CADisplayLink *displayLink;
@end

@implementation MBEMetalView

+ (Class)layerClass
{
    return [CAMetalLayer class];
}

- (CAMetalLayer *)metalLayer
{
    return (CAMetalLayer *)self.layer;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self commonInit];
        self.metalLayer.device = MTLCreateSystemDefaultDevice();
    }

    return self;
}

- (instancetype)initWithFrame:(CGRect)frame device:(id<MTLDevice>)device
{
    if ((self = [super initWithFrame:frame]))
    {
        [self commonInit];
        self.metalLayer.device = device;
    }

    return self;
}

- (void)commonInit
{
    _preferredFramesPerSecond = 60;
    _clearColor = MTLClearColorMake(1, 1, 1, 1);

    self.metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    // During the first layout pass, we will not be in a view hierarchy, so we guess our scale
    CGFloat scale = [UIScreen mainScreen].scale;
    
    // If we've moved to a window by the time our frame is being set, we can take its scale as our own
    if (self.window)
    {
        scale = self.window.screen.scale;
    }
    
    CGSize drawableSize = self.bounds.size;
    
    // Since drawable size is in pixels, we need to multiply by the scale to move from points to pixels
    drawableSize.width *= scale;
    drawableSize.height *= scale;

    self.metalLayer.drawableSize = drawableSize;

    [self makeDepthTexture];
}

- (void)setColorPixelFormat:(MTLPixelFormat)colorPixelFormat
{
    self.metalLayer.pixelFormat = colorPixelFormat;
}

- (MTLPixelFormat)colorPixelFormat
{
    return self.metalLayer.pixelFormat;
}

- (void)didMoveToWindow
{
    const NSTimeInterval idealFrameDuration = (1.0 / 60);
    const NSTimeInterval targetFrameDuration = (1.0 / self.preferredFramesPerSecond);
    const NSInteger frameInterval = round(targetFrameDuration / idealFrameDuration);

    if (self.window)
    {
        [self.displayLink invalidate];
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkDidFire:)];
        self.displayLink.frameInterval = frameInterval;
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    else
    {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

- (void)displayLinkDidFire:(CADisplayLink *)displayLink
{
    self.currentDrawable = [self.metalLayer nextDrawable];
    self.frameDuration = displayLink.duration;

    if ([self.delegate respondsToSelector:@selector(drawInView:)])
    {
        [self.delegate drawInView:self];
    }
}

- (void)makeDepthTexture
{
    CGSize drawableSize = self.metalLayer.drawableSize;

    if ([self.depthTexture width] != drawableSize.width ||
        [self.depthTexture height] != drawableSize.height)
    {
        MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                                                                        width:drawableSize.width
                                                                                       height:drawableSize.height
                                                                                    mipmapped:NO];

        self.depthTexture = [self.metalLayer.device newTextureWithDescriptor:desc];
    }
}

- (MTLRenderPassDescriptor *)currentRenderPassDescriptor
{
    MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];

    passDescriptor.colorAttachments[0].texture = [self.currentDrawable texture];
    passDescriptor.colorAttachments[0].clearColor = self.clearColor;
    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;

    passDescriptor.depthAttachment.texture = self.depthTexture;
    passDescriptor.depthAttachment.clearDepth = 1.0;
    passDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
    passDescriptor.depthAttachment.storeAction = MTLStoreActionDontCare;

    return passDescriptor;
}

@end
