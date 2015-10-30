@import Foundation;
@import Metal;
@import QuartzCore.CAMetalLayer;

@interface MBERenderer : NSObject

@property (nonatomic, readonly) NSArray *textures;
@property (nonatomic, assign) NSInteger currentTextureIndex;
@property (nonatomic, assign) CGVector rotationAngles;

- (instancetype)initWithLayer:(CAMetalLayer *)layer;
- (void)draw;

@end
