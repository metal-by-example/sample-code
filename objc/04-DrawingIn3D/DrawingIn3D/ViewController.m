#import "ViewController.h"
#import "MBEMetalView.h"

@interface ViewController ()
@property (nonatomic, strong) MBERenderer *renderer;
@end

@implementation ViewController

- (MBEMetalView *)metalView {
    return (MBEMetalView *)self.view;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.renderer = [MBERenderer new];
    self.metalView.delegate = self.renderer;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

@end
