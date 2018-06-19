//
//  MBEMetalView.m
//  Mipmapping
//
//  Created by Brent Gulanowski on 2018-06-19.
//  Copyright © 2018 Metal By Example. All rights reserved.
//

#import "MBEMetalView.h"

@implementation MBEMetalView

@dynamic metalLayer;
@dynamic drawableSize;

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    self.metalLayer.drawableSize = self.drawableSize;
}

@end
