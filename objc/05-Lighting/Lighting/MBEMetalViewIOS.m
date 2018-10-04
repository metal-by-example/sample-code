//
//  MBEMetalViewIOS.m
//  DrawingIn3D
//
//  Created by Brent Gulanowski on 2018-06-18.
//  Copyright © 2018 Metal by Example. All rights reserved.
//

#import "MBEMetalViewIOS.h"

@interface MBEMetalViewIOS()
@property (strong) CADisplayLink *displayLink;
@end

@implementation MBEMetalViewIOS

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
    [self renderWithDuration:displayLink.duration];
}

@end
