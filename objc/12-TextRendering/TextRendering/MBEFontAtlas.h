@import UIKit;

@interface MBEGlyphDescriptor : NSObject <NSSecureCoding>
@property (nonatomic, assign) CGGlyph glyphIndex;
@property (nonatomic, assign) CGPoint topLeftTexCoord;
@property (nonatomic, assign) CGPoint bottomRightTexCoord;
@end

@interface MBEFontAtlas : NSObject <NSSecureCoding>

@property (nonatomic, readonly) UIFont *parentFont;
@property (nonatomic, readonly) CGFloat fontPointSize;
@property (nonatomic, readonly) CGFloat spread;
@property (nonatomic, readonly) NSInteger textureSize;
@property (nonatomic, readonly) NSArray *glyphDescriptors;
@property (nonatomic, readonly) NSData *textureData;

/// Create a signed-distance field based font atlas with the specified dimensions.
/// The supplied font will be resized to fit all available glyphs in the texture.
- (instancetype)initWithFont:(UIFont *)font textureSize:(NSInteger)textureSize;

@end
