#import <TargetConditionals.h>

#if TARGET_OS_IPHONE
@import UIKit;
#define NSUIViewController UIViewController
#else
@import AppKit;
#define NSUIViewController NSViewController
#endif

@interface ViewController : NSUIViewController

@end

