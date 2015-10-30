@import UIKit;

@interface MBEViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UISlider *blurRadiusSlider;
@property (weak, nonatomic) IBOutlet UISlider *saturationSlider;

- (IBAction)blurRadiusDidChange:(id)sender;
- (IBAction)saturationDidChange:(id)sender;

@end
