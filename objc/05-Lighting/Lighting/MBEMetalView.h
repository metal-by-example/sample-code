@import UIKit;
@import Metal;
@import QuartzCore.CAMetalLayer;

@protocol MBEMetalViewDelegate;

@interface MBEMetalView : UIView

/// The delegate of this view, responsible for drawing
@property (nonatomic, weak) id<MBEMetalViewDelegate> delegate;

/// The Metal layer that backs this view
@property (nonatomic, readonly) CAMetalLayer *metalLayer;

/// The target frame rate (in Hz). For best results, this should
/// be a number that evenly divides 60 (e.g., 60, 30, 15).
@property (nonatomic) NSInteger preferredFramesPerSecond;

/// The desired pixel format of the color attachment
@property (nonatomic) MTLPixelFormat colorPixelFormat;

/// The color to which the color attachment should be cleared at the start of
/// a rendering pass
@property (nonatomic, assign) MTLClearColor clearColor;

/// The duration (in seconds) of the previous frame. This is valid only in the context
/// of a callback to the delegate's -drawInView: method.
@property (nonatomic, readonly) NSTimeInterval frameDuration;

/// The view's layer's current drawable. This is valid only in the context
/// of a callback to the delegate's -drawInView: method.
@property (nonatomic, readonly) id<CAMetalDrawable> currentDrawable;

/// A render pass descriptor configured to use the current drawable's texture
/// as its primary color attachment and an internal depth texture of the same
/// size as its depth attachment's texture
@property (nonatomic, readonly) MTLRenderPassDescriptor *currentRenderPassDescriptor;

@end

@protocol MBEMetalViewDelegate <NSObject>
/// This method is called once per frame. Within the method, you may access
/// any of the properties of the view, and request the current render pass
/// descriptor to get a descriptor configured with renderable color and depth
/// textures.
- (void)drawInView:(MBEMetalView *)view;
@end
