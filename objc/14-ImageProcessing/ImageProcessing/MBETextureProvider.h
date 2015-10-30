@import Foundation;

@protocol MTLTexture;

@protocol MBETextureProvider <NSObject>

@property (nonatomic, readonly) id<MTLTexture> texture;

@end
