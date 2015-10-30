@import Metal;
#import "MBEMesh.h"
#import "MBEFontAtlas.h"

@interface MBETextMesh : MBEMesh

- (instancetype)initWithString:(NSString *)string
                        inRect:(CGRect)rect
                      withFontAtlas:(MBEFontAtlas *)fontAtlas
                        atSize:(CGFloat)fontSize
                        device:(id<MTLDevice>)device;

@end
