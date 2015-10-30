@import UIKit;
#import "MBETextureDataSource.h"

const uint32_t MBEPVRLegacyMagic = 0x21525650;
const uint32_t MBEPVRv3Magic = 0x03525650;
const uint32_t MBEASTCMagic = 0x5CA1AB13;
const uint32_t MBEKTXMagic = 0xAB4B5458;

typedef NS_ENUM(NSInteger, MBETextureContainerFormat)
{
    MBETextureContainerFormatUnknown = -1,
    MBETextureContainerFormatNotHardwareCompressed, // PNG, JPG, etc.
    MBETextureContainerFormatASTC,
    MBETextureContainerFormatPVRv2,
    MBETextureContainerFormatPVRv3,
    MBETextureContainerFormatKTX,
};

typedef struct __attribute__((packed))
{
    uint32_t magic;
    unsigned char blockDimX;
    unsigned char blockDimY;
    unsigned char blockDimZ;
    unsigned char xSize[3];
    unsigned char ySize[3];
    unsigned char zSize[3];
} MBEASTCHeader;

typedef struct __attribute__((packed))
{
    uint32_t headerLength;
    uint32_t height;
    uint32_t width;
    uint32_t mipmapCount;
    uint32_t flags;
    uint32_t dataLength;
    uint32_t bitsPerPixel;
    uint32_t redBitmask;
    uint32_t greenBitmask;
    uint32_t blueBitmask;
    uint32_t alphaBitmask;
    uint32_t pvrTag;
    uint32_t surfaceCount;
} MBEPVRv2Header;

typedef struct __attribute__((packed))
{
    uint32_t version;
    uint32_t flags;
    uint64_t pixelFormat;
    uint32_t colorSpace;
    uint32_t channelType;
    uint32_t height;
    uint32_t width;
    uint32_t depth;
    uint32_t surfaceCount;
    uint32_t faceCount;
    uint32_t mipmapCount;
    uint32_t metadataLength;
} MBEPVRv3Header;

typedef struct __attribute__((packed))
{
    uint8_t identifier[12];
    uint32_t endianness;
    uint32_t glType;
    uint32_t glTypeSize;
    uint32_t glFormat;
    uint32_t glInternalFormat;
    uint32_t glBaseInternalFormat;
    uint32_t width;
    uint32_t height;
    uint32_t depth;
    uint32_t arrayElementCount;
    uint32_t faceCount;
    uint32_t mipmapCount;
    uint32_t keyValueDataLength;
} MBEKTXHeader;

typedef NS_ENUM(NSInteger, MBEPVRLegacyPixelFormat)
{
    MBEPVRLegacyPixelFormatPVRTC2 = 0x18,
    MBEPVRLegacyPixelFormatPVRTC4 = 0x19,
};

typedef NS_ENUM(NSInteger, MBEPVRv3PixelFormat)
{
    MBEPVRv3PixelFormatPVRTC_2BPP_RGB  = 0x0,
    MBEPVRv3PixelFormatPVRTC_2BPP_RGBA = 0x1,
    MBEPVRv3PixelFormatPVRTC_4BPP_RGB  = 0x2,
    MBEPVRv3PixelFormatPVRTC_4BPP_RGBA = 0x3,
    MBEPVRv3PixelFormatETC2_RGB   = 0x16,
    MBEPVRv3PixelFormatETC2_RGBA  = 0x17,
    MBEPVRv3PixelFormatETC2_RGBA1 = 0x18,
    MBEPVRv3PixelFormatEAC_R11    = 0x19,
    MBEPVRv3PixelFormatEAC_RG11   = 0x1A,
};

typedef NS_ENUM(NSInteger, MBEKTXInternalFormat)
{
    MBEKTXInternalFormatASTC_4x4   = 37808,
    MBEKTXInternalFormatASTC_5x4   = 37809,
    MBEKTXInternalFormatASTC_5x5   = 37810,
    MBEKTXInternalFormatASTC_6x5   = 37811,
    MBEKTXInternalFormatASTC_6x6   = 37812,
    MBEKTXInternalFormatASTC_8x5   = 37813,
    MBEKTXInternalFormatASTC_8x6   = 37814,
    MBEKTXInternalFormatASTC_8x8   = 37815,
    MBEKTXInternalFormatASTC_10x5  = 37816,
    MBEKTXInternalFormatASTC_10x6  = 37817,
    MBEKTXInternalFormatASTC_10x8  = 37818,
    MBEKTXInternalFormatASTC_10x10 = 37819,
    MBEKTXInternalFormatASTC_12x10 = 37820,
    MBEKTXInternalFormatASTC_12x12 = 37821,

    MBEKTXInternalFormatASTC_4x4_sRGB   = 37840,
    MBEKTXInternalFormatASTC_5x4_sRGB   = 37841,
    MBEKTXInternalFormatASTC_5x5_sRGB   = 37842,
    MBEKTXInternalFormatASTC_6x5_sRGB   = 37843,
    MBEKTXInternalFormatASTC_6x6_sRGB   = 37844,
    MBEKTXInternalFormatASTC_8x5_sRGB   = 37845,
    MBEKTXInternalFormatASTC_8x6_sRGB   = 37846,
    MBEKTXInternalFormatASTC_8x8_sRGB   = 37847,
    MBEKTXInternalFormatASTC_10x5_sRGB  = 37848,
    MBEKTXInternalFormatASTC_10x6_sRGB  = 37849,
    MBEKTXInternalFormatASTC_10x8_sRGB  = 37850,
    MBEKTXInternalFormatASTC_10x10_sRGB = 37851,
    MBEKTXInternalFormatASTC_12x10_sRGB = 37852,
    MBEKTXInternalFormatASTC_12x12_sRGB = 37853,
};

