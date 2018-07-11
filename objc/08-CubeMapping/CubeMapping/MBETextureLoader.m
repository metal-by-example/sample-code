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

+ (uint8_t *)dataForImage:(NSUIImage *)image
{
    CGImageRef imageRef = [image CGImage];
    
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

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    return rawData;
}

+ (id<MTLTexture>)texture2DWithImageNamed:(NSString *)imageName device:(id<MTLDevice>)device
{
    NSUIImage *image = [NSUIImage imageNamed:imageName];
    CGSize imageSize = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
    const NSUInteger bytesPerPixel = 4;
    const NSUInteger bytesPerRow = bytesPerPixel * imageSize.width;
    uint8_t *imageData = [self dataForImage:image];
    
    MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                                 width:imageSize.width
                                                                                                height:imageSize.height
                                                                                             mipmapped:NO];
    id<MTLTexture> texture = [device newTextureWithDescriptor:textureDescriptor];
    
    MTLRegion region = MTLRegionMake2D(0, 0, imageSize.width, imageSize.height);
    [texture replaceRegion:region mipmapLevel:0 withBytes:imageData bytesPerRow:bytesPerRow];
    
    free(imageData);
    
    return texture;
}

+ (id<MTLTexture>)textureCubeWithImagesNamed:(NSArray *)imageNameArray device:(id<MTLDevice>)device
{
    NSAssert(imageNameArray.count == 6, @"Cube texture can only be created from exactly six images");
    
    NSUIImage *firstImage = [NSUIImage imageNamed:[imageNameArray firstObject]];
    const CGFloat cubeSize = firstImage.size.width * firstImage.scale;
    
    const NSUInteger bytesPerPixel = 4;
    const NSUInteger bytesPerRow = bytesPerPixel * cubeSize;
    const NSUInteger bytesPerImage = bytesPerRow * cubeSize;

    MTLRegion region = MTLRegionMake2D(0, 0, cubeSize, cubeSize);
    
    MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                                    size:cubeSize
                                                                                               mipmapped:NO];
    
    id<MTLTexture> texture = [device newTextureWithDescriptor:textureDescriptor];

    for (size_t slice = 0; slice < 6; ++slice)
    {
        NSString *imageName = imageNameArray[slice];
        NSUIImage *image = [NSUIImage imageNamed:imageName];
        uint8_t *imageData = [self dataForImage:image];
        
        NSAssert(image.size.width == cubeSize && image.size.height == cubeSize, @"Cube map images must be square and uniformly-sized");
        
        [texture replaceRegion:region
                   mipmapLevel:0
                         slice:slice
                     withBytes:imageData
                   bytesPerRow:bytesPerRow
                 bytesPerImage:bytesPerImage];
        free(imageData);
    }

    return texture;
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
