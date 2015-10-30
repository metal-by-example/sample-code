@import Foundation;
@import Metal;
#import "MBEMesh.h"

@class MBEOBJGroup;

@interface MBEOBJMesh : MBEMesh

- (instancetype)initWithGroup:(MBEOBJGroup *)group device:(id<MTLDevice>)device;

@end
