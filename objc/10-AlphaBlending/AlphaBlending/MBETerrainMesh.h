#import "MBEMesh.h"

@interface MBETerrainMesh : MBEMesh

@property (nonatomic, readonly) float width;
@property (nonatomic, readonly) float depth;
@property (nonatomic, readonly) float height;

/// Generates a square patch of terrain, using the diamond-square midpoint displacement algorithm.
/// Smoothness varies from 0 to 1, with 1 being the smoothest. `iterations` determines how many
/// times the recursive subdivision algorithm is applied; the total number of triangles is
/// 2 * (2 ^ (2 * iterations)). `width` determines both the width and depth of the patch. `height`
/// is the maximum possible distance from the lowest point to the highest point on the patch.
- (instancetype)initWithWidth:(float)width
                       height:(float)height
                   iterations:(uint16_t)iterations
                   smoothness:(float)smoothness
                       device:(id<MTLDevice>)device;

- (float)heightAtPositionX:(float)x z:(float)z;

@end
