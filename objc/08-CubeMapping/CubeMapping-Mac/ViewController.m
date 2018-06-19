//
//  ViewController.m
//  Mipmapping-Mac
//
//  Created by Brent Gulanowski on 2018-06-19.
//  Copyright © 2018 Metal By Example. All rights reserved.
//

#import "ViewController.h"
#import "MBERenderer.h"

@interface ViewController ()

@property (nonatomic) CVDisplayLinkRef displayLink;
@property (nonatomic, strong) MBERenderer *renderer;

- (void)draw;

@end

static CVReturn C3DViewDisplayLink(CVDisplayLinkRef displayLink,
                                   const CVTimeStamp *inNow,
                                   const CVTimeStamp *inOutputTime,
                                   CVOptionFlags flagsIn,
                                   CVOptionFlags *flagsOut,
                                   void *viewController)
{
    @autoreleasepool {
        [(__bridge ViewController *)viewController draw];
    }
    
    return kCVReturnSuccess;
}

@implementation ViewController

- (void)dealloc
{
    CVDisplayLinkRelease(_displayLink);
    _displayLink = NULL;
}

- (MBEMetalView *)metalView
{
    return (MBEMetalView *)self.view;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.renderer = [[MBERenderer alloc] initWithLayer:self.metalView.metalLayer];

    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
    CVDisplayLinkSetOutputCallback(_displayLink, C3DViewDisplayLink, (__bridge void *)(self));
}

- (void)viewWillAppear
{
    CVDisplayLinkStart(_displayLink);
}

- (void)viewWillDisappear
{
    CVDisplayLinkStop(_displayLink);
}

- (void)draw
{
    // TODO: implement UI controls
    [self.renderer draw];
}

@end
