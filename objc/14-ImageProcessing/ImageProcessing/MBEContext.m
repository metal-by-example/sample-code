#import "MBEContext.h"
@import Metal;

@implementation MBEContext

+ (instancetype)newContext
{
    return [[self alloc] initWithDevice:nil];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super init]))
    {
        _device = device ?: MTLCreateSystemDefaultDevice();
        _library = [_device newDefaultLibrary];
        _commandQueue = [_device newCommandQueue];
    }
    return self;
}

@end