@implementation MBETextureDataSource

+ (instancetype)textureDataSourceWithContentsOfURL:(NSURL *)url
{
    NSData *data = [NSData dataWithContentsOfURL:url];
    return [self textureDataSourceWithData:data];
}

+ (instancetype)textureDataSourceWithData:(NSData *)data
{
    return [[self alloc] initWithData:data];
}

- (instancetype)initWithData:(NSData *)data
{
    if ((self = [super init]))
    {
        MBETextureContainerFormat containerFormat = [[self class] inferredContainerFormatForData:data];
        if (containerFormat != MBETextureContainerFormatUnknown)
        {
            [self loadTextureData:data containerFormat:containerFormat];
        }
        else
        {
            return nil;
        }
    }

    return self;
}

+ (BOOL)dataIsProbablyNotHardwareCompressed:(NSData *)data
{
    if (data.length == 0)
        return YES;

    uint8_t c = 0;
    [data getBytes:&c length:1];

    switch (c) {
        case 0xFF: // JPEG
        case 0x89: // PNG
        case 0x47: // GIF
        case 0x49: // TIFF
        case 0x4D: // TIFF
            return YES;
        default:
            return NO;
    }
}

+ (BOOL)dataIsPVRv2Container:(NSData *)data
{
    if ([data length] < sizeof(MBEPVRv2Header))
    {
        return NO;
    }

    MBEPVRv2Header *header = (MBEPVRv2Header *)[data bytes];
    uint32_t fileMagic = CFSwapInt32LittleToHost(header->pvrTag);
    return (fileMagic == MBEPVRLegacyMagic);
}

+ (BOOL)dataIsPVRv3Container:(NSData *)data
{
    if ([data length] < sizeof(MBEPVRv3Header))
    {
        return NO;
    }

    MBEPVRv3Header *header = (MBEPVRv3Header *)[data bytes];
    uint32_t fileMagic = CFSwapInt32LittleToHost(header->version);
    return (fileMagic == MBEPVRv3Magic);
}

+ (BOOL)dataIsASTCContainer:(NSData *)data
{
    if ([data length] < sizeof(MBEASTCHeader))
    {
        return NO;
    }

    MBEASTCHeader *header = (MBEASTCHeader *)[data bytes];
    uint32_t fileMagic = CFSwapInt32LittleToHost(header->magic);
    return (fileMagic == MBEASTCMagic);
}

+ (BOOL)dataIsKTXContainer:(NSData *)data
{
    if ([data length] < sizeof(MBEKTXHeader))
    {
        return NO;
    }

    MBEKTXHeader *header = (MBEKTXHeader *)[data bytes];
    char *format = (char *)(header->identifier + 1);
    return strncmp(format, "KTX 11", 6) == 0;
}

+ (MBETextureContainerFormat)inferredContainerFormatForData:(NSData *)data
{
    if ([self dataIsProbablyNotHardwareCompressed:data])
    {
        return MBETextureContainerFormatNotHardwareCompressed;
    }
    else if ([self dataIsPVRv2Container:data])
    {
        return MBETextureContainerFormatPVRv2;
    }
    else if ([self dataIsPVRv3Container:data])
    {
        return MBETextureContainerFormatPVRv3;
    }
    else if ([self dataIsASTCContainer:data])
    {
        return MBETextureContainerFormatASTC;
    }
    else if ([self dataIsKTXContainer:data])
    {
        return MBETextureContainerFormatKTX;
    }

    return MBETextureContainerFormatUnknown;
}

- (BOOL)loadTextureData:(NSData *)data containerFormat:(MBETextureContainerFormat)containerFormat
{
    switch (containerFormat)
    {
        case MBETextureContainerFormatNotHardwareCompressed:
            [self loadImageData:data];
            break;
        case MBETextureContainerFormatPVRv2:
            [self loadPVRv2ImageData:data];
            break;
        case MBETextureContainerFormatPVRv3:
            [self loadPVRv3ImageData:data];
            break;
        case MBETextureContainerFormatASTC:
            [self loadASTCImageData:data];
            break;
        case MBETextureContainerFormatKTX:
            [self loadKTXImageData:data];
            break;
        default:
            break;
    }

    return NO;
}

