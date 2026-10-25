#import <UIKit/UIKit.h>
@interface MDUtil : NSObject
+ (NSString *)escape:(NSString *)s;               // percent-encode, unreserved only
+ (NSDate *)parseTime:(NSString *)iso;            // 2021-05-01T12:00:00+00:00
+ (NSString *)ago:(NSDate *)d;
+ (NSString *)plainFromMarkdown:(NSString *)s;
+ (NSString *)md5:(NSString *)s;
+ (NSData *)base64Decode:(NSString *)s;           // iOS 6 has no public base64 decoder
+ (NSString *)humanSize:(unsigned long long)b;
+ (void)showMessage:(NSString *)m title:(NSString *)t;
@end
