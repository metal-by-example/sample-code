@import UIKit;
@import QuartzCore.CAMetalLayer;

@interface MBEMetalView : UIView

@property (nonatomic, readonly) CAMetalLayer *metalLayer;
@property (nonatomic, readonly) UITouch *currentTouch;

@end