- (BOOL)loadImageData:(NSData *)imageData
{
    UIImage *image = [UIImage imageWithData:imageData];
    CGImageRef imageRef = image.CGImage;

    // Create a suitable bitmap context for extracting the bits of the image
    const NSUInteger width = CGImageGetWidth(imageRef);
    const NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    const NSUInteger dataLength = height * width * 4;
    uint8_t *rawData = (uint8_t *)calloc(dataLength, sizeof(uint8_t));
    const NSUInteger bytesPerPixel = 4;
    const NSUInteger bytesPerRow = bytesPerPixel * width;
    const NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);

    CGRect imageRect = CGRectMake(0, 0, width, height);
    CGContextDrawImage(context, imageRect, imageRef);

    CGContextRelease(context);

    _pixelFormat = MTLPixelFormatRGBA8Unorm;
    _width = width;
    _height = height;
    _bytesPerRow = bytesPerRow;
    _mipmapCount = 1;
    _levels = @[[NSData dataWithBytesNoCopy:rawData length:dataLength freeWhenDone:YES]];

    return YES;
}

- (MTLPixelFormat)pixelFormatForASTCBlockWidth:(uint32_t)blockWidth
                                   blockHeight:(uint32_t)blockHeight
                               colorSpaceIsLDR:(BOOL)colorSpaceIsLDR
{
    MTLPixelFormat pixelFormat = MTLPixelFormatInvalid;

    if (blockWidth == 4)
    {
        if (blockHeight == 4)
        {
            pixelFormat = MTLPixelFormatASTC_4x4_LDR;
        }
    }
    else if (blockWidth == 5)
    {
        if( blockHeight == 4)
        {
            pixelFormat = MTLPixelFormatASTC_5x4_LDR;
        }
        else if (blockHeight == 5)
        {
            pixelFormat = MTLPixelFormatASTC_5x5_LDR;
        }
    }
    else if (blockWidth == 6)
    {
        if( blockHeight == 5)
        {
            pixelFormat = MTLPixelFormatASTC_6x5_LDR;
        }
        else if (blockHeight == 6)
        {
            pixelFormat = MTLPixelFormatASTC_6x6_LDR;
        }
    }
    else if (blockWidth == 8)
    {
        if( blockHeight == 5)
        {
            pixelFormat = MTLPixelFormatASTC_8x5_LDR;
        }
        else if (blockHeight == 6)
        {
            pixelFormat = MTLPixelFormatASTC_8x6_LDR;
        }
        else if (blockHeight == 8)
        {
            pixelFormat = MTLPixelFormatASTC_8x8_LDR;
        }
    }
    else if (blockWidth == 10)
    {
        if( blockHeight == 5)
        {
            pixelFormat = MTLPixelFormatASTC_10x5_LDR;
        }
        else if (blockHeight == 6)
        {
            pixelFormat = MTLPixelFormatASTC_10x6_LDR;
        }
        else if (blockHeight == 8)
        {
            pixelFormat = MTLPixelFormatASTC_10x8_LDR;
        }
        else if (blockHeight == 10)
        {
            pixelFormat = MTLPixelFormatASTC_10x10_LDR;
        }
    }
    else if (blockWidth == 12)
    {
        if (blockHeight == 10)
        {
            pixelFormat = MTLPixelFormatASTC_12x10_LDR;
        }
        else if (blockHeight == 12)
        {
            pixelFormat = MTLPixelFormatASTC_12x12_LDR;
        }
    }

    // Adjust pixel format if we're actually sRGB instead of LDR
    if (!colorSpaceIsLDR && pixelFormat != MTLPixelFormatInvalid)
    {
        pixelFormat -= (MTLPixelFormatASTC_4x4_LDR - MTLPixelFormatASTC_4x4_sRGB);
    }

    return pixelFormat;
}

