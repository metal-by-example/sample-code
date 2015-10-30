@import Foundation;
@import simd;

@interface MBECow : NSObject
@property (nonatomic, assign) vector_float3 position;
@property (nonatomic, assign) float targetHeading;
@property (nonatomic, assign) float heading;
@end
