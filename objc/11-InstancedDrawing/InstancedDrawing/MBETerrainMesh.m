#import "MBETerrainMesh.h"
#import "MBETypes.h"

@interface MBETerrainMesh ()
@property (nonatomic, weak) id<MTLDevice> device;
@property (nonatomic, assign) float smoothness;
@property (nonatomic, assign) uint16_t iterations;
@property (nonatomic, assign) size_t stride; // number of vertices per edge
@property (nonatomic, assign) size_t vertexCount;
@property (nonatomic, assign) size_t indexCount;
@property (nonatomic, assign) MBEVertex *vertices;
@property (nonatomic, assign) uint16_t *indices;
@end

@implementation MBETerrainMesh

@synthesize vertexBuffer=_vertexBuffer;
@synthesize indexBuffer=_indexBuffer;

- (instancetype)initWithWidth:(float)width
                       height:(float)height
                   iterations:(uint16_t)iterations
                   smoothness:(float)smoothness
                       device:(id<MTLDevice>)device
{
    if (iterations > 6)
    {
        NSLog(@"Too many terrain mesh subdivisions requested. 16-bit indexing does not suffice.");
        return nil;
    }

    if ((self = [super init]))
    {
        _width = width;
        _depth = width;
        _height = height;
        _smoothness = smoothness;
        _iterations = iterations;
        _device = device;

        [self generateTerrain];
    }
    return self;
}

- (void)dealloc
{
    free (self.vertices);
    free(self.indices);
}

- (void)generateTerrain
{
    self.stride = (1 << self.iterations) + 1; // number of vertices on one side of the terrain patch
    self.vertexCount = self.stride * self.stride;
    self.indexCount = (self.stride - 1) * (self.stride - 1) * 6;
    
    self.vertices = malloc(sizeof(MBEVertex) * self.vertexCount);
    self.indices = malloc(sizeof(uint16_t) * self.indexCount);
    
    float variance = 1.0; // absolute maximum variance about mean height value
    const float smoothingFactor = powf(2, -self.smoothness); // factor by which to decrease variance each iteration

    // seed corners with 0.
    self.vertices[0].position.y = 0.0;
    self.vertices[self.stride].position.y = 0.0;
    self.vertices[(self.stride - 1) * self.stride].position.y = 0.0;
    self.vertices[(self.stride * self.stride) - 1].position.y = 0.0;

    for (int i = 0; i < self.iterations; ++i)
    {
        int numSquares = (1 << i); // squares per edge at the current subdivision level (1, 2, 4, 8)
        int squareSize = (1 << (self.iterations - i)); // edge length of square at current subdivision (CHECK THIS)

        for (int y = 0; y < numSquares; ++y)
        {
            for (int x = 0; x < numSquares; ++x)
            {
                int r = y * squareSize;
                int c = x * squareSize;
                [self performSquareStepWithRow:r column:c squareSize:squareSize variance:variance];
                [self performDiamondStepWithRow:r column:c squareSize:squareSize variance:variance];
            }
        }
        
        variance *= smoothingFactor;
    }

    [self computeMeshCoordinates];
    [self computeMeshNormals];
    [self generateMeshIndices];

    _vertexBuffer = [self.device newBufferWithBytes:self.vertices
                                             length:sizeof(MBEVertex) * self.vertexCount
                                            options:MTLResourceOptionCPUCacheModeDefault];
    [_vertexBuffer setLabel:@"Vertices (Terrain)"];

    
    _indexBuffer = [self.device newBufferWithBytes:self.indices
                                            length:sizeof(uint16_t) * self.indexCount
                                           options:MTLResourceOptionCPUCacheModeDefault];
    [_indexBuffer setLabel:@"Indices (Terrain)"];
}

- (void)performSquareStepWithRow:(int)row column:(int)column squareSize:(int)squareSize variance:(float)variance
{
    size_t r0 = row;
    size_t c0 = column;
    size_t r1 = (r0 + squareSize) % self.stride;
    size_t c1 = (c0 + squareSize) % self.stride;
    size_t cmid = c0 + (squareSize / 2);
    size_t rmid = r0 + (squareSize / 2);
    float y00 = self.vertices[r0 * self.stride + c0].position.y;
    float y01 = self.vertices[r0 * self.stride + c1].position.y;
    float y11 = self.vertices[r1 * self.stride + c1].position.y;
    float y10 = self.vertices[r1 * self.stride + c0].position.y;
    float ymean = (y00 + y01 + y11 + y10) * 0.25;
    float error = (((arc4random() / (float)(UINT32_MAX)) - 0.5) * 2) * variance;
    float y = ymean + error;
    self.vertices[rmid * self.stride + cmid].position.y = y;
}