- (void)getASTCPixelFormat:(MTLPixelFormat)pixelFormat
                blockWidth:(uint32_t *)outBlockWidth
               blockHeight:(uint32_t *)outBlockHeight
{
    switch (pixelFormat) {
        case MTLPixelFormatASTC_4x4_LDR:
        case MTLPixelFormatASTC_4x4_sRGB:
            *outBlockHeight = 4;
            *outBlockWidth = 4;
            break;
        case MTLPixelFormatASTC_5x4_LDR:
        case MTLPixelFormatASTC_5x4_sRGB:
            *outBlockHeight = 5;
            *outBlockWidth = 4;
            break;
        case MTLPixelFormatASTC_5x5_LDR:
        case MTLPixelFormatASTC_5x5_sRGB:
            *outBlockHeight = 5;
            *outBlockWidth = 5;
            break;
        case MTLPixelFormatASTC_6x5_LDR:
        case MTLPixelFormatASTC_6x5_sRGB:
            *outBlockHeight = 6;
            *outBlockWidth = 5;
            break;
        case MTLPixelFormatASTC_6x6_LDR:
        case MTLPixelFormatASTC_6x6_sRGB:
            *outBlockHeight = 6;
            *outBlockWidth = 6;
            break;
        case MTLPixelFormatASTC_8x5_LDR:
        case MTLPixelFormatASTC_8x5_sRGB:
            *outBlockHeight = 8;
            *outBlockWidth = 5;
            break;
        case MTLPixelFormatASTC_8x6_LDR:
        case MTLPixelFormatASTC_8x6_sRGB:
            *outBlockHeight = 8;
            *outBlockWidth = 6;
            break;
        case MTLPixelFormatASTC_8x8_LDR:
        case MTLPixelFormatASTC_8x8_sRGB:
            *outBlockWidth = 8;
            *outBlockHeight = 8;
            break;
        case MTLPixelFormatASTC_10x5_LDR:
        case MTLPixelFormatASTC_10x5_sRGB:
            *outBlockHeight = 10;
            *outBlockWidth = 5;
            break;
        case MTLPixelFormatASTC_10x6_LDR:
        case MTLPixelFormatASTC_10x6_sRGB:
            *outBlockHeight = 10;
            *outBlockWidth = 6;
            break;
        case MTLPixelFormatASTC_10x8_LDR:
        case MTLPixelFormatASTC_10x8_sRGB:
            *outBlockHeight = 10;
            *outBlockWidth = 8;
            break;
        case MTLPixelFormatASTC_10x10_LDR:
        case MTLPixelFormatASTC_10x10_sRGB:
            *outBlockHeight = 10;
            *outBlockWidth = 10;
            break;
        case MTLPixelFormatASTC_12x10_LDR:
        case MTLPixelFormatASTC_12x10_sRGB:
            *outBlockHeight = 12;
            *outBlockWidth = 10;
            break;
        case MTLPixelFormatASTC_12x12_LDR:
        case MTLPixelFormatASTC_12x12_sRGB:
            *outBlockHeight = 12;
            *outBlockWidth = 12;
            break;
        default:
            *outBlockHeight = 0;
            *outBlockWidth = 0;
            break;
    }
}


- (BOOL)loadASTCImageData:(NSData *)imageData
{
    MBEASTCHeader *header = (MBEASTCHeader *)[imageData bytes];

    uint32_t fileMagic = CFSwapInt32LittleToHost(header->magic);

    if (fileMagic != MBEASTCMagic)
    {
        return NO;
    }

    uint32_t width  = (header->xSize[2] << 16) + (header->xSize[1] << 8) + header->xSize[0];
    uint32_t height = (header->ySize[2] << 16) + (header->ySize[1] << 8) + header->ySize[0];
    uint32_t depth  = (header->zSize[2] << 16) + (header->zSize[1] << 8) + header->zSize[0];

    uint32_t widthInBlocks  =  (width + header->blockDimX - 1) / header->blockDimX;
    uint32_t heightInBlocks = (height + header->blockDimY - 1) / header->blockDimY;
    uint32_t depthInBlocks  =  (depth + header->blockDimZ - 1) / header->blockDimZ;

    uint32_t blockSize = 4 * 4;
    uint32_t dataLength = widthInBlocks * heightInBlocks * depthInBlocks * blockSize;

    NSData *levelData = [NSData dataWithBytes:[imageData bytes] + sizeof(MBEASTCHeader) length:dataLength];

    _width = width;
    _height = height;
    _bytesPerRow = widthInBlocks * blockSize;
    _mipmapCount = 1;
    _levels = @[levelData];

    // The ASTC header doesn't seem to tell us which colorspace we're in, so we assume LDR (as opposed to sRGB)
    _pixelFormat = [self pixelFormatForASTCBlockWidth:header->blockDimX
                                          blockHeight:header->blockDimY
                                      colorSpaceIsLDR:YES];

    return YES;
}

- (MTLPixelFormat)pixelFormatForPVRTCBitsPerPixel:(uint32_t)bitsPerPixel
                                   componentCount:(uint32_t)componentCount
                               colorSpaceIsLinear:(BOOL)colorSpaceIsLinear
{
    MTLPixelFormat pixelFormat = MTLPixelFormatInvalid;

    if (bitsPerPixel == 2)
    {
        if (componentCount == 3)
        {
            pixelFormat = colorSpaceIsLinear ? MTLPixelFormatPVRTC_RGB_2BPP : MTLPixelFormatPVRTC_RGB_2BPP_sRGB;
        }
        else if (componentCount == 4)
        {
            pixelFormat = colorSpaceIsLinear ? MTLPixelFormatPVRTC_RGBA_2BPP : MTLPixelFormatPVRTC_RGBA_2BPP_sRGB;
        }
    }
    else if (bitsPerPixel == 4)
    {
        if (componentCount == 3)
        {
            pixelFormat = colorSpaceIsLinear ? MTLPixelFormatPVRTC_RGB_4BPP : MTLPixelFormatPVRTC_RGB_4BPP_sRGB;
        }
        else if (componentCount == 4)
        {
            pixelFormat = colorSpaceIsLinear ? MTLPixelFormatPVRTC_RGBA_4BPP : MTLPixelFormatPVRTC_RGBA_4BPP_sRGB;
        }
    }

    return pixelFormat;
}

