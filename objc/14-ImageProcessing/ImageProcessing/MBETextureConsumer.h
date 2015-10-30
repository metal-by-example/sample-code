@import Foundation;

@protocol MBETextureProvider;

@protocol MBETextureConsumer <NSObject>

@property (nonatomic, strong) id<MBETextureProvider> provider;

@end
