#import "MBEOBJGroup.h"

@implementation MBEOBJGroup

- (instancetype)initWithName:(NSString *)name
{
    if ((self = [super init]))
    {
        _name = [name copy];
    }
    return self;
}

@end
