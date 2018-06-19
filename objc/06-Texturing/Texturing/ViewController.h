#import <TargetConditionals.h>

#if TARGET_OS_IPHONE
@import UIKit;
#define NSUIViewController UIViewController
#define NSUIPanGestureRecognizer UIPanGestureRecognizer
#else
@import AppKit;
#define NSUIViewController NSViewController
#define NSUIPanGestureRecognizer NSPanGestureRecognizer
#endif

@interface ViewController : NSUIViewController

@end

