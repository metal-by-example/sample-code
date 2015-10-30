#import "MBEMaterial.h"
#import "MBETypes.h"

@implementation MBEMaterial

- (instancetype)initWithDiffuseTexture:(id<MTLTexture>)diffuseTexture
                      alphaTestEnabled:(BOOL)alphaTestEnabled
                       blendingEnabled:(BOOL)blendingEnabled
                     depthWriteEnabled:(BOOL)depthWriteEnabled
                                device:(id<MTLDevice>)device
{
    NSError *error = nil;

    if ((self = [super init]))
    {
        _diffuseTexture = diffuseTexture;

        NSString *fragmentFunctionName = alphaTestEnabled ? @"texture_fragment_alpha_test" : @"texture_fragment";
        
        id<MTLLibrary> library = [device newDefaultLibrary];

        MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
        pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"project_vertex"];
        pipelineDescriptor.fragmentFunction = [library newFunctionWithName:fragmentFunctionName];
        pipelineDescriptor.vertexDescriptor = [self newVertexDescriptor];

        MTLRenderPipelineColorAttachmentDescriptor *renderbufferAttachment = pipelineDescriptor.colorAttachments[0];

        renderbufferAttachment.pixelFormat = MTLPixelFormatBGRA8Unorm;

        if (blendingEnabled)
        {
            renderbufferAttachment.blendingEnabled = YES;
            renderbufferAttachment.rgbBlendOperation = MTLBlendOperationAdd;
            renderbufferAttachment.alphaBlendOperation = MTLBlendOperationAdd;

            renderbufferAttachment.sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
            renderbufferAttachment.destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

            renderbufferAttachment.sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
            renderbufferAttachment.destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        }

        pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

        _pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
        if (!_pipelineState)
        {
            NSLog(@"Failed to create render pipeline state: %@", error);
        }

        MTLDepthStencilDescriptor *depthDescriptor = [MTLDepthStencilDescriptor new];
        depthDescriptor.depthWriteEnabled = depthWriteEnabled;
        depthDescriptor.depthCompareFunction = MTLCompareFunctionLess;

        _depthState = [device newDepthStencilStateWithDescriptor:depthDescriptor];
    }

    return self;
}

- (MTLVertexDescriptor *)newVertexDescriptor
{
    MTLVertexDescriptor *vertexDescriptor = [MTLVertexDescriptor new];

    // Position
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;

    // Normal
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[1].offset = sizeof(vector_float4);
    vertexDescriptor.attributes[1].bufferIndex = 0;

    // Diffuse color
    vertexDescriptor.attributes[2].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[2].offset = sizeof(vector_float4) * 2;
    vertexDescriptor.attributes[2].bufferIndex = 0;

    // Texture coordinates
    vertexDescriptor.attributes[3].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[3].offset = sizeof(vector_float4) * 3;
    vertexDescriptor.attributes[3].bufferIndex = 0;

    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    vertexDescriptor.layouts[0].stride = sizeof(MBEVertex);
    
    return vertexDescriptor;
}

@end
