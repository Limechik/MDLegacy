#import "MDUtil.h"
#import <CommonCrypto/CommonDigest.h>
#import <ctype.h>

@implementation MDUtil

+ (NSString *)escape:(NSString *)s {
    const char *u = s.UTF8String;
    NSMutableString *o = [NSMutableString string];
    for (; u && *u; u++) {
        unsigned char c = (unsigned char)*u;
        if (c < 128 && (isalnum(c) || c == '-' || c == '.' || c == '_' || c == '~'))
            [o appendFormat:@"%c", c];
        else
            [o appendFormat:@"%%%02X", c];
    }
    return o;
}

+ (NSDate *)parseTime:(NSString *)s {
    if (![s isKindOfClass:[NSString class]] || s.length < 19) return nil;
    static NSDateFormatter *f; static dispatch_once_t once;
    dispatch_once(&once, ^{
        f = [[NSDateFormatter alloc] init];
        f.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        f.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        f.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
    });
    @synchronized (f) { return [f dateFromString:[s substringToIndex:19]]; }
}

+ (NSString *)ago:(NSDate *)d {
    if (!d) return @"";
    NSInteger s = (NSInteger)-[d timeIntervalSinceNow];
    if (s < 60)    return @"только что";
    if (s < 3600)  return [NSString stringWithFormat:@"%ld мин. назад", (long)(s / 60)];
    if (s < 86400) return [NSString stringWithFormat:@"%ld ч. назад", (long)(s / 3600)];
    if (s < 86400 * 30) return [NSString stringWithFormat:@"%ld дн. назад", (long)(s / 86400)];
    static NSDateFormatter *f; static dispatch_once_t once;
    dispatch_once(&once, ^{ f = [[NSDateFormatter alloc] init]; f.dateStyle = NSDateFormatterMediumStyle; });
    @synchronized (f) { return [f stringFromDate:d]; }
}

+ (NSString *)plainFromMarkdown:(NSString *)s {
    if (![s length]) return @"";
    NSMutableString *m = [s mutableCopy];
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\[([^\\]]*)\\]\\([^)]*\\)" options:0 error:nil];
    [re replaceMatchesInString:m options:0 range:NSMakeRange(0, m.length) withTemplate:@"$1"];
    for (NSString *t in @[@"**", @"__", @"~~", @"###", @"##", @"#"])
        [m replaceOccurrencesOfString:t withString:@"" options:0 range:NSMakeRange(0, m.length)];
    return [m stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (NSString *)md5:(NSString *)s {
    const char *u = s.UTF8String; unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(u, (CC_LONG)strlen(u), r);
    NSMutableString *h = [NSMutableString string];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) [h appendFormat:@"%02x", r[i]];
    return h;
}

+ (NSData *)base64Decode:(NSString *)s {
    static const char *T = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    NSMutableData *d = [NSMutableData data];
    int acc = 0, bits = 0;
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar ch = [s characterAtIndex:i];
        const char *p = (ch > 0 && ch < 128) ? strchr(T, (char)ch) : NULL;
        if (!p) continue;                         // skips '=', whitespace, newlines
        acc = (acc << 6) | (int)(p - T); bits += 6;
        if (bits >= 8) { bits -= 8; uint8_t b = (acc >> bits) & 0xFF; [d appendBytes:&b length:1]; }
        acc &= (1 << bits) - 1;
    }
    return d;
}

+ (NSString *)humanSize:(unsigned long long)b {
    if (b < 1024) return [NSString stringWithFormat:@"%llu Б", b];
    if (b < 1024 * 1024) return [NSString stringWithFormat:@"%.1f КБ", b / 1024.0];
    return [NSString stringWithFormat:@"%.1f МБ", b / 1048576.0];
}

+ (void)showMessage:(NSString *)m title:(NSString *)t {
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:t message:m delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [a show];
}
@end
