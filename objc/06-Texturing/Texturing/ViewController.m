#import "ViewController.h"
#import "MBERenderer.h"
#import "MBEMetalView.h"
@import AudioToolbox;

static const CGFloat kVelocityScale = 0.01;
static const CGFloat kRotationDamping = 0.05;
static const CGFloat kMooSpinThreshold = 30;
static const CGFloat kMooDuration = 3;

@interface ViewController () <MBEMetalViewDelegate>
@property (nonatomic, strong) MBERenderer *renderer;
@property (nonatomic, assign) SystemSoundID mooSound;
@property (nonatomic, assign) NSTimeInterval lastMooTime;
@property (nonatomic, assign) CGPoint angularVelocity;
@property (nonatomic, assign) CGPoint angle;
@end

@implementation ViewController

- (void)dealloc
{
    AudioServicesDisposeSystemSoundID(_mooSound);
}

- (MBEMetalView *)metalView {
    return (MBEMetalView *)self.view;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.renderer = [MBERenderer new];
    self.metalView.delegate = self;

    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                 action:@selector(gestureDidRecognize:)];
    [self.view addGestureRecognizer:panGesture];

    [self loadResources];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}


- (void)gestureDidRecognize:(UIGestureRecognizer *)gestureRecognizer
{
    UIPanGestureRecognizer *panGestureRecognizer = (UIPanGestureRecognizer *)gestureRecognizer;
    CGPoint velocity = [panGestureRecognizer velocityInView:self.view];
    self.angularVelocity = CGPointMake(velocity.x * kVelocityScale, velocity.y * kVelocityScale);
}

- (void)loadResources
{
    NSURL *mooURL = [[NSBundle mainBundle] URLForResource:@"moo" withExtension:@"aiff"];
    if (!mooURL)
    {
        NSLog(@"Could not find sound effect file in main bundle");
    }

    OSStatus result = AudioServicesCreateSystemSoundID((__bridge CFURLRef)mooURL, &_mooSound);
    if (result != noErr)
    {
        NSLog(@"Error when loading sound effect. Error code %d", (int)result);
    }
}

- (void)updateMotionWithTimestep:(NSTimeInterval)duration
{
    if (duration > 0)
    {
        // Update the rotation angles according to the current velocity and time step
        self.angle = CGPointMake(self.angle.x + self.angularVelocity.x * duration,
                                 self.angle.y + self.angularVelocity.y * duration);

        // Apply damping by removing some proportion of the angular velocity each frame
        self.angularVelocity = CGPointMake(self.angularVelocity.x * (1 - kRotationDamping),
                                           self.angularVelocity.y * (1 - kRotationDamping));

        CGFloat spinSpeed = hypot(self.angularVelocity.x, self.angularVelocity.y);

        // If we're spinning fast and haven't mooed in a while, trigger the moo sound effect
        CFAbsoluteTime frameTime = CFAbsoluteTimeGetCurrent();
        if (spinSpeed > kMooSpinThreshold && frameTime > (self.lastMooTime + kMooDuration))
        {
            AudioServicesPlaySystemSound(self.mooSound);
            self.lastMooTime = frameTime;
        }
    }
}

- (void)drawInView:(MBEMetalView *)view
{
    [self updateMotionWithTimestep:view.frameDuration];

    self.renderer.rotationX = -self.angle.y;
    self.renderer.rotationY = -self.angle.x;

    [self.renderer drawInView:view];
}


@end
