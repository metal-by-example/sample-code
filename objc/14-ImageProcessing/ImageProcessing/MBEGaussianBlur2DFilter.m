#import "MBEGaussianBlur2DFilter.h"
@import Metal;

@interface MBEGaussianBlur2DFilter ()
@property (nonatomic, strong) id<MTLTexture> blurWeightTexture;
@end

@implementation MBEGaussianBlur2DFilter

@synthesize radius = _radius;
@synthesize sigma = _sigma;

+ (instancetype)filterWithRadius:(float)radius context:(MBEContext *)context
{
    return [[self alloc] initWithRadius:radius context:context];
}

- (instancetype)initWithRadius:(float)radius context:(MBEContext *)context
{
    if ((self = [super initWithFunctionName:@"gaussian_blur_2d" context:context]))
    {
        self.radius = radius;
    }
    return self;
}

- (void)generateBlurWeightTexture
{
    NSAssert(self.radius >= 0, @"Blur radius must be non-negative");
    
    const float radius = self.radius;
    const float sigma = self.sigma;
    const int size = (round(radius) * 2) + 1;
    
    float delta = 0;
    float expScale = 0;;
    if (radius > 0.0)
    {
        delta = (radius * 2) / (size - 1);;
        expScale = -1 / (2 * sigma * sigma);
    }
    
    float *weights = malloc(sizeof(float) * size * size);
    
    float weightSum = 0;
    float y = -radius;
    for (int j = 0; j < size; ++j, y += delta)
    {
        float x = -radius;

        for (int i = 0; i < size; ++i, x += delta)
        {
            float weight = expf((x * x + y * y) * expScale);
            weights[j * size + i] = weight;
            weightSum += weight;
        }
    }

    const float weightScale = 1 / weightSum;
    for (int j = 0; j < size; ++j)
    {
        for (int i = 0; i < size; ++i)
        {
            weights[j * size + i] *= weightScale;
        }
    }
    
    MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                                                                                                 width:size
                                                                                                height:size
                                                                                             mipmapped:NO];
    
    self.blurWeightTexture = [self.context.device newTextureWithDescriptor:textureDescriptor];
    
    MTLRegion region = MTLRegionMake2D(0, 0, size, size);
    [self.blurWeightTexture replaceRegion:region mipmapLevel:0 withBytes:weights bytesPerRow:sizeof(float) * size];

    free(weights);
}

- (void)setRadius:(float)radius
{
    self.dirty = YES;
    _radius = radius;
    _sigma = radius / 2;
    self.blurWeightTexture = nil;
}

- (void)setSigma:(float)sigma
{
    self.dirty = YES;
    _sigma = sigma;
    self.blurWeightTexture = nil;
}

- (void)configureArgumentTableWithCommandEncoder:(id<MTLComputeCommandEncoder>)commandEncoder
{
    if (!self.blurWeightTexture)
    {
        [self generateBlurWeightTexture];
    }
    
    [commandEncoder setTexture:self.blurWeightTexture atIndex:2];
}

@end