- (BOOL)loadPVRv2ImageData:(NSData *)imageData
{
    MBEPVRv2Header *header = (MBEPVRv2Header *)[imageData bytes];

    uint32_t flags = CFSwapInt32LittleToHost(header->flags);
    uint32_t format = flags & 0xFF;
    uint32_t mipCount = CFSwapInt32LittleToHost(header->mipmapCount);
    uint32_t width = 0, height = 0;
    BOOL hasAlpha = ((flags & 0x8000) > 0);
    BOOL colorSpaceIsLinear = YES;

    NSMutableArray *levelsData = [NSMutableArray arrayWithCapacity:MAX(mipCount, 1)];

    if (format == MBEPVRLegacyPixelFormatPVRTC2 || format == MBEPVRLegacyPixelFormatPVRTC4)
    {
        width = CFSwapInt32LittleToHost(header->width);
        height = CFSwapInt32LittleToHost(header->height);

        uint32_t dataLength = CFSwapInt32LittleToHost(header->dataLength);

        uint8_t *bytes = ((uint8_t *)[imageData bytes]) + sizeof(MBEPVRv2Header);

        uint32_t blockWidth = 0, blockHeight = 0, bitsPerPixel = 0;
        if (format == MBEPVRLegacyPixelFormatPVRTC4)
        {
            blockWidth = blockHeight = 4;
            bitsPerPixel = 4;
        }
        else
        {
            blockWidth = 8;
            blockHeight = 4;
            bitsPerPixel = 2;
        }

        uint32_t componentCount = hasAlpha ? 4 : 3;

        uint32_t blockSize = blockWidth * blockHeight;

        uint32_t dataOffset = 0;
        uint32_t levelWidth = width, levelHeight = height;
        while (dataOffset < dataLength)
        {
            uint32_t widthInBlocks = levelWidth / blockWidth;
            uint32_t heightInBlocks = levelHeight / blockHeight;

            if (widthInBlocks < 2)
            {
                widthInBlocks = 2;
            }

            if (heightInBlocks < 2)
            {
                heightInBlocks = 2;
            }

            uint32_t mipSize = widthInBlocks * heightInBlocks * ((blockSize * bitsPerPixel) / 8);

            NSData *mipData = [NSData dataWithBytes:bytes + dataOffset length:mipSize];
            [levelsData addObject:mipData];

            dataOffset += mipSize;

            levelWidth = MAX(levelWidth / 2, 1);
            levelHeight = MAX(levelHeight / 2, 1);
        }

        _pixelFormat = [self pixelFormatForPVRTCBitsPerPixel:bitsPerPixel
                                              componentCount:componentCount
                                          colorSpaceIsLinear:colorSpaceIsLinear];
    }
    else
    {
        return NO;
    }

    _width = width;
    _height = height;
    _bytesPerRow = 0;
    _mipmapCount = [levelsData count];
    _levels = [levelsData copy];

    return YES;
}

- (MTLPixelFormat)pixelFormatForETC2PixelFormat:(MBEPVRv3PixelFormat)etcPixelFormat
                             colorSpaceIsLinear:(BOOL)colorSpaceIsLinear
{
    MTLPixelFormat pixelFormat = MTLPixelFormatInvalid;

    switch (etcPixelFormat)
    {
        case MBEPVRv3PixelFormatETC2_RGB:
            pixelFormat = colorSpaceIsLinear ? MTLPixelFormatETC2_RGB8 : MTLPixelFormatETC2_RGB8_sRGB;
            break;
        case MBEPVRv3PixelFormatETC2_RGBA:
            pixelFormat = colorSpaceIsLinear ? MTLPixelFormatEAC_RGBA8 : MTLPixelFormatEAC_RGBA8_sRGB;
            break;
        case MBEPVRv3PixelFormatETC2_RGBA1:
            pixelFormat = colorSpaceIsLinear ? MTLPixelFormatETC2_RGB8A1 : MTLPixelFormatETC2_RGB8A1_sRGB;
            break;
        case MBEPVRv3PixelFormatEAC_R11:
            pixelFormat = MTLPixelFormatEAC_R11Unorm;
            break;
        case MBEPVRv3PixelFormatEAC_RG11:
            pixelFormat = MTLPixelFormatEAC_RG11Unorm;
            break;
        default:
            break;
    }

    return pixelFormat;
}

