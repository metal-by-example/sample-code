@import UIKit;
@import Metal;

@interface MBETextureLoader : NSObject

+ (id<MTLTexture>)texture2DWithImageNamed:(NSString *)imageName device:(id<MTLDevice>)device;

@end
