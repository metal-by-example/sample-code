#import "MBEViewController.h"
#import "MBEMetalView.h"
#import "MBERenderer.h"
@import QuartzCore.CAMetalLayer;

static const float MBERotationSpeed = 3; // radians per second

@interface MBEViewController ()
@property (nonatomic, readonly) MBEMetalView *metalView;
@property (nonatomic, strong) MBERenderer *renderer;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) float angularVelocity;
@end

@implementation MBEViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.renderer = [[MBERenderer alloc] initWithLayer:self.metalView.metalLayer];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self
                                                   selector:@selector(displayLinkDidFire:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (MBEMetalView *)metalView
{
    return (MBEMetalView *)self.view;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)updateMotion
{
    self.renderer.frameDuration = self.displayLink.duration;
    
    UITouch *touch = self.metalView.currentTouch;
    
    if (touch)
    {
        CGRect bounds = self.view.bounds;
        float rotationScale = (CGRectGetMidX(bounds) - [touch locationInView:self.view].x) / bounds.size.width;
        
        self.renderer.velocity = 2;
        self.renderer.angularVelocity = rotationScale * MBERotationSpeed;
    }
    else
    {
        self.renderer.velocity = 0;
        self.renderer.angularVelocity = 0;
    }
}

- (void)displayLinkDidFire:(id)sender
{
    [self updateMotion];

    [self.renderer draw];
}

@end
