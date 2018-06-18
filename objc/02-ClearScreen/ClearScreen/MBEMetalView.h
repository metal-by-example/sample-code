#if TARGET_OS_IPHONE
@import UIKit;
#define NSUIView UIView
#else
@import AppKit;
@import QuartzCore;
#define NSUIView NSView
#endif

@interface MBEMetalView : NSUIView

@property (readonly) CAMetalLayer *metalLayer;

@end
