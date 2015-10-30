#import "MBEViewController.h"
#import "MBEContext.h"
#import "MBEImageFilter.h"
#import "MBESaturationAdjustmentFilter.h"
#import "MBEGaussianBlur2DFilter.h"
#import "UIImage+MBETextureUtilities.h"
#import "MBEMainBundleTextureProvider.h"

@interface MBEViewController ()

@property (nonatomic, strong) MBEContext *context;
@property (nonatomic, strong) id<MBETextureProvider> imageProvider;
@property (nonatomic, strong) MBESaturationAdjustmentFilter *desaturateFilter;
@property (nonatomic, strong) MBEGaussianBlur2DFilter *blurFilter;

@property (nonatomic, strong) dispatch_queue_t renderingQueue;
@property (atomic, assign) uint64_t jobIndex;

@end

@implementation MBEViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.renderingQueue = dispatch_queue_create("Rendering", DISPATCH_QUEUE_SERIAL);

    [self buildFilterGraph];
    [self updateImage];
}

- (void)buildFilterGraph
{
    self.context = [MBEContext newContext];
    
    self.imageProvider = [MBEMainBundleTextureProvider textureProviderWithImageNamed:@"mandrill"
                                                                             context:self.context];
    
    self.desaturateFilter = [MBESaturationAdjustmentFilter filterWithSaturationFactor:self.saturationSlider.value
                                                                              context:self.context];
    self.desaturateFilter.provider = self.imageProvider;
    
    self.blurFilter = [MBEGaussianBlur2DFilter filterWithRadius:self.blurRadiusSlider.value
                                                        context:self.context];
    self.blurFilter.provider = self.desaturateFilter;
}

- (void)updateImage
{
    ++self.jobIndex;
    uint64_t currentJobIndex = self.jobIndex;

    // Grab these values while we're still on the main thread, since we could
    // conceivably get incomplete values by reading them in the background.
    float blurRadius = self.blurRadiusSlider.value;
    float saturation = self.saturationSlider.value;
    
    dispatch_async(self.renderingQueue, ^{
        if (currentJobIndex != self.jobIndex)
            return;

        self.blurFilter.radius = blurRadius;
        self.desaturateFilter.saturationFactor = saturation;

        id<MTLTexture> texture = self.blurFilter.texture;
        UIImage *image = [UIImage imageWithMTLTexture:texture];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.imageView.image = image;
        });
    });
}

- (IBAction)blurRadiusDidChange:(id)sender
{
    [self updateImage];
}

- (IBAction)saturationDidChange:(id)sender
{
    [self updateImage];
}

@end
