@import Foundation;

@protocol MTLDevice, MTLLibrary, MTLCommandQueue;

@interface MBEContext : NSObject

@property (strong) id<MTLDevice> device;
@property (strong) id<MTLLibrary> library;
@property (strong) id<MTLCommandQueue> commandQueue;

+ (instancetype)newContext;

@end
