#import "MBEViewController.h"
#import "MBERenderer.h"

@interface MBEViewController ()
@property (nonatomic, strong) MBERenderer *renderer;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) float baseZoomFactor, pinchZoomFactor;
@end

@implementation MBEViewController

- (MBEMetalView *)metalView
{
    return (MBEMetalView *)self.view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.baseZoomFactor = 2;
    self.pinchZoomFactor = 1;
    
    self.renderer = [[MBERenderer alloc] initWithLayer:self.metalView.metalLayer];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkDidFire:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    UIGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self
                                                                                  action:@selector(pinchGestureDidRecognize:)];
    [self.view addGestureRecognizer:pinchGesture];
    
    UIGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                              action:@selector(tapGestureDidRecognize:)];
    [self.view addGestureRecognizer:tapGesture];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)displayLinkDidFire:(id)sender
{
    self.renderer.cameraDistance = self.baseZoomFactor * self.pinchZoomFactor;
    
    [self.renderer draw];
}

- (void)pinchGestureDidRecognize:(UIPinchGestureRecognizer *)gesture
{
    switch (gesture.state)
    {
        case UIGestureRecognizerStateChanged:
            self.pinchZoomFactor = 1 / gesture.scale;
            break;
        case UIGestureRecognizerStateEnded:
            self.baseZoomFactor = self.baseZoomFactor * self.pinchZoomFactor;
            self.pinchZoomFactor = 1.0;
        default:
            break;
    }
    
    float constrainedZoom = fmax(1.0, fmin(100.0, self.baseZoomFactor * self.pinchZoomFactor));
    self.pinchZoomFactor = constrainedZoom / self.baseZoomFactor;
}

- (void)tapGestureDidRecognize:(UITapGestureRecognizer *)gesture
{
    self.renderer.mipmappingMode = ((self.renderer.mipmappingMode + 1) % 4);
}

@end
