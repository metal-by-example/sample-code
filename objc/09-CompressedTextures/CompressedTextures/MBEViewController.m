#import "MBEViewController.h"
#import "MBEMetalView.h"
#import "MBERenderer.h"

@interface MBEViewController () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) MBERenderer *renderer;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CGVector rotationAngles;
@end

@implementation MBEViewController

- (MBEMetalView *)metalView
{
    return (MBEMetalView *)self.view;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.renderer = [[MBERenderer alloc] initWithLayer:self.metalView.metalLayer];

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkDidFire:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                 action:@selector(panGestureDidRecognize:)];
    [self.view addGestureRecognizer:panGesture];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)displayLinkDidFire:(id)sender
{
    [self redraw];
}

- (void)panGestureDidRecognize:(UIPanGestureRecognizer *)panGesture
{
    CGPoint translation = [panGesture translationInView:self.view];
    [panGesture setTranslation:CGPointZero inView:self.view];

    const CGFloat rotationFactor = 0.005;
    const CGFloat rotationLimit = M_PI / 2.5;

    CGVector newRotation = self.renderer.rotationAngles;
    newRotation.dx += rotationFactor * -translation.y;
    newRotation.dy += rotationFactor * -translation.x;
    newRotation.dx = MAX(-rotationLimit, MIN(newRotation.dx, rotationLimit));
    newRotation.dy = MAX(-rotationLimit, MIN(newRotation.dy, rotationLimit));
    self.renderer.rotationAngles = newRotation;
}

- (IBAction)textureMenuButtonWasPressed:(UIButton *)sender
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                             message:@"Select a texture"
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];

    [self.renderer.textures enumerateObjectsUsingBlock:^(id<MTLTexture> texture, NSUInteger index, BOOL *stop) {
        [alertController addAction:[UIAlertAction actionWithTitle:[texture label]
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action)
                                    {
                                        self.renderer.currentTextureIndex = index;
                                    }]];
    }];

    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad)
    {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction *action)
        {
            [self dismissViewControllerAnimated:YES completion:nil];
        }]];
    }

    alertController.popoverPresentationController.sourceView = sender;
    alertController.popoverPresentationController.sourceRect = sender.bounds;

    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)redraw
{
    [self.renderer draw];
}

@end
