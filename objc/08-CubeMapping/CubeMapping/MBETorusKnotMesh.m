#import "MBETorusKnotMesh.h"
#import "MBETypes.h"
@import simd;

@interface MBETorusKnotMesh ()
@property (nonatomic, assign) NSInteger p;
@property (nonatomic, assign) NSInteger q;
@property (nonatomic, assign) NSInteger segments;
@property (nonatomic, assign) NSInteger slices;
@property (nonatomic, assign) CGFloat tubeRadius;
@property (nonatomic, weak) id<MTLDevice> device;
@end

@implementation MBETorusKnotMesh

@synthesize vertexBuffer=_vertexBuffer;
@synthesize indexBuffer=_indexBuffer;

- (instancetype)initWithParameters:(NSArray *)parameters
                        tubeRadius:(CGFloat)tubeRadius
                      tubeSegments:(NSInteger)segments
                        tubeSlices:(NSInteger)slices
                            device:(id<MTLDevice>)device
{
    if ((self = [super init]))
    {
        NSParameterAssert(device);
        NSAssert(parameters.count == 2, @"Torus knot parameters array must contain exactly two elements");
        
        _p = [parameters[0] integerValue];
        _q = [parameters[1] integerValue];
        _segments = segments;
        _slices = slices;
        _tubeRadius = tubeRadius;
        _device = device;
        
        [self generateGeometry];
    }
    return self;
}

- (void)generateGeometry
{
    size_t vertexCount = (self.segments + 1) * (self.slices + 1);
    size_t indexCount = (self.segments) * (self.slices + 1) * 6;
    
    MBEVertex *vertices = malloc(sizeof(MBEVertex) * vertexCount);
    uint16_t *indices = malloc(sizeof(uint16_t) * indexCount);

    const float epsilon = 1e-4;
    const float dt = (2 * M_PI) / (self.segments);
    const float du = (2 * M_PI) / self.slices;
    
    size_t vi = 0;
    for (size_t i = 0; i <= self.segments; ++i)
    {
        // calculate a point that lies on the curve
        float t0 = i * dt;
        float r0 = (2 + cosf(_q * t0)) * 0.5;
        vector_float3 p0 = { r0 * cosf(_p * t0),
                             r0 * sinf(_p * t0),
                             -sinf(_q * t0) };

        // approximate the Frenet frame { T, N, B } for the curve at the current point
        
        float t1 = t0 + epsilon;
        float r1 = (2 + cosf(_q * t1)) * 0.5;
        
        // p1 is p0 advanced infinitesimally along the curve
        vector_float3 p1 = { r1 * cosf(_p * t1),
                             r1 * sinf(_p * t1),
                             -sinf(_q * t1) };
        
        // compute approximate tangent as vector connecting p0 to p1
        vector_float3 T = { p1.x - p0.x,
                            p1.y - p0.y,
                            p1.z - p0.z };
        
        // rough approximation of normal vector
        vector_float3 N = { p1.x + p0.x,
                            p1.y + p0.y,
                            p1.z + p0.z };
        
        // compute binormal of curve
        vector_float3 B = vector_cross(T, N);
        
        // refine normal vector by Graham-Schmidt
        N = vector_cross(B, T);

        B = vector_normalize(B);
        N = vector_normalize(N);

        // generate points in a circle perpendicular to the curve at the current point
        for (size_t j = 0; j <= self.slices; ++j, ++vi)
        {
            float u = j * du;
            
            // compute position of circle point
            float x = _tubeRadius * cosf(u);
            float y = _tubeRadius * sinf(u);
            
            vector_float3 p2 = { x * N.x + y * B.x,
                                 x * N.y + y * B.y,
                                 x * N.z + y * B.z };

            vertices[vi].position.x = p0.x + p2.x;
            vertices[vi].position.y = p0.y + p2.y;
            vertices[vi].position.z = p0.z + p2.z;
            vertices[vi].position.w = 1;
            
            // compute normal of circle point
            vector_float3 n2 = vector_normalize(p2);
            
            vertices[vi].normal.x = n2.x;
            vertices[vi].normal.y = n2.y;
            vertices[vi].normal.z = n2.z;
            vertices[vi].normal.w = 0;
        }
    }
    
    // generate triplets of indices to create torus triangles
    size_t i = 0;
    for (size_t vi = 0; vi < (self.segments) * (self.slices + 1); ++vi)
    {
        indices[i++] = vi;
        indices[i++] = vi + self.slices + 1;
        indices[i++] = vi + self.slices;

        indices[i++] = vi;
        indices[i++] = vi + 1;
        indices[i++] = vi + self.slices + 1;
    }

    _vertexBuffer = [self.device newBufferWithBytes:vertices
                                             length:sizeof(MBEVertex) * vertexCount
                                            options:0];
    
    _indexBuffer = [self.device newBufferWithBytes:indices
                                            length:sizeof(uint16_t) * indexCount
                                           options:0];
    
    free(indices);
    free(vertices);
}

@end
