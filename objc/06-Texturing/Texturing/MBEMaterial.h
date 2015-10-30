@import Foundation;
@import Metal;

@interface MBEMaterial : NSObject

@property (strong) id<MTLFunction> vertexFunction;
@property (strong) id<MTLFunction> fragmentFunction;
@property (strong) id<MTLTexture> diffuseTexture;

- (instancetype)initWithVertexFunction:(id<MTLFunction>)vertexFunction
                      fragmentFunction:(id<MTLFunction>)fragmentFunction
                        diffuseTexture:(id<MTLTexture>)diffuseTexture;

@end