- (BOOL)loadPVRv3ImageData:(NSData *)data
{
    MBEPVRv3Header *header = (MBEPVRv3Header *)[data bytes];

    uint32_t width = CFSwapInt32LittleToHost(header->width);
    uint32_t height = CFSwapInt32LittleToHost(header->height);
    uint32_t format = CFSwapInt64LittleToHost(header->pixelFormat) & 0xffffffff;
    uint32_t mipCount = CFSwapInt32LittleToHost(header->mipmapCount);
    uint32_t metadataLength = CFSwapInt32LittleToHost(header->metadataLength);
    BOOL colorSpaceIsLinear = (CFSwapInt32LittleToHost(header->colorSpace) == 0);

    NSMutableArray *levelDatas = [NSMutableArray arrayWithCapacity:MAX(mipCount, 1)];

    if (format == MBEPVRv3PixelFormatPVRTC_2BPP_RGB ||
        format == MBEPVRv3PixelFormatPVRTC_2BPP_RGBA ||
        format == MBEPVRv3PixelFormatPVRTC_4BPP_RGB ||
        format == MBEPVRv3PixelFormatPVRTC_4BPP_RGBA)
    {
        uint32_t dataLength = (uint32_t)[data length] - (sizeof(MBEPVRv3Header) + metadataLength);

        uint8_t *bytes = ((uint8_t *)[data bytes]) + sizeof(MBEPVRv3Header) + metadataLength;

        uint32_t blockWidth = 0, blockHeight = 0, bitsPerPixel = 0;

        if (format == MBEPVRv3PixelFormatPVRTC_4BPP_RGB || format == MBEPVRv3PixelFormatPVRTC_4BPP_RGBA)
        {
            blockWidth = blockHeight = 4;
            bitsPerPixel = 4;
        }
        else
        {
            blockWidth = 8;
            blockHeight = 4;
            bitsPerPixel = 2;
        }

        uint32_t blockSize = blockWidth * blockHeight;

        uint32_t dataOffset = 0;
        uint32_t levelWidth = width, levelHeight = height;
        while (dataOffset < dataLength)
        {
            uint32_t widthInBlocks = levelWidth / blockWidth;
            uint32_t heightInBlocks = levelHeight / blockHeight;

            uint32_t mipSize = widthInBlocks * heightInBlocks * ((blockSize * bitsPerPixel) / 8);

            if (mipSize < 32)
            {
                mipSize = 32;
            }

            NSData *mipData = [NSData dataWithBytes:bytes + dataOffset length:mipSize];
            [levelDatas addObject:mipData];

            dataOffset += mipSize;

            levelWidth = MAX(levelWidth / 2, 1);
            levelHeight = MAX(levelHeight / 2, 1);
        }

        uint32_t componentCount = ((format == MBEPVRv3PixelFormatPVRTC_2BPP_RGB) ||
                                   (format == MBEPVRv3PixelFormatPVRTC_4BPP_RGB)) ? 3 : 4;

        _bytesPerRow = 0;
        _pixelFormat = [self pixelFormatForPVRTCBitsPerPixel:bitsPerPixel
                                              componentCount:componentCount
                                          colorSpaceIsLinear:colorSpaceIsLinear];
    }
    else if (format == MBEPVRv3PixelFormatETC2_RGB ||
             format == MBEPVRv3PixelFormatETC2_RGBA1 ||
             format == MBEPVRv3PixelFormatETC2_RGBA ||
             format == MBEPVRv3PixelFormatEAC_R11 ||
             format == MBEPVRv3PixelFormatEAC_RG11)
    {
        uint32_t dataLength = (uint32_t)[data length] - (sizeof(MBEPVRv3Header) + metadataLength);

        uint8_t *bytes = ((uint8_t *)[data bytes]) + sizeof(MBEPVRv3Header) + metadataLength;

        uint32_t blockWidth = 4, blockHeight = 4, blockSize = 0;

        if (format == MBEPVRv3PixelFormatETC2_RGB)
        {
            blockSize = 8;
        }
        else if (format == MBEPVRv3PixelFormatETC2_RGBA)
        {
            blockSize = 16;
        }
        else if (format == MBEPVRv3PixelFormatETC2_RGBA1)
        {
            blockSize = 8;
        }
        else if (format == MBEPVRv3PixelFormatEAC_R11)
        {
            blockSize = 8;
        }
        else if (format == MBEPVRv3PixelFormatEAC_RG11)
        {
            blockSize = 16;
        }

        uint32_t dataOffset = 0;
        uint32_t levelWidth = width, levelHeight = height;
        while (dataOffset < dataLength)
        {
            uint32_t widthInBlocks = levelWidth / blockWidth;
            uint32_t heightInBlocks = levelHeight / blockHeight;

            uint32_t mipSize = widthInBlocks * heightInBlocks * blockSize;

            if (mipSize < 32)
            {
                mipSize = 32;
            }

            NSData *mipData = [NSData dataWithBytes:bytes + dataOffset length:mipSize];
            [levelDatas addObject:mipData];

            dataOffset += mipSize;

            levelWidth = MAX(levelWidth / 2, 1);
            levelHeight = MAX(levelHeight / 2, 1);
        }

        _bytesPerRow = (width / blockWidth) * blockSize;
        _pixelFormat = [self pixelFormatForETC2PixelFormat:format colorSpaceIsLinear:colorSpaceIsLinear];
    }
    else
    {
        return NO; // Unsupported format for PVR container
    }

    _width = width;
    _height = height;
    _levels = [levelDatas copy];
    _mipmapCount = [levelDatas count];

    return YES;
}

