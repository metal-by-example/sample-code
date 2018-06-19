#import "MBEMetalViewIOS.h"

@implementation MBEMetalViewIOS

+ (Class)layerClass
{
    return [CAMetalLayer class];
}

- (CAMetalLayer *)metalLayer
{
    return (CAMetalLayer *)self.layer;
}

- (CGSize)drawableSize {
    
    // During the first layout pass, we will not be in a view hierarchy, so we guess our scale
    // If we've moved to a window by the time our frame is being set, we can take its scale as our own
    CGFloat scale = self.window ? self.window.screen.scale : [UIScreen mainScreen].scale;
    CGSize drawableSize = self.bounds.size;
    
    // Since drawable size is in pixels, we need to multiply by the scale to move from points to pixels
    drawableSize.width *= scale;
    drawableSize.height *= scale;
    
    return drawableSize;
}

@end
