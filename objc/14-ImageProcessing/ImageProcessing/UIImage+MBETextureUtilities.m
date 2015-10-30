#import "UIImage+MBETextureUtilities.h"
@import Metal;

static void MBEReleaseDataCallback(void *info, const void *data, size_t size)
{
    free((void *)data);
}

@implementation UIImage (MBETextureUtilities)

+ (UIImage *)imageWithMTLTexture:(id<MTLTexture>)texture
{
    NSAssert([texture pixelFormat] == MTLPixelFormatRGBA8Unorm, @"Pixel format of texture must be MTLPixelFormatBGRA8Unorm to create UIImage");
    
    CGSize imageSize = CGSizeMake([texture width], [texture height]);
    size_t imageByteCount = imageSize.width * imageSize.height * 4;
    void *imageBytes = malloc(imageByteCount);
    NSUInteger bytesPerRow = imageSize.width * 4;
    MTLRegion region = MTLRegionMake2D(0, 0, imageSize.width, imageSize.height);
    [texture getBytes:imageBytes bytesPerRow:bytesPerRow fromRegion:region mipmapLevel:0];
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, imageBytes, imageByteCount, MBEReleaseDataCallback);
    int bitsPerComponent = 8;
    int bitsPerPixel = 32;
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    CGImageRef imageRef = CGImageCreate(imageSize.width,
                                        imageSize.height,
                                        bitsPerComponent,
                                        bitsPerPixel,
                                        bytesPerRow,
                                        colorSpaceRef,
                                        bitmapInfo,
                                        provider,
                                        NULL,
                                        false,
                                        renderingIntent);
    
    UIImage *image = [UIImage imageWithCGImage:imageRef scale:0.0 orientation:UIImageOrientationDownMirrored];
    
    CFRelease(provider);
    CFRelease(colorSpaceRef);
    CFRelease(imageRef);
    
    return image;
}

@end