- (MTLPixelFormat)pixelFormatForGLInternalFormat:(MBEKTXInternalFormat)internalFormat
{
    switch (internalFormat) {
        case MBEKTXInternalFormatASTC_4x4:
            return MTLPixelFormatASTC_4x4_LDR;
        case MBEKTXInternalFormatASTC_5x4:
            return MTLPixelFormatASTC_5x4_LDR;
        case MBEKTXInternalFormatASTC_5x5:
            return MTLPixelFormatASTC_5x5_LDR;
        case MBEKTXInternalFormatASTC_6x5:
            return MTLPixelFormatASTC_6x5_LDR;
        case MBEKTXInternalFormatASTC_6x6:
            return MTLPixelFormatASTC_6x6_LDR;
        case MBEKTXInternalFormatASTC_8x5:
            return MTLPixelFormatASTC_8x5_LDR;
        case MBEKTXInternalFormatASTC_8x6:
            return MTLPixelFormatASTC_8x6_LDR;
        case MBEKTXInternalFormatASTC_8x8:
            return MTLPixelFormatASTC_8x8_LDR;
        case MBEKTXInternalFormatASTC_10x5:
            return MTLPixelFormatASTC_10x5_LDR;
        case MBEKTXInternalFormatASTC_10x6:
            return MTLPixelFormatASTC_10x6_LDR;
        case MBEKTXInternalFormatASTC_10x8:
            return MTLPixelFormatASTC_10x8_LDR;
        case MBEKTXInternalFormatASTC_10x10:
            return MTLPixelFormatASTC_10x10_LDR;
        case MBEKTXInternalFormatASTC_12x10:
            return MTLPixelFormatASTC_12x10_LDR;
        case MBEKTXInternalFormatASTC_12x12:
            return MTLPixelFormatASTC_12x12_LDR;
        case MBEKTXInternalFormatASTC_4x4_sRGB:
            return MTLPixelFormatASTC_4x4_sRGB;
        case MBEKTXInternalFormatASTC_5x4_sRGB:
            return MTLPixelFormatASTC_5x4_sRGB;
        case MBEKTXInternalFormatASTC_5x5_sRGB:
            return MTLPixelFormatASTC_5x5_sRGB;
        case MBEKTXInternalFormatASTC_6x5_sRGB:
            return MTLPixelFormatASTC_6x5_sRGB;
        case MBEKTXInternalFormatASTC_6x6_sRGB:
            return MTLPixelFormatASTC_6x6_sRGB;
        case MBEKTXInternalFormatASTC_8x5_sRGB:
            return MTLPixelFormatASTC_8x5_sRGB;
        case MBEKTXInternalFormatASTC_8x6_sRGB:
            return MTLPixelFormatASTC_8x6_sRGB;
        case MBEKTXInternalFormatASTC_8x8_sRGB:
            return MTLPixelFormatASTC_8x8_sRGB;
        case MBEKTXInternalFormatASTC_10x5_sRGB:
            return MTLPixelFormatASTC_10x5_sRGB;
        case MBEKTXInternalFormatASTC_10x6_sRGB:
            return MTLPixelFormatASTC_10x6_sRGB;
        case MBEKTXInternalFormatASTC_10x8_sRGB:
            return MTLPixelFormatASTC_10x8_sRGB;
        case MBEKTXInternalFormatASTC_10x10_sRGB:
            return MTLPixelFormatASTC_10x10_sRGB;
        case MBEKTXInternalFormatASTC_12x10_sRGB:
            return MTLPixelFormatASTC_12x10_sRGB;
        case MBEKTXInternalFormatASTC_12x12_sRGB:
            return MTLPixelFormatASTC_12x12_sRGB;
        default:
            return MTLPixelFormatInvalid;
    }
}

