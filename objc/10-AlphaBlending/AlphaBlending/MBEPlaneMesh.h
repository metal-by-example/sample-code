#import "MBEMesh.h"
@import simd;

@interface MBEPlaneMesh : MBEMesh

/// Generates a planar mesh with the specified dimensions and subdivision counts.
/// Texture coordinates are multiplied by textureScale to allow tiling, and
/// opacity is set as the alpha value of the diffuse color of each vertex.
- (instancetype)initWithWidth:(float)width
                        depth:(float)depth
                   divisionsX:(unsigned int)divisionsX
                   divisionsZ:(unsigned int)divisionsZ
                 textureScale:(float)textureScale
                      opacity:(float)opacity
                       device:(id<MTLDevice>)device;

@end
