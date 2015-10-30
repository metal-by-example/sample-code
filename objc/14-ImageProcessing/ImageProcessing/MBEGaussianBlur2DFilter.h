@import Foundation;
#import "MBEImageFilter.h"

@interface MBEGaussianBlur2DFilter : MBEImageFilter

@property (nonatomic, assign) float radius;
@property (nonatomic, assign) float sigma;

+ (instancetype)filterWithRadius:(float)radius context:(MBEContext *)context;

@end

