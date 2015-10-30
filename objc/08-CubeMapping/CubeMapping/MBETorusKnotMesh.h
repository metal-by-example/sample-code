#import "MBEMesh.h"
@import Metal;

@interface MBETorusKnotMesh : MBEMesh

/// `parameters` must be an NSArray containing two co-prime integers p, q, wrapped as NSNumbers.
- (instancetype)initWithParameters:(NSArray *)parameters
                        tubeRadius:(CGFloat)tubeRadius
                      tubeSegments:(NSInteger)segments
                        tubeSlices:(NSInteger)slices
                            device:(id<MTLDevice>)device;

@end
