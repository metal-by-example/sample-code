#import "MBEMaterial.h"

@implementation MBEMaterial

- (instancetype)initWithVertexFunction:(id<MTLFunction>)vertexFunction
                      fragmentFunction:(id<MTLFunction>)fragmentFunction
                        diffuseTexture:(id<MTLTexture>)diffuseTexture
{
    if ((self = [super init]))
    {
        _vertexFunction = vertexFunction;
        _fragmentFunction = fragmentFunction;
        _diffuseTexture = diffuseTexture;
    }
    return self;
}

@end
