#import "MBETextureGenerator.h"

static const NSUInteger bytesPerPixel = 4;

@implementation MBETextureGenerator

+ (void)checkerboardTextureWithSize:(CGSize)size
                          tileCount:(size_t)tileCount
                    colorfulMipmaps:(BOOL)colorfulMipmaps
                             device:(id<MTLDevice>)device
                         completion:(void (^)(id<MTLTexture>))completionBlock
{
    const NSUInteger bytesPerRow = bytesPerPixel * size.width;
    
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                          width:size.width
                                                                                         height:size.height
                                                                                      mipmapped:YES];
    
    id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
    
    CGImageRef image;
    NSData *baseLevelData = [self createCheckerboardImageDataWithSize:size tileCount:tileCount image:&image];
    
    MTLRegion region = MTLRegionMake2D(0, 0, size.width, size.height);
    [texture replaceRegion:region mipmapLevel:0 withBytes:[baseLevelData bytes] bytesPerRow:bytesPerRow];
    
    if (colorfulMipmaps)
    {
        [self generateTintedMipmapsForTexture:texture
                                        image:image
                              completionBlock:completionBlock];
    }
    else
    {
        [self generateMipmapsAcceleratedForTexture:texture
                                            device:device
                                   completionBlock:completionBlock];
    }
}

+ (NSData *)createCheckerboardImageDataWithSize:(CGSize)size tileCount:(size_t)tileCount image:(CGImageRef *)outImage
{
    const NSUInteger width = size.width;
    const NSUInteger height = size.height;
    
    if (width % tileCount != 0 || height % tileCount != 0)
    {
        NSLog(@"Texture generator was asked for a checkerboard image with non-whole tile sizes: "
              "size is %d x %d, but tileCount is %d, which doesn't divide evenly. The resulting image will have gaps.",
              (int)width, (int)height, (int)tileCount);
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    size_t dataLength = height * width * bytesPerPixel;
    uint8_t *data = (uint8_t *)calloc(dataLength, sizeof(uint8_t));
    const NSUInteger bytesPerRow = bytesPerPixel * width;
    const NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(data,
                                                 width,
                                                 height,
                                                 bitsPerComponent,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1, -1);
    
    const CGFloat lightValue = 0.95;
    const CGFloat darkValue = 0.15;
    const NSUInteger tileWidth = width / tileCount;
    const NSUInteger tileHeight = height / tileCount;
    
    for (size_t r = 0; r < tileCount; ++r)
    {
        BOOL useLightColor = (r % 2 == 0);
        for (size_t c = 0; c < tileCount; ++c)
        {
            CGFloat value = useLightColor ? lightValue : darkValue;
            CGContextSetRGBFillColor(context, value, value, value, 1.0);
            CGContextFillRect(context, CGRectMake(r * tileHeight, c * tileWidth, tileWidth, tileHeight));
            useLightColor =! useLightColor;
        }
    }
    
    if (outImage)
    {
        *outImage = CGBitmapContextCreateImage(context);
    }
    
    CGContextRelease(context);
    
    return [NSData dataWithBytesNoCopy:data length:dataLength freeWhenDone:YES];
}

+ (void)generateTintedMipmapsForTexture:(id<MTLTexture>)texture
                                  image:(CGImageRef)image
                        completionBlock:(void (^)(id<MTLTexture>))completionBlock
{
    NSUInteger level = 1;
    NSUInteger mipWidth = [texture width] / 2;
    NSUInteger mipHeight = [texture height] / 2;
    CGImageRef scaledImage;
    CGImageRetain(image);
    
    while (mipWidth >= 1 && mipHeight >= 1)
    {
        NSUInteger mipBytesPerRow = bytesPerPixel * mipWidth;
        
        UIColor *tintColor = [self tintColorAtIndex:level - 1];
        NSData *mipData = [self createResizedImageDataForImage:image
                                                          size:CGSizeMake(mipWidth, mipHeight)
                                                     tintColor:tintColor
                                                         image:&scaledImage];
        
        CGImageRelease(image);
        image = scaledImage;
        
        MTLRegion region = MTLRegionMake2D(0, 0, mipWidth, mipHeight);
        [texture replaceRegion:region mipmapLevel:level withBytes:[mipData bytes] bytesPerRow:mipBytesPerRow];
        
        mipWidth /= 2;
        mipHeight /= 2;
        ++level;
    }
    
    CGImageRelease(image);
    
    completionBlock(texture);
}

+ (void)generateMipmapsAcceleratedForTexture:(id<MTLTexture>)texture
                                      device:(id<MTLDevice>)device
                             completionBlock:(void (^)(id<MTLTexture>))completionBlock
{
    id<MTLCommandQueue> commandQueue = [device newCommandQueue];
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    id<MTLBlitCommandEncoder> commandEncoder = [commandBuffer blitCommandEncoder];
    [commandEncoder generateMipmapsForTexture:texture];
    [commandEncoder endEncoding];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        completionBlock(texture);
    }];
    [commandBuffer commit];
}

+ (NSData *)createResizedImageDataForImage:(CGImageRef)image
                                      size:(CGSize)size
                                 tintColor:(UIColor *)tintColor
                                     image:(CGImageRef *)outImage
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    size_t dataLength = size.height * size.width * 4;
    uint8_t *data = (uint8_t *)calloc(dataLength, sizeof(uint8_t));
    const NSUInteger bitsPerComponent = 8;
    const NSUInteger bytesPerPixel = 4;
    const NSUInteger bytesPerRow = bytesPerPixel * size.width;
    
    CGContextRef context = CGBitmapContextCreate(data,
                                                 size.width,
                                                 size.height,
                                                 bitsPerComponent,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);

    CGRect targetRect = CGRectMake(0, 0, size.width, size.height);
    CGContextDrawImage(context, targetRect, image);
    
    if (outImage)
    {
        *outImage = CGBitmapContextCreateImage(context);
    }

    if (tintColor)
    {
        CGFloat r, g, b, a;
        [tintColor getRed:&r green:&g blue:&b alpha:&a];
        CGContextSetRGBFillColor(context, r, g, b, 1);
        CGContextSetBlendMode (context, kCGBlendModeMultiply);
        CGContextFillRect (context, targetRect);
    }

    CFRelease(colorSpace);
    CFRelease(context);
    
    return [NSData dataWithBytesNoCopy:data length:dataLength freeWhenDone:YES];
}

+ (UIColor *)tintColorAtIndex:(size_t)index
{
    switch (index % 7) {
        case 0:
            return [UIColor redColor];
        case 1:
            return [UIColor orangeColor];
        case 2:
            return [UIColor yellowColor];
        case 3:
            return [UIColor greenColor];
        case 4:
            return [UIColor blueColor];
        case 5:
            return [UIColor colorWithRed:0.5 green:0.0 blue:1.0 alpha:1.0]; // indigo
        case 6:
        default:
            return [UIColor purpleColor];
    }
}

@end
