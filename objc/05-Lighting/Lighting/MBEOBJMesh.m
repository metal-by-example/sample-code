#import "MBEOBJMesh.h"
#import "MBEOBJGroup.h"

@implementation MBEOBJMesh

@synthesize indexBuffer=_indexBuffer;
@synthesize vertexBuffer=_vertexBuffer;

- (instancetype)initWithGroup:(MBEOBJGroup *)group device:(id<MTLDevice>)device
{
    if ((self = [super init]))
    {
        _vertexBuffer = [device newBufferWithBytes:[group.vertexData bytes]
                                            length:[group.vertexData length]
                                           options:MTLResourceOptionCPUCacheModeDefault];
        [_vertexBuffer setLabel:[NSString stringWithFormat:@"Vertices (%@)", group.name]];
        
        _indexBuffer = [device newBufferWithBytes:[group.indexData bytes]
                                           length:[group.indexData length]
                                          options:MTLResourceOptionCPUCacheModeDefault];
        [_indexBuffer setLabel:[NSString stringWithFormat:@"Indices (%@)", group.name]];
    }
    return self;
}

@end
