@import UIKit;
@import Metal;

@interface MBETextureGenerator : NSObject

/// Generates a square checkerboard texture with the specified number of tiles.
/// If `colorfulMipmaps` is YES, mipmap levels will be generated on the CPU and tinted
/// to be visually distinct when drawn. Otherwise, the blit command encoder is used to
/// generate all mipmap levels on the GPU.
+ (void)checkerboardTextureWithSize:(CGSize)size
                          tileCount:(size_t)tileCount
                    colorfulMipmaps:(BOOL)colorfulMipmaps
                             device:(id<MTLDevice>)device
                         completion:(void (^)(id<MTLTexture>))completionBlock;

@end
