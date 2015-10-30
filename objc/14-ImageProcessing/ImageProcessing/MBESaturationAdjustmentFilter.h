@import Foundation;
#import "MBEContext.h"
#import "MBEImageFilter.h"

@interface MBESaturationAdjustmentFilter : MBEImageFilter

@property (nonatomic, assign) float saturationFactor;

+ (instancetype)filterWithSaturationFactor:(float)saturation context:(MBEContext *)context;

@end

