//
//  MBEMetalViewMac.m
//  DrawingIn3D-Mac
//
//  Created by Brent Gulanowski on 2018-06-18.
//  Copyright © 2018 Metal by Example. All rights reserved.
//

#import "MBEMetalViewMac.h"

@import Metal;
@import QuartzCore;

@interface MBEMetalViewMac()
@property (nonatomic, strong) CAMetalLayer *metalLayer;
@end


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

@end
