#import "MBEMainBundleTextureProvider.h"
#import "MBEContext.h"

@import Metal;

@interface MBEMainBundleTextureProvider ()
@property (nonatomic, strong) id<MTLTexture> texture;
@end

@implementation MBEMainBundleTextureProvider

+ (instancetype)textureProviderWithImageNamed:(NSString *)imageName context:(MBEContext *)context
{
    return [[self alloc] initWithImageNamed:imageName context:context];
}

- (instancetype)initWithImageNamed:(NSString *)imageName context:(MBEContext *)context
{
    if ((self = [super init]))
    {
        UIImage *image = [UIImage imageNamed:imageName];
        _texture = [self textureForImage:image context:context];
    }
    return self;
}

- (id<MTLTexture>)textureForImage:(UIImage *)image context:(MBEContext *)context
{
    CGImageRef imageRef = [image CGImage];
    
    // Create a suitable bitmap context for extracting the bits of the image
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    uint8_t *rawData = (uint8_t *)calloc(height * width * 4, sizeof(uint8_t));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef bitmapContext = CGBitmapContextCreate(rawData, width, height,
                                                       bitsPerComponent, bytesPerRow, colorSpace,
                                                       kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    // Flip the context so the positive Y axis points down
    CGContextTranslateCTM(bitmapContext, 0, height);
    CGContextScaleCTM(bitmapContext, 1, -1);
    
    CGContextDrawImage(bitmapContext, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(bitmapContext);
    
    MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                                 width:width
                                                                                                height:height
                                                                                             mipmapped:NO];
    id<MTLTexture> texture = [context.device newTextureWithDescriptor:textureDescriptor];
    
    MTLRegion region = MTLRegionMake2D(0, 0, width, height);
    [texture replaceRegion:region mipmapLevel:0 withBytes:rawData bytesPerRow:bytesPerRow];
    
    free(rawData);
    
    return texture;
}

- (void)provideTexture:(void (^)(id<MTLTexture>))textureBlock
{
    if (textureBlock)
    {
        textureBlock(self.texture);
    }
}

@end
