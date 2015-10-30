#import "MBEViewController.h"
#import "MBETextureLoader.h"
#import "MBERenderer.h"
#import "MBEMetalView.h"
#import "MBEMatrixUtilities.h"
@import Metal;
@import CoreMotion;
@import simd;

@interface MBEViewController ()
@property (nonatomic, strong) MBERenderer *renderer;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) CMMotionManager *motionManager;
@end

@implementation MBEViewController

- (void)dealloc
{
    [_displayLink invalidate];
}

- (MBEMetalView *)metalView
{
    return (MBEMetalView *)self.view;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    CAMetalLayer *metalLayer = [self.metalView metalLayer];
    self.renderer = [[MBERenderer alloc] initWithLayer:metalLayer];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkDidFire:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    self.motionManager = [[CMMotionManager alloc] init];
    if (self.motionManager.deviceMotionAvailable)
    {
        self.motionManager.deviceMotionUpdateInterval = 1 / 60.0;
        CMAttitudeReferenceFrame frame = CMAttitudeReferenceFrameXTrueNorthZVertical;
        [self.motionManager startDeviceMotionUpdatesUsingReferenceFrame:frame];
    }
    
    UIGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    [self.view addGestureRecognizer:tapRecognizer];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (void)tap:(id)sender
{
    self.renderer.useRefractionMaterial = !self.renderer.useRefractionMaterial;
}

- (void)updateDeviceOrientation
{
    if (self.motionManager.deviceMotionAvailable)
    {
        CMDeviceMotion *motion = self.motionManager.deviceMotion;        
        CMRotationMatrix m = motion.attitude.rotationMatrix;
        
        // permute rotation matrix from Core Motion to get scene orientation
        vector_float4 X = { m.m12, m.m22, m.m32, 0 };
        vector_float4 Y = { m.m13, m.m23, m.m33, 0 };
        vector_float4 Z = { m.m11, m.m21, m.m31, 0 };
        vector_float4 W = {     0,     0,     0, 1 };
        
        matrix_float4x4 orientation = { X, Y, Z, W };
        self.renderer.sceneOrientation = orientation;
    }
}

- (void)displayLinkDidFire:(id)sender
{
    [self updateDeviceOrientation];
    [self redraw];
}

- (void)redraw
{
    [self.renderer draw];
}

@end
