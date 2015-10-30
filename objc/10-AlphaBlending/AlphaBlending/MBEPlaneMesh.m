#import "MBEPlaneMesh.h"
#import "MBETypes.h"
#import "MBEMathUtilities.h"

@implementation MBEPlaneMesh

@synthesize vertexBuffer=_vertexBuffer;
@synthesize indexBuffer=_indexBuffer;

- (instancetype)initWithWidth:(float)width
                        depth:(float)depth
                   divisionsX:(unsigned int)divisionsX
                   divisionsZ:(unsigned int)divisionsZ
                 textureScale:(float)textureScale
                      opacity:(float)opacity
                       device:(id<MTLDevice>)device
{
    if ((self = [super init]))
    {
        [self generateBuffersWithWidth:width
                                 depth:depth
                            divisionsX:divisionsX
                            divisionsZ:divisionsZ
                          textureScale:textureScale
                               opacity:opacity
                                device:device];
    }

    return self;
}

- (void)generateBuffersWithWidth:(float)width
                           depth:(float)depth
                      divisionsX:(unsigned int)divisionsX
                      divisionsZ:(unsigned int)divisionsZ
                    textureScale:(float)textureScale
                         opacity:(float)opacity
                          device:(id<MTLDevice>)device
{
    size_t vertexCount = (divisionsX + 1) * (divisionsZ + 1);
    size_t indexCount = divisionsX * divisionsZ * 6;

    MBEVertex *vertices = malloc(sizeof(MBEVertex) * vertexCount);
    MBEIndex *indices = malloc(sizeof(MBEIndex) * indexCount);

    float dx = width / (divisionsX + 1);
    float dz = depth / (divisionsZ + 1);
    float y = 0, z = depth * -0.5;
    for (int r = 0, v = 0; r < (divisionsZ + 1); ++r)
    {
        float x = width * -0.5;
        for (int c = 0; c < (divisionsX + 1); ++c)
        {
            vertices[v].position = (vector_float4){ x, y, z, 1 };

            vertices[v].normal = (vector_float4){ 0, 1, 0, 0 };

            float s = ((x / width) + 0.5) * textureScale;
            float t = ((z / depth) + 0.5) * textureScale;
            vertices[v].texCoords = (vector_float2){ s, t };

            vertices[v].diffuseColor = (vector_float4){ 1, 1, 1, opacity };

            x += dx;
            ++v;
        }
        z += dz;
    }

    for (int r = 0, i = 0; r < divisionsZ; ++r)
    {
        for (int c = 0; c < divisionsX; ++c)
        {
            int v = (c * divisionsX) + r;
            indices[i++] = v;
            indices[i++] = v + divisionsX;
            indices[i++] = v + divisionsX + 1;
            indices[i++] = v + divisionsX + 1;
            indices[i++] = v + 1;
            indices[i++] = v;
        }
    }

    _vertexBuffer = [device newBufferWithBytes:vertices
                                        length:sizeof(MBEVertex) * vertexCount
                                       options:MTLResourceOptionCPUCacheModeDefault];
    _indexBuffer = [device newBufferWithBytes:indices
                                       length:sizeof(MBEIndex) * indexCount
                                      options:MTLResourceOptionCPUCacheModeDefault];

    free(vertices);
    free(indices);
}

@end