- (void)performDiamondStepWithRow:(int)row column:(int)column squareSize:(int)squareSize variance:(float)variance
{
    size_t r0 = row;
    size_t c0 = column;
    size_t r1 = (r0 + squareSize) % self.stride;
    size_t c1 = (c0 + squareSize) % self.stride;
    size_t cmid = c0 + (squareSize / 2);
    size_t rmid = r0 + (squareSize / 2);
    float y00 = self.vertices[r0 * self.stride + c0].position.y;
    float y01 = self.vertices[r0 * self.stride + c1].position.y;
    float y11 = self.vertices[r1 * self.stride + c1].position.y;
    float y10 = self.vertices[r1 * self.stride + c0].position.y;
    float error = 0;
    error = (((arc4random() / (float)(UINT32_MAX)) - 0.5) * 2) * variance;
    self.vertices[r0 * self.stride + cmid].position.y = (y00 + y01) * 0.5 + error;
    error = (((arc4random() / (float)(UINT32_MAX)) - 0.5) * 2) * variance;
    self.vertices[rmid * self.stride + c0].position.y = (y00 + y10) * 0.5 + error;
    error = (((arc4random() / (float)(UINT32_MAX)) - 0.5) * 2) * variance;
    self.vertices[rmid * self.stride + c1].position.y = (y01 + y11) * 0.5 + error;
    error = (((arc4random() / (float)(UINT32_MAX)) - 0.5) * 2) * variance;
    self.vertices[r1 * self.stride + cmid].position.y = (y01 + y11) * 0.5 + error;
}

- (void)computeMeshCoordinates
{
    for (int r = 0; r < self.stride; ++r)
    {
        for (int c = 0; c < self.stride; ++c)
        {
            float x = ((float)c / (self.stride - 1) - 0.5) * self.width;
            float y = self.vertices[r * self.stride + c].position.y * self.height;
            float z = ((float)r / (self.stride - 1) - 0.5) * self.depth;
            self.vertices[r * self.stride + c].position = (vector_float4){ x, y, z, 1 };
            
            float s = (float)c / (self.stride - 1) * 5;
            float t = (float)r / (self.stride - 1) * 5;
            self.vertices[r * self.stride + c].texCoords = (vector_float2){s, t};
        }
    }
}

- (void)computeMeshNormals
{
    const float yScale = 4;
    for (int r = 0; r < self.stride; ++r)
    {
        for (int c = 0; c < self.stride; ++c)
        {
            if (r > 0 && c > 0 && r < self.stride - 1 && c < self.stride - 1)
            {
                vector_float4 L = self.vertices[r * self.stride + (c - 1)].position;
                vector_float4 R = self.vertices[r * self.stride + (c + 1)].position;
                vector_float4 U = self.vertices[(r - 1) * self.stride + c].position;
                vector_float4 D = self.vertices[(r + 1) * self.stride + c].position;
                vector_float3 T = { R.x - L.x, (R.y - L.y) * yScale, 0 };
                vector_float3 B = { 0, (D.y - U.y) * yScale, D.z - U.z };
                vector_float3 N = vector_cross(B, T);
                vector_float4 normal = { N.x, N.y, N.z, 0 };
                normal = vector_normalize(normal);
                self.vertices[r * self.stride + c].normal = normal;
            }
            else
            {
                vector_float4 N = { 0, 1, 0, 0 };
                self.vertices[r * self.stride + c].normal = N;
            }
        }
    }
}

- (void)generateMeshIndices
{
    uint16_t i = 0;
    for (int r = 0; r < self.stride - 1; ++r)
    {
        for (int c = 0; c < self.stride - 1; ++c)
        {
            self.indices[i++] = r * self.stride + c;
            self.indices[i++] = (r + 1) * self.stride + c;
            self.indices[i++] = (r + 1) * self.stride + (c + 1);
            self.indices[i++] = (r + 1) * self.stride + (c + 1);
            self.indices[i++] = r * self.stride + (c + 1);
            self.indices[i++] = r * self.stride + c;
        }
    }
}

- (float)heightAtPositionX:(float)x z:(float)z
{
    float halfSize = self.width / 2;
    
    if (x < -halfSize || x > halfSize || z < -halfSize || z > halfSize)
        return 0.0;

    // Normalize x and z between 0 and 1
    float nx = (x / self.width) + 0.5;
    float nz = (z / self.depth) + 0.5;

    // Compute fractional indices of nearest vertices
    float fx = nx * (self.stride - 1);
    float fz = nz * (self.stride - 1);

    // Compute index of nearest vertices that are "up" and to the left
    int ix = floorf(fx);
    int iz = floorf(fz);
    
    // Compute fractional offsets in the direction of next nearest vertices
    float dx = fx - ix;
    float dz = fz - iz;

    // Get heights of nearest vertices
    float y00 = self.vertices[iz * self.stride + ix].position.y;
    float y01 = self.vertices[iz * self.stride + (ix + 1)].position.y;
    float y10 = self.vertices[(iz + 1) * self.stride + ix].position.y;
    float y11 = self.vertices[(iz + 1) * self.stride + (ix + 1)].position.y;
    
    // Perform bilinear interpolation to get approximate height at point
    float ytop = ((1 - dx) * y00) + (dx * y01);
    float ybot = ((1 - dx) * y10) + (dx * y11);
    float y = ((1 - dz) * ytop) + (dz * ybot);

    return y;
}

@end
