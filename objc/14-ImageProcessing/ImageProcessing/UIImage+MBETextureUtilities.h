@import UIKit;

@protocol MTLTexture;

@interface UIImage (MBETextureUtilities)

+ (UIImage *)imageWithMTLTexture:(id<MTLTexture>)texture;

@end