- (BOOL)loadKTXImageData:(NSData *)data;
{
    MBEKTXHeader *header = (MBEKTXHeader *)[data bytes];

    BOOL endianSwap = (header->endianness == 0x01020304);

    uint32_t width = endianSwap ? CFSwapInt32(header->width) : header->width;
    uint32_t height = endianSwap ? CFSwapInt32(header->height) : header->height;
    uint32_t internalFormat = endianSwap ? CFSwapInt32(header->glInternalFormat) : header->glInternalFormat;
    uint32_t mipCount = endianSwap ? CFSwapInt32(header->mipmapCount) : header->mipmapCount;
    uint32_t keyValueDataLength = endianSwap ? CFSwapInt32(header->keyValueDataLength) : header->keyValueDataLength;

    const uint8_t *bytes = [data bytes] + sizeof(MBEKTXHeader) + keyValueDataLength;
    const size_t dataLength = [data length] - (sizeof(MBEKTXHeader) + keyValueDataLength);

    NSMutableArray *levelDatas = [NSMutableArray arrayWithCapacity:MAX(mipCount, 1)];

    const uint32_t blockSize = 16;
    uint32_t dataOffset = 0;
    uint32_t levelWidth = width, levelHeight = height;
    while (dataOffset < dataLength)
    {
        uint32_t levelSize = *(uint32_t *)(bytes + dataOffset);
        dataOffset += sizeof(uint32_t);

        NSData *mipData = [NSData dataWithBytes:bytes + dataOffset length:levelSize];
        [levelDatas addObject:mipData];

        dataOffset += levelSize;

        levelWidth = MAX(levelWidth / 2, 1);
        levelHeight = MAX(levelHeight / 2, 1);
    }

    MTLPixelFormat pixelFormat = [self pixelFormatForGLInternalFormat:internalFormat];

    if (pixelFormat == MTLPixelFormatInvalid)
    {
        return NO;
    }

    uint32_t blockWidth, blockHeight;
    [self getASTCPixelFormat:pixelFormat blockWidth:&blockWidth blockHeight:&blockHeight];

    _pixelFormat = pixelFormat;
    _bytesPerRow = (width / blockWidth) * blockSize;
    _width = width;
    _height = height;
    _levels = [levelDatas copy];
    _mipmapCount = [levelDatas count];

    return YES;
}

// This heuristic might be a little bit off. I haven't tested it with anything other than RGBA8Unorm.
- (BOOL)pixelFormatIsColorRenderable:(MTLPixelFormat)pixelFormat
{
    BOOL isCompressedFormat = (pixelFormat >= MTLPixelFormatASTC_4x4_sRGB && pixelFormat <= MTLPixelFormatASTC_12x12_LDR) ||
                              (pixelFormat >= MTLPixelFormatPVRTC_RGB_2BPP && pixelFormat <= MTLPixelFormatPVRTC_RGBA_4BPP_sRGB) ||
                              (pixelFormat >= MTLPixelFormatEAC_R11Unorm && pixelFormat <= MTLPixelFormatETC2_RGB8A1_sRGB);
    BOOL is422Format = (pixelFormat == MTLPixelFormatGBGR422 || pixelFormat == MTLPixelFormatBGRG422);

    return !isCompressedFormat && !is422Format && !(pixelFormat == MTLPixelFormatInvalid);
}

- (id<MTLTexture>)newTextureWithCommandQueue:(id<MTLCommandQueue>)commandQueue generateMipmaps:(BOOL)generateMipmaps
{
    if ([self.levels count] > 0)
    {
        BOOL mipsLoaded = ([self.levels count] > 1);
        BOOL canGenerateMips = [self pixelFormatIsColorRenderable:self.pixelFormat];

        if (mipsLoaded || !canGenerateMips)
        {
            generateMipmaps = NO;
        }

        BOOL needMipStorage = (generateMipmaps || mipsLoaded);

        MTLTextureDescriptor *texDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:self.pixelFormat
                                                                                                 width:self.width
                                                                                                height:self.height
                                                                                             mipmapped:needMipStorage];
        id<MTLTexture> texture = [[commandQueue device] newTextureWithDescriptor:texDescriptor];

        __block NSInteger levelWidth = self.width;
        __block NSInteger levelHeight = self.height;
        __block NSInteger levelBytesPerRow = self.bytesPerRow;

        [self.levels enumerateObjectsUsingBlock:^(NSData *levelData, NSUInteger level, BOOL *stop) {
            MTLRegion region = MTLRegionMake2D(0, 0, levelWidth, levelHeight);
            [texture replaceRegion:region mipmapLevel:level withBytes:[levelData bytes] bytesPerRow:levelBytesPerRow];

            levelWidth = MAX(levelWidth / 2, 1);
            levelHeight = MAX(levelHeight / 2, 1);
            levelBytesPerRow = (levelBytesPerRow > 0) ? MAX(levelBytesPerRow / 2, 16) : 0;
        }];

        if (generateMipmaps)
        {
            [self generateMipmapsForTexture:texture commandQueue:commandQueue];
        }

        return texture;
    }

    return nil;
}

- (void)generateMipmapsForTexture:(id<MTLTexture>)texture commandQueue:(id<MTLCommandQueue>)commandQueue
{
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    [blitEncoder generateMipmapsForTexture:texture];
    [blitEncoder endEncoding];
    [commandBuffer commit];

    // blocking call
    [commandBuffer waitUntilCompleted];
}

@end
