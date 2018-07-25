#import "MBEMetalView.h"

@implementation MBEMetalView

@dynamic metalLayer;
@dynamic drawableSize;

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
    self.metalLayer.drawableSize = self.drawableSize;
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
        desc.usage = MTLTextureUsageRenderTarget;
        desc.storageMode = MTLStorageModePrivate;
        
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

- (void)renderWithDuration:(NSTimeInterval)duration {
    self.currentDrawable = [self.metalLayer nextDrawable];
    self.frameDuration = duration;
    
    if ([self.delegate respondsToSelector:@selector(drawInView:)])
    {
        [self.delegate drawInView:self];
    }
}

@end
