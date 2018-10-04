//
//  MBEMetalView.h
//  Mipmapping
//
//  Created by Brent Gulanowski on 2018-06-19.
//  Copyright © 2018 Metal By Example. All rights reserved.
//

#import <TargetConditionals.h>

#if TARGET_OS_IPHONE
@import UIKit;
#define NSUIView UIView;
#else
@import AppKit;
#define NSUIView NSView;
#endif

@import QuartzCore.CAMetalLayer;

@interface MBEMetalView : NSUIView

@property (nonatomic, readonly) CAMetalLayer *metalLayer;
@property (nonatomic, readonly) CGSize drawableSize;

@end
