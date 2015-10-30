@import UIKit;
@import Metal;

#import "MBETypes.h"

@interface MBEMesh : NSObject

@property (nonatomic, readonly) id<MTLBuffer> vertexBuffer;
@property (nonatomic, readonly) id<MTLBuffer> indexBuffer;

@end
