@import Foundation;
@import QuartzCore.CAMetalLayer;

@interface MBERenderer : NSObject

@property (nonatomic, assign) float angularVelocity;
@property (nonatomic, assign) float velocity;
@property (nonatomic, assign) float frameDuration;

- (instancetype)initWithLayer:(CAMetalLayer *)layer;
- (void)draw;

@end
