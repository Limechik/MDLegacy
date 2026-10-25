#import <Foundation/Foundation.h>

@interface MDHttpResponse : NSObject
@property (nonatomic) NSInteger statusCode;
@property (nonatomic, strong) NSData *body;
@property (nonatomic, strong) NSDictionary *headers;   // lower-cased keys
@property (nonatomic, strong) NSError *error;
@property (nonatomic) NSInteger endCode;                // mbedTLS code that ended the read loop (0 = clean close)
- (BOOL)isSuccessful;
@end

@interface MDHttp : NSObject
// Blocking; call from a background thread. ttl > 0 enables in-memory cache.
+ (MDHttpResponse *)get:(NSString *)url cacheForTTL:(NSTimeInterval)ttl;
+ (void)dropMemoryCache;
+ (NSString *)userAgent;
@end
