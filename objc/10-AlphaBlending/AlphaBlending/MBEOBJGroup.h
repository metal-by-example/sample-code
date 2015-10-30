#import <Foundation/Foundation.h>

@interface MBEOBJGroup : NSObject

- (instancetype)initWithName:(NSString *)name;

@property (copy) NSString *name;
@property (copy) NSData *vertexData;
@property (copy) NSData *indexData;

@end
