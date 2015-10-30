@import UIKit;
@import Metal;

@interface MBETextureLoader : NSObject

+ (instancetype)sharedTextureLoader;

- (id<MTLTexture>)texture2DWithImageNamed:(NSString *)imageName
                                mipmapped:(BOOL)mipmapped
                             commandQueue:(id<MTLCommandQueue>)queue;

@end
