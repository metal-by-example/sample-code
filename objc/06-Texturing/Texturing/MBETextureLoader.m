#import "MBETextureLoader.h"

#if TARGET_OS_IPHONE
@import UIKit;
#define NSUIImage UIImage

#else
@import AppKit;
#define NSUIImage NSImage

@interface NSImage (Scale)
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) CGImageRef CGImage;
@end
#endif

@implementation MBETextureLoader

+ (instancetype)sharedTextureLoader
{
    static dispatch_once_t onceToken;
    static MBETextureLoader *instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [MBETextureLoader new];
    });
    return instance;
}

- (id<MTLTexture>)texture2DWithImageNamed:(NSString *)imageName
                                mipmapped:(BOOL)mipmapped
                             commandQueue:(id<MTLCommandQueue>)queue
{
    NSUIImage *image = [NSUIImage imageNamed:imageName];

    if (image == nil)
    {
        return nil;
    }
    
    CGSize imageSize = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
    const NSUInteger bytesPerPixel = 4;
    const NSUInteger bytesPerRow = bytesPerPixel * imageSize.width;
    uint8_t *imageData = [self dataForImage:image];
    
    MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                                 width:imageSize.width
                                                                                                height:imageSize.height
                                                                                             mipmapped:mipmapped];
    textureDescriptor.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> texture = [[queue device] newTextureWithDescriptor:textureDescriptor];

    [texture setLabel:imageName];
    
    MTLRegion region = MTLRegionMake2D(0, 0, imageSize.width, imageSize.height);
    [texture replaceRegion:region mipmapLevel:0 withBytes:imageData bytesPerRow:bytesPerRow];
    
    free(imageData);

    if (mipmapped)
    {
        [self generateMipmapsForTexture:texture onQueue:queue];
    }

    return texture;
}

- (uint8_t *)dataForImage:(NSUIImage *)image
{
    CGImageRef imageRef = image.CGImage;
    
    // Create a suitable bitmap context for extracting the bits of the image
    const NSUInteger width = CGImageGetWidth(imageRef);
    const NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    uint8_t *rawData = (uint8_t *)calloc(height * width * 4, sizeof(uint8_t));
    const NSUInteger bytesPerPixel = 4;
    const NSUInteger bytesPerRow = bytesPerPixel * width;
    const NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);

    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1, -1);
    
    CGRect imageRect = CGRectMake(0, 0, width, height);
    CGContextDrawImage(context, imageRect, imageRef);

    CGContextRelease(context);
    
    return rawData;
}

- (void)generateMipmapsForTexture:(id<MTLTexture>)texture onQueue:(id<MTLCommandQueue>)queue
{
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    [blitEncoder generateMipmapsForTexture:texture];
    [blitEncoder endEncoding];
    [commandBuffer commit];

    // block
    [commandBuffer waitUntilCompleted];
}

@end

#if TARGET_OS_OSX
@implementation NSImage (Scale)

- (CGFloat)scale { return 1.0; }

- (CGImageRef)CGImage {
    return [self CGImageForProposedRect:NULL context:NULL hints:nil];
}

@end
#endif

