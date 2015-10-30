@import Foundation;
@import Metal;

/// This class provides pixel data for textures from the following formats:
///  - Any format that can be loaded by UIImage, such as PNG, JPEG, TIFF, etc.
///      (These textures will be converted to have a pixel format of RGBA8Unorm)
///  - Legacy PVR (v.2) encapsulating PVRTC data
///  - PVR v.3 encapsulating PVRTC or ETC2/EAC data
///  - ASTC encapsulating ASTC (LDR) data
///
/// The `levels` property is an array of NSData objects containing the mipmap
/// levels encoded in the file, suitable for loading into an MTLTexture.
/// If the file contains only a single layer, this array will have one entry.
///
/// The `width` and `height` properties give the dimensions of the base level.
///
/// Currently, only 2D, single-slice, single-face textures are supported.
@interface MBETextureDataSource : NSObject

@property (nonatomic, readonly) MTLPixelFormat pixelFormat;
@property (nonatomic, readonly) NSUInteger width;
@property (nonatomic, readonly) NSUInteger height;
@property (nonatomic, readonly) NSUInteger bytesPerRow;
@property (nonatomic, readonly) NSUInteger mipmapCount;
@property (nonatomic, readonly) NSArray *levels;

+ (instancetype)textureDataSourceWithContentsOfURL:(NSURL *)url;

+ (instancetype)textureDataSourceWithData:(NSData *)data;

/// This method creates a new texture, generating mipmaps if requested.
/// If the pixel format of the data data does not permit runtime mipmap
/// generation, the `generateMipmaps` parameter is ignored.
- (id<MTLTexture>)newTextureWithCommandQueue:(id<MTLCommandQueue>)commandQueue
                             generateMipmaps:(BOOL)generateMipmaps;

@end
