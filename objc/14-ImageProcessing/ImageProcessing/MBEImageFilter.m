#import "MBEImageFilter.h"
#import "MBEContext.h"
@import Metal;

@interface MBEImageFilter ()
@property (nonatomic, strong) id<MTLFunction> kernelFunction;
@property (nonatomic, strong) id<MTLTexture> texture;
@end

@implementation MBEImageFilter

@synthesize dirty=_dirty;
@synthesize provider=_provider;

- (instancetype)initWithFunctionName:(NSString *)functionName context:(MBEContext *)context;
{
    if ((self = [super init]))
    {
        NSError *error = nil;
        _context = context;
        _kernelFunction = [_context.library newFunctionWithName:functionName];
        _pipeline = [_context.device newComputePipelineStateWithFunction:_kernelFunction error:&error];
        if (!_pipeline)
        {
            NSLog(@"Error occurred when building compute pipeline for function %@", functionName);
            return nil;
        }
        _dirty = YES;
    }
    
    return self;
}

- (void)configureArgumentTableWithCommandEncoder:(id<MTLComputeCommandEncoder>)commandEncoder
{
}

- (void)applyFilter
{
    id<MTLTexture> inputTexture = self.provider.texture;
    
    if (!self.internalTexture ||
        [self.internalTexture width] != [inputTexture width] ||
        [self.internalTexture height] != [inputTexture height])
    {
        MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:[inputTexture pixelFormat]
                                                                                                     width:[inputTexture width]
                                                                                                    height:[inputTexture height]
                                                                                                 mipmapped:NO];
        self.internalTexture = [self.context.device newTextureWithDescriptor:textureDescriptor];
    }
    
    MTLSize threadgroupCounts = MTLSizeMake(8, 8, 1);
    MTLSize threadgroups = MTLSizeMake([inputTexture width] / threadgroupCounts.width,
                                       [inputTexture height] / threadgroupCounts.height,
                                       1);
    
    id<MTLCommandBuffer> commandBuffer = [self.context.commandQueue commandBuffer];
    
    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    [commandEncoder setComputePipelineState:self.pipeline];
    [commandEncoder setTexture:inputTexture atIndex:0];
    [commandEncoder setTexture:self.internalTexture atIndex:1];
    [self configureArgumentTableWithCommandEncoder:commandEncoder];
    [commandEncoder dispatchThreadgroups:threadgroups threadsPerThreadgroup:threadgroupCounts];
    [commandEncoder endEncoding];
    
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

- (id<MTLTexture>)texture
{
    if (self.isDirty)
    {
        [self applyFilter];
    }
    
    return self.internalTexture;
}

@end
