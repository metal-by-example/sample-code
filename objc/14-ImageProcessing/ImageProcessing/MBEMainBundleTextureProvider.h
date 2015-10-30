@import UIKit;
#import "MBETextureProvider.h"

@class MBEContext;

@interface MBEMainBundleTextureProvider : NSObject<MBETextureProvider>

+ (instancetype)textureProviderWithImageNamed:(NSString *)imageName context:(MBEContext *)context;

@end
