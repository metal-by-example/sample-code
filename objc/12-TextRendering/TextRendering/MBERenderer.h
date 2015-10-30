@import Foundation;
@import QuartzCore.CAMetalLayer;

@interface MBERenderer : NSObject

@property (nonatomic, assign) CGPoint textTranslation;
@property (nonatomic, assign) CGFloat textScale;

- (instancetype)initWithLayer:(CAMetalLayer *)layer;
- (void)draw;

@end
