@import UIKit;
@import QuartzCore.CAMetalLayer;
@import Metal;

typedef NS_ENUM(NSInteger, MBEMipmappingMode)
{
    MBEMipmappingModeNone,
    MBEMipmappingModeBlitGeneratedLinear,
    MBEMipmappingModeVibrantLinear,
    MBEMipmappingModeVibrantNearest
};

@interface MBERenderer : NSObject

@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) CAMetalLayer *layer;

@property (nonatomic, assign) float cameraDistance;
@property (nonatomic, assign) MBEMipmappingMode mipmappingMode;

- (instancetype)initWithLayer:(CAMetalLayer *)layer;
- (void)draw;

@end
