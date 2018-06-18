//
//  MBEMetalViewMac.m
//  DrawingIn3D-Mac
//
//  Created by Brent Gulanowski on 2018-06-18.
//  Copyright © 2018 Metal by Example. All rights reserved.
//

#import "MBEMetalViewMac.h"

@interface MBEMetalViewMac()
@property (nonatomic) CVDisplayLinkRef displayLink;
@property (nonatomic, strong) CAMetalLayer *metalLayer;
@end

static NSTimeInterval C3DTimeIntervalFromTimeStamp(const CVTimeStamp *timeStamp) {
    return 1.0 / (timeStamp->rateScalar * (double)timeStamp->videoTimeScale / (double)timeStamp->videoRefreshPeriod);
}

static CVReturn C3DViewDisplayLink(CVDisplayLinkRef displayLink,
                                   const CVTimeStamp *inNow,
                                   const CVTimeStamp *inOutputTime,
                                   CVOptionFlags flagsIn,
                                   CVOptionFlags *flagsOut,
                                   void *view) {
    @autoreleasepool {
        [(__bridge MBEMetalView *)view renderWithDuration:C3DTimeIntervalFromTimeStamp(inOutputTime)];
    }
    
    return kCVReturnSuccess;
}

@implementation MBEMetalViewMac

@synthesize metalLayer=_metalLayer;

- (CALayer *)makeBackingLayer
{
    CAMetalLayer *layer = [[CAMetalLayer alloc] init];
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalLayer = layer;
    return layer;
}

- (CGSize)drawableSize {
    return self.bounds.size;
}

- (void)viewDidMoveToSuperview
{
    [super viewDidMoveToSuperview];
    
    if (self.metalLayer.device == nil) {
        self.metalLayer.device = MTLCreateSystemDefaultDevice();
    }
    if (self.depthTexture == nil) {
        [self makeDepthTexture];
    }
    
    if (self.superview) {
        CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
        CVDisplayLinkSetOutputCallback(_displayLink, C3DViewDisplayLink, (__bridge void *)(self));
        CVDisplayLinkStart(_displayLink);
    }
    else {
        CVDisplayLinkStop(_displayLink);
        CVDisplayLinkRelease(_displayLink);
        _displayLink = NULL;
    }
}

@end
